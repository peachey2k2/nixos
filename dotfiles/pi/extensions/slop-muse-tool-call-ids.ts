/**
 * Muse Spark OpenAI-compatibility shim.
 *
 * Slop's Muse backend can emit OpenAI tool calls with id: "". OpenAI requires
 * a non-empty ID when the tool result is replayed, so retain/generated IDs must
 * be used before Pi stores or sends the call.
 */

import { Type } from "typebox";

const MUSE_PREFIX = "muse-spark-";
let sequence = 0;

function newToolCallId(): string {
  sequence += 1;
  return `muse_call_${Date.now().toString(36)}_${sequence}_${crypto.randomUUID().slice(0, 8)}`;
}

function isMuseAssistant(message: any): boolean {
  return message?.role === "assistant"
    && message?.provider === "slop"
    && typeof message?.model === "string"
    && message.model.startsWith(MUSE_PREFIX);
}

/**
 * Recover only unambiguous malformed names. Unknown nameless calls go to a
 * local diagnostic tool, rather than being replayed to Slop as name: "".
 */
function repairMuseToolName(call: any): any {
  if (call?.name === "tool" && typeof call?.arguments?.command === "string") {
    return { ...call, name: "bash" };
  }
  if (!call?.name && typeof call?.arguments?.url === "string"
    && (Array.isArray(call.arguments.formats) || typeof call.arguments.onlyMainContent === "boolean")) {
    return { ...call, name: "firecrawl_scrape" };
  }
  if (!call?.name) return { ...call, name: "muse_invalid_tool_call" };
  return call;
}

/** Give freshly streamed Muse calls an ID before Pi executes and saves them. */
function repairAssistantMessage(message: any): any {
  if (!isMuseAssistant(message) || !Array.isArray(message.content)) return message;

  let changed = false;
  const content = message.content.map((block: any) => {
    if (block?.type !== "toolCall") return block;

    const namedBlock = repairMuseToolName(block);
    if (typeof namedBlock.id === "string" && namedBlock.id.length > 0) {
      if (namedBlock !== block) changed = true;
      return namedBlock;
    }

    changed = true;
    return { ...namedBlock, id: newToolCallId() };
  });

  return changed ? { ...message, content } : message;
}

function repairOpenAIChatCall(call: any): any {
  let argumentsObject: any;
  if (typeof call?.function?.arguments === "string") {
    try {
      argumentsObject = JSON.parse(call.function.arguments);
    } catch {
      // Leave malformed argument JSON to Pi/provider validation.
    }
  }
  const repaired = repairMuseToolName({
    name: call?.function?.name,
    arguments: argumentsObject,
  });
  return repaired.name === call?.function?.name
    ? call
    : { ...call, function: { ...call.function, name: repaired.name } };
}

/**
 * Repair old session entries after Pi has serialized them to OpenAI Chat
 * Completions. Calls and their following tool results are paired in order.
 */
function repairChatPayload(payload: any): any {
  if (!payload?.model?.startsWith?.(MUSE_PREFIX) || !Array.isArray(payload.messages)) {
    return payload;
  }

  const pendingIds: string[] = [];
  let changed = false;
  const messages = payload.messages.map((message: any) => {
    if (message?.role === "assistant" && Array.isArray(message.tool_calls)) {
      const tool_calls = message.tool_calls.map((call: any) => {
        const namedCall = repairOpenAIChatCall(call);
        if (typeof namedCall?.id === "string" && namedCall.id.length > 0) {
          if (namedCall !== call) changed = true;
          return namedCall;
        }
        changed = true;
        const id = newToolCallId();
        pendingIds.push(id);
        return { ...namedCall, id };
      });
      return tool_calls === message.tool_calls ? message : { ...message, tool_calls };
    }

    if (message?.role === "tool" && (!message.tool_call_id || message.tool_call_id === "")) {
      const id = pendingIds.shift() ?? newToolCallId();
      changed = true;
      return { ...message, tool_call_id: id };
    }

    return message;
  });

  return changed ? { ...payload, messages } : payload;
}

export default function (pi: any) {
  // A safe fallback for malformed Muse calls whose arguments do not identify a
  // real Pi tool. Its result tells Muse to retry with one of the advertised tools.
  pi.registerTool({
    name: "muse_invalid_tool_call",
    label: "Muse malformed tool-call recovery",
    description: "Internal recovery tool for malformed Muse tool calls. Do not call directly.",
    parameters: Type.Object({}, { additionalProperties: true }),
    prepareArguments: () => ({}),
    execute: async () => ({
      content: [{ type: "text", text: "Muse emitted a tool call without a function name. Retry using a named available tool." }],
      details: {},
      isError: true,
    }),
  });

  pi.on("message_end", (event: any) => {
    const message = repairAssistantMessage(event.message);
    return message === event.message ? undefined : { message };
  });

  pi.on("before_provider_request", (event: any) => {
    return repairChatPayload(event.payload);
  });
}
