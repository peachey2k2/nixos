import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

const CODEX_STATUS_KEY = "codex-usage";
const PRESET_STATUS_KEY = "preset";
const ANSI_PATTERN = /[\u001B\u009B][[\]()#;?]*(?:(?:(?:[a-zA-Z\d]*(?:;[a-zA-Z\d]*)*)?\u0007)|(?:(?:\d{1,4}(?:;\d{0,4})*)?[\dA-PR-TZcf-nq-uy=><~]))/g;

function sessionCost(ctx: ExtensionContext): number {
  let cost = 0;
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message" || entry.message.role !== "assistant") continue;
    const message = entry.message as AssistantMessage;
    cost += message.usage?.cost?.total ?? 0;
  }
  return cost;
}

function modelLabel(ctx: ExtensionContext): string {
  return ctx.model?.id ?? "no-model";
}

function contextLabel(ctx: ExtensionContext): string {
  const usage = ctx.getContextUsage();
  if (usage?.percent === null || usage?.percent === undefined) return "ctx=?";
  return `ctx=${Math.round(usage.percent)}%`;
}

function modeLabel(statuses: ReadonlyMap<string, string>, pi: ExtensionAPI): string {
  const status = statuses.get(PRESET_STATUS_KEY)?.replace(ANSI_PATTERN, "");
  const preset = status?.match(/preset:([^\s]+)/)?.[1];
  if (preset) return preset;

  const active = new Set(pi.getActiveTools());
  if (active.has("edit") || active.has("write") || active.has("bash")) return "normal";
  if (active.has("read")) return "readonly";
  return "ad-hoc";
}

function codexLabel(statuses: ReadonlyMap<string, string>): string | undefined {
  const status = statuses.get(CODEX_STATUS_KEY);
  if (!status) return undefined;

  const fiveHour = status.match(/(\d+)%\s+5h/i)?.[1];
  const weekly = status.match(/(\d+)%\s+wk/i)?.[1];
  const windows = [
    fiveHour ? `5h=${fiveHour}%` : undefined,
    weekly ? `w=${weekly}%` : undefined,
  ].filter((window): window is string => Boolean(window));
  if (windows.length > 0) return windows.join(" ");

  if (/checking/i.test(status)) return "codex=?";
  if (/error|unavailable/i.test(status)) return "codex=?";
  return undefined;
}

export default function minimalStatusline(pi: ExtensionAPI) {
  let requestRender: (() => void) | undefined;
  let cachedSessionCost = 0;

  function renderNow() {
    requestRender?.();
  }

  function install(ctx: ExtensionContext) {
    if (!ctx.hasUI) return;
    cachedSessionCost = sessionCost(ctx);

    ctx.ui.setFooter((tui, theme, footerData) => {
      requestRender = () => tui.requestRender();
      const unsubscribeBranch = footerData.onBranchChange(() => {
        cachedSessionCost = sessionCost(ctx);
        tui.requestRender();
      });

      return {
        dispose() {
          unsubscribeBranch();
          requestRender = undefined;
        },
        invalidate() {},
        render(width: number): string[] {
          const statuses = footerData.getExtensionStatuses();
          const parts = [
            modeLabel(statuses, pi),
            `${modelLabel(ctx)}:${pi.getThinkingLevel()}`,
            contextLabel(ctx),
            `$${cachedSessionCost.toFixed(2)}`,
            codexLabel(statuses),
          ].filter((part): part is string => Boolean(part));

          const line = theme.fg("dim", parts.join(" • "));
          return ["", truncateToWidth(line, Math.max(0, width), "")];
        },
      };
    });
  }

  pi.on("session_start", async (_event, ctx) => install(ctx));
  pi.on("session_shutdown", async (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setFooter(undefined);
    requestRender = undefined;
  });

  pi.on("agent_start", async () => renderNow());
  pi.on("agent_end", async () => renderNow());
  pi.on("message_end", async () => renderNow());
  pi.on("model_select", async () => renderNow());
  pi.on("thinking_level_select", async () => renderNow());
  pi.on("tool_execution_start", async () => renderNow());
  pi.on("tool_execution_end", async () => renderNow());
  pi.on("session_compact", async () => renderNow());
}
