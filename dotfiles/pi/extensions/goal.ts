import { complete } from "@earendil-works/pi-ai/compat";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATE_TYPE = "goal-state";
const STATUS_KEY = "goal";
const MAX_GOAL_LENGTH = 4000;
const MAX_TRANSCRIPT_CHARS = 120_000;
const CLEAR_ALIASES = new Set(["clear", "stop", "off", "reset", "none", "cancel"]);

type GoalStatus = "active" | "paused" | "achieved" | "cleared";

interface GoalState {
  condition: string;
  status: GoalStatus;
  startedAt: number;
  updatedAt: number;
  turns: number;
  baselineTokens: number;
  evaluatorTokens: number;
  lastReason?: string;
  noToolTurns: number;
}

interface Evaluation {
  decision: "complete" | "continue" | "blocked";
  reason: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function textFromContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .map((part) => (isRecord(part) && typeof part.text === "string" ? part.text : ""))
    .filter(Boolean)
    .join("\n");
}

function usageTokens(value: unknown): number {
  if (!isRecord(value)) return 0;
  return typeof value.totalTokens === "number"
    ? value.totalTokens
    : (typeof value.input === "number" ? value.input : 0) +
        (typeof value.output === "number" ? value.output : 0) +
        (typeof value.cacheRead === "number" ? value.cacheRead : 0) +
        (typeof value.cacheWrite === "number" ? value.cacheWrite : 0);
}

function sessionTokens(ctx: ExtensionContext): number {
  let total = 0;
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type === "message" && entry.message.role === "assistant") {
      total += usageTokens(entry.message.usage);
    }
  }
  return total;
}

