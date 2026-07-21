import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function textFromContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";

  return content
    .map((part) => {
      if (typeof part === "string") return part;
      if (!isRecord(part)) return "";
      if (typeof part.text === "string") return part.text;
      if (typeof part.content === "string") return part.content;
      if (part.type === "image") return "[image]";
      return "";
    })
    .filter(Boolean)
    .join("\n");
}

function messageText(entry: Record<string, unknown>): string {
  const message = entry.message;
  if (!isRecord(message)) return "";
  return textFromContent(message.content);
}

function messageRole(entry: Record<string, unknown>): string {
  const message = entry.message;
  if (!isRecord(message)) return "unknown";
  return typeof message.role === "string" ? message.role : "unknown";
}

function toolInfo(entry: Record<string, unknown>): string | undefined {
  const message = entry.message;
  if (!isRecord(message)) return undefined;
  const toolName = typeof message.toolName === "string" ? message.toolName : undefined;
  if (message.role === "toolResult") return toolName ? `tool result: ${toolName}` : "tool result";
  return undefined;
}

function formatHistory(ctx: ExtensionContext): string {
  const lines: string[] = [
    "# Pi chat history",
    "",
    `- cwd: \`${ctx.cwd}\``,
    `- model: \`${ctx.model?.provider ?? "unknown"}/${ctx.model?.id ?? "unknown"}\``,
    `- exported: ${new Date().toISOString()}`,
    "",
  ];

  const entries = ctx.sessionManager.getBranch();
  for (const rawEntry of entries) {
    if (!isRecord(rawEntry) || rawEntry.type !== "message") continue;

    const role = messageRole(rawEntry);
    const tool = toolInfo(rawEntry);
    const text = messageText(rawEntry).trim();

    if (role === "system") continue;
    if (!text && !tool) continue;

    if (tool) {
      lines.push(`<details><summary>${tool}</summary>`, "", "```text", text, "```", "", "</details>", "");
      continue;
    }

    const title = role === "user" ? "User" : role === "assistant" ? "Assistant" : role;
    lines.push(`## ${title}`, "", text, "");
  }

  return lines.join("\n").replace(/\n{4,}/g, "\n\n\n");
}

function editorCommand(): string | undefined {
  return process.env.VISUAL || process.env.EDITOR;
}

function historyFilePath(ctx: ExtensionContext): string {
  const dir = path.join(tmpdir(), "pi-chat-history");
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  const project = path.basename(ctx.cwd).replace(/[^a-zA-Z0-9._-]+/g, "-") || "session";
  return path.join(dir, `${project}-${Date.now()}.md`);
}

async function openInEditor(tui: { stop(): void; start(): void; requestRender(force?: boolean): void }, file: string): Promise<number | null> {
  const command = editorCommand();
  if (!command) return null;

  tui.stop();
  try {
    process.stdout.write(`Opening chat history in $EDITOR: ${command}\nPi will resume when the editor exits.\n`);
    return await new Promise<number | null>((resolve) => {
      const child = spawn(command, [file], {
        stdio: "inherit",
        shell: true,
      });
      child.on("error", () => resolve(null));
      child.on("close", (code) => resolve(code));
    });
  } finally {
    tui.start();
    tui.requestRender(true);
  }
}

async function showHistoryInEditor(ctx: ExtensionContext): Promise<void> {
  if (!ctx.hasUI) return;

  const command = editorCommand();
  if (!command) {
    ctx.ui.notify("Set $EDITOR or $VISUAL to open chat history.", "warning");
    return;
  }

  const file = historyFilePath(ctx);
  writeFileSync(file, formatHistory(ctx), "utf8");

  await ctx.ui.custom<void>((tui, theme, _keybindings, done) => {
    const status = new Text(theme.fg("muted", `Opening chat history in ${command}...`), 1, 0);

    setTimeout(() => {
      void openInEditor(tui, file).then((code) => {
        if (code !== 0) {
          ctx.ui.notify(`Editor exited with ${code === null ? "an error" : `code ${code}`}. History kept at ${file}`, "warning");
        } else {
          try {
            rmSync(file, { force: true });
          } catch {
            // Ignore cleanup errors.
          }
        }
        done();
      });
    }, 0);

    return status;
  });
}

export default function historyEditor(pi: ExtensionAPI) {
  pi.registerShortcut("ctrl+h", {
    description: "Open chat history in $EDITOR",
    handler: async (ctx) => {
      await showHistoryInEditor(ctx);
    },
  });

  pi.registerCommand("history-editor", {
    description: "Open chat history in $EDITOR",
    handler: async (_args, ctx) => {
      await showHistoryInEditor(ctx);
    },
  });
}
