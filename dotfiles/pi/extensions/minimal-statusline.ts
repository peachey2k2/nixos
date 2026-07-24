import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

const CODEX_STATUS_KEY = "codex-usage";
const GOAL_STATUS_KEY = "goal";
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
  if (usage?.percent === null || usage?.percent === undefined) return "?% ctx";
  return `${Math.round(usage.percent)}% ctx`;
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

function codexLabels(statuses: ReadonlyMap<string, string>): {
  fiveHour?: string;
  weekly?: string;
  unavailable?: string;
} {
  const status = statuses.get(CODEX_STATUS_KEY);
  if (!status) return {};

  const fiveHour = status.match(/(\d+)%\s+5h/i)?.[1];
  const weekly = status.match(/(\d+)%\s+wk/i)?.[1];
  if (fiveHour || weekly) {
    return {
      fiveHour: fiveHour ? `${fiveHour}% 5h` : undefined,
      weekly: weekly ? `${weekly}% wk` : undefined,
    };
  }

  if (/checking|error|unavailable/i.test(status)) return { unavailable: "codex=?" };
  return {};
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
          const mode = modeLabel(statuses, pi);
          const coloredMode = mode === "readonly"
            ? theme.fg("warning", mode)
            : mode === "ad-hoc"
              ? theme.fg("error", mode)
              : theme.fg("accent", mode);
          const modelAndVariant = [
            theme.fg("accent", modelLabel(ctx)),
            theme.fg("warning", pi.getThinkingLevel()),
          ].join(theme.fg("dim", ":"));
          const codex = codexLabels(statuses);
          const goal = statuses.get(GOAL_STATUS_KEY)?.replace(ANSI_PATTERN, "");
          const parts = [
            coloredMode,
            goal ? theme.fg("syntaxKeyword", goal) : undefined,
            modelAndVariant,
            theme.fg("success", contextLabel(ctx)),
            theme.fg("syntaxNumber", `$${cachedSessionCost.toFixed(2)}`),
            codex.fiveHour ? theme.fg("syntaxKeyword", codex.fiveHour) : undefined,
            codex.weekly ? theme.fg("customMessageLabel", codex.weekly) : undefined,
            codex.unavailable ? theme.fg("dim", codex.unavailable) : undefined,
          ].filter((part): part is string => Boolean(part));

          const line = parts.join(theme.fg("dim", " • "));
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