function elapsed(startedAt: number): string {
  const seconds = Math.max(0, Math.floor((Date.now() - startedAt) / 1000));
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ${seconds % 60}s`;
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
}

function isGoalState(value: unknown): value is GoalState {
  if (!isRecord(value)) return false;
  return (
    typeof value.condition === "string" &&
    ["active", "paused", "achieved", "cleared"].includes(String(value.status)) &&
    typeof value.startedAt === "number" &&
    typeof value.turns === "number"
  );
}

function latestState(ctx: ExtensionContext): GoalState | undefined {
  let found: GoalState | undefined;
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type === "custom" && entry.customType === STATE_TYPE && isGoalState(entry.data)) {
      found = entry.data;
    }
  }
  return found;
}

function transcript(ctx: ExtensionContext): string {
  const sections: string[] = [];
  for (const entry of ctx.sessionManager.buildContextEntries()) {
    if (entry.type === "message") {
      const message = entry.message;
      const text = textFromContent(message.content).trim();
      if (!text) continue;
      const label = message.role === "toolResult" ? `Tool result (${message.toolName})` : message.role;
      sections.push(`${label}:\n${text}`);
    } else if (entry.type === "compaction") {
      sections.push(`Earlier conversation summary:\n${entry.summary}`);
    } else if (entry.type === "branch_summary") {
      sections.push(`Branch summary:\n${entry.summary}`);
    } else if (entry.type === "custom_message" && entry.customType === STATE_TYPE) {
      const text = textFromContent(entry.content).trim();
      if (text) sections.push(`Goal controller:\n${text}`);
    }
  }
  const full = sections.join("\n\n");
  return full.length <= MAX_TRANSCRIPT_CHARS
    ? full
    : `[Earlier transcript omitted]\n\n${full.slice(-MAX_TRANSCRIPT_CHARS)}`;
}

function parseEvaluation(text: string): Evaluation | undefined {
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) return undefined;
  try {
    const value = JSON.parse(match[0]) as unknown;
    if (!isRecord(value)) return undefined;
    if (!["complete", "continue", "blocked"].includes(String(value.decision))) return undefined;
    if (typeof value.reason !== "string" || !value.reason.trim()) return undefined;
    return { decision: value.decision as Evaluation["decision"], reason: value.reason.trim() };
  } catch {
    return undefined;
  }
}

function evaluatorPrompt(condition: string, conversation: string): string {
  return [
    "You are an independent goal evaluator. Judge only from concrete evidence in the transcript.",
    "Return exactly one JSON object and no markdown:",
    '{"decision":"complete|continue|blocked","reason":"short evidence-based reason"}',
    "Use complete only when every part of the condition is demonstrably satisfied.",
    "Use blocked only when progress requires user input or no defensible path remains.",
    "Otherwise use continue and identify the most important missing evidence or next step.",
    "",
    `<goal>${condition}</goal>`,
    "<transcript>",
    conversation,
    "</transcript>",
  ].join("\n");
}

export default function goalExtension(pi: ExtensionAPI) {
  let state: GoalState | undefined;
  let evaluating = false;
  let generation = 0;
  let toolUsedThisRun = false;

  const persist = () => {
    if (state) pi.appendEntry(STATE_TYPE, { ...state });
  };

  const updateStatus = (ctx: ExtensionContext) => {
    if (!ctx.hasUI) return;
    if (!state || state.status === "cleared") {
      ctx.ui.setStatus(STATUS_KEY, undefined);
      return;
    }
    const symbol = state.status === "active" ? "◎" : state.status === "achieved" ? "✓" : "Ⅱ";
    ctx.ui.setStatus(STATUS_KEY, `${symbol} goal:${state.status}`);
  };

  const tokenSpend = (ctx: ExtensionContext) =>
    Math.max(0, sessionTokens(ctx) - (state?.baselineTokens ?? 0)) + (state?.evaluatorTokens ?? 0);

  const statusText = (ctx: ExtensionContext) => {
    if (!state || state.status === "cleared") return "No goal set";
    const lines = [
      `Goal (${state.status}): ${state.condition}`,
      `Elapsed: ${elapsed(state.startedAt)} · Evaluations: ${state.turns} · Tokens: ${tokenSpend(ctx)}`,
    ];
    if (state.lastReason) lines.push(`Evaluator: ${state.lastReason}`);
    return lines.join("\n");
  };

  pi.registerCommand("goal", {
    description: "Keep working until a completion condition is satisfied",
    handler: async (rawArgs, ctx) => {
      const args = rawArgs.trim();
      const command = args.toLowerCase();

      if (!args) {
        ctx.ui.notify(statusText(ctx), state?.status === "active" ? "info" : "warning");
        return;
      }

      if (CLEAR_ALIASES.has(command)) {
        generation++;
        if (!state || state.status === "cleared") {
          ctx.ui.notify("No goal set", "warning");
          return;
        }
        const condition = state.condition;
        state = { ...state, status: "cleared", updatedAt: Date.now(), lastReason: "Cleared by user" };
        persist();
        updateStatus(ctx);
        ctx.ui.notify(`Goal cleared: ${condition}`, "info");
        return;
      }

      if (command === "pause") {
        generation++;
        if (!state || state.status !== "active") {
          ctx.ui.notify("No active goal", "warning");
          return;
        }
        state = { ...state, status: "paused", updatedAt: Date.now(), lastReason: "Paused by user" };
        persist();
        updateStatus(ctx);
        ctx.ui.notify("Goal paused", "info");
        return;
      }

      if (command === "resume") {
        if (!state || state.status !== "paused") {
          ctx.ui.notify("No paused goal", "warning");
          return;
        }
        generation++;
        state = { ...state, status: "active", updatedAt: Date.now(), noToolTurns: 0 };
        persist();
        updateStatus(ctx);
        pi.sendMessage(
          {
            customType: STATE_TYPE,
            content: `Goal resumed: ${state.condition}\nContinue working toward it and surface concrete verification evidence.`,
            display: true,
          },
          { triggerTurn: true, deliverAs: "followUp" },
        );
        return;
      }

      if (args.length > MAX_GOAL_LENGTH) {
        ctx.ui.notify(`Goal is too long (${args.length}/${MAX_GOAL_LENGTH} characters)`, "error");
        return;
      }

      generation++;
      state = {
        condition: args,
        status: "active",
        startedAt: Date.now(),
        updatedAt: Date.now(),
        turns: 0,
        baselineTokens: sessionTokens(ctx),
        evaluatorTokens: 0,
        noToolTurns: 0,
      };
      persist();
      updateStatus(ctx);
      pi.sendUserMessage(
        `Work autonomously toward this goal until it is verifiably satisfied:\n\n${args}\n\n` +
          "Use concrete evidence to verify completion. If blocked on user input, explain exactly what is needed.",
      );
    },
  });

  pi.on("session_start", (event, ctx) => {
    state = latestState(ctx);
    evaluating = false;
    generation++;
    updateStatus(ctx);

    if (state?.status === "active" && (event.reason === "startup" || event.reason === "resume")) {
      state = {
        ...state,
        startedAt: Date.now(),
        updatedAt: Date.now(),
        turns: 0,
        baselineTokens: sessionTokens(ctx),
        evaluatorTokens: 0,
        noToolTurns: 0,
      };
      persist();
      queueMicrotask(() => {
        if (state?.status !== "active") return;
        pi.sendMessage(
          {
            customType: STATE_TYPE,
            content: `Restored active goal: ${state.condition}\nContinue working and verify the completion condition.`,
            display: true,
          },
          { triggerTurn: true, deliverAs: "followUp" },
        );
      });
    }
  });

  pi.on("agent_start", () => {
    toolUsedThisRun = false;
  });

  pi.on("tool_execution_start", () => {
    toolUsedThisRun = true;
  });

  pi.on("agent_settled", async (_event, ctx) => {
    if (!state || state.status !== "active" || evaluating || ctx.hasPendingMessages()) return;
    if (!ctx.model) {
      state = { ...state, status: "paused", updatedAt: Date.now(), lastReason: "No model selected" };
      persist();
      updateStatus(ctx);
      return;
    }

    evaluating = true;
    const myGeneration = generation;
    try {
      // Evaluate through the model that just completed the agent turn.  Replacing a
      // Slop model with openai-codex requires unrelated credentials and pauses an
      // otherwise working goal when Codex is not configured.
      const evaluatorModel = ctx.model;
      const auth = await ctx.modelRegistry.getApiKeyAndHeaders(evaluatorModel);
      if (!auth.ok || !auth.apiKey) throw new Error(auth.ok ? "No API key available" : auth.error);

      const response = await complete(
        evaluatorModel,
        {
          messages: [
            {
              role: "user",
              content: [{ type: "text", text: evaluatorPrompt(state.condition, transcript(ctx)) }],
              timestamp: Date.now(),
            },
          ],
        },
        {
          apiKey: auth.apiKey,
          headers: auth.headers,
          env: auth.env,
          reasoningEffort: "minimal",
        },
      );

      if (myGeneration !== generation || !state || state.status !== "active") return;
      const output = response.content
        .filter((part): part is { type: "text"; text: string } => part.type === "text")
        .map((part) => part.text)
        .join("\n");
      const evaluation = parseEvaluation(output);
      if (!evaluation) throw new Error("Evaluator returned an invalid decision");

      const noToolTurns = toolUsedThisRun ? 0 : state.noToolTurns + 1;
      state = {
        ...state,
        turns: state.turns + 1,
        updatedAt: Date.now(),
        evaluatorTokens: state.evaluatorTokens + usageTokens(response.usage),
        lastReason: evaluation.reason,
        noToolTurns,
      };

      if (evaluation.decision === "complete") {
        state.status = "achieved";
        persist();
        updateStatus(ctx);
        pi.sendMessage({
          customType: STATE_TYPE,
          content: `Goal achieved: ${state.condition}\nEvaluator: ${evaluation.reason}`,
          display: true,
        });
        return;
      }

      if (evaluation.decision === "blocked" || noToolTurns >= 2) {
        state.status = "paused";
        if (noToolTurns >= 2 && evaluation.decision !== "blocked") {
          state.lastReason = `${evaluation.reason} Automatic continuation paused after two turns without tool use.`;
        }
        persist();
        updateStatus(ctx);
        pi.sendMessage({
          customType: STATE_TYPE,
          content: `Goal paused: ${state.lastReason}\nRun /goal resume after resolving the blocker.`,
          display: true,
        });
        return;
      }

      persist();
      updateStatus(ctx);
      pi.sendMessage(
        {
          customType: STATE_TYPE,
          content: `Goal not yet satisfied. Evaluator: ${evaluation.reason}\nContinue working toward: ${state.condition}`,
          display: true,
        },
        { triggerTurn: true, deliverAs: "followUp" },
      );
    } catch (error) {
      if (myGeneration !== generation || !state || state.status !== "active") return;
      state = {
        ...state,
        status: "paused",
        updatedAt: Date.now(),
        lastReason: `Evaluator failed: ${error instanceof Error ? error.message : String(error)}`,
      };
      persist();
      updateStatus(ctx);
      if (ctx.hasUI) ctx.ui.notify(`${state.lastReason}; goal paused`, "error");
    } finally {
      evaluating = false;
    }
  });

  pi.on("session_shutdown", (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setStatus(STATUS_KEY, undefined);
    generation++;
  });
}
