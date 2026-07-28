import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { KeyId } from "@earendil-works/pi-tui";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
type Preset = {
  provider?: string;
  model?: string;
  thinkingLevel?: ThinkingLevel;
  tools?: string[];
  instructions?: string;
};
type Config = {
  commandName?: string | false;
  flagName?: string;
  cycleShortcut?: KeyId | false;
  defaultTools?: string[];
  presets?: Record<string, Preset>;
};

const DEFAULT_TOOLS = ["read", "bash", "edit", "write"];
const READONLY_BLOCKED_TOOLS = new Set(["bash", "edit", "write"]);
const AD_HOC_ALLOWED_TOOLS = new Set(["web_search", "web_fetch"]);
const STATE_ENTRY = "mode-preset-state";
const MODE_EVENT = "me:mode-changed";

function piAgentDir() {
  return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".config", "pi");
}

function stripJsonComments(text: string) {
  return text
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/^\s*\/\/.*$/gm, "");
}

function readConfig(): Required<Config> {
  const fallback: Required<Config> = {
    commandName: "mode",
    flagName: "mode",
    cycleShortcut: "shift+tab",
    defaultTools: DEFAULT_TOOLS,
    presets: {},
  };
  const file = join(piAgentDir(), "preset.jsonc");
  if (!existsSync(file)) return fallback;
  try {
    const parsed = JSON.parse(stripJsonComments(readFileSync(file, "utf8"))) as Config;
    return {
      commandName: parsed.commandName === false ? false : (parsed.commandName || fallback.commandName),
      flagName: parsed.flagName || fallback.flagName,
      cycleShortcut: parsed.cycleShortcut === false ? false : (parsed.cycleShortcut || fallback.cycleShortcut),
      defaultTools: Array.isArray(parsed.defaultTools) ? parsed.defaultTools : fallback.defaultTools,
      presets: parsed.presets && typeof parsed.presets === "object" ? parsed.presets : fallback.presets,
    };
  } catch {
    return fallback;
  }
}

function presetOrder(presets: Record<string, Preset>) {
  return Object.keys(presets).sort();
}

function lastState(ctx: ExtensionContext): string | null | undefined {
  const entry = ctx.sessionManager
    .getEntries()
    .filter((item: { type: string; customType?: string }) => item.type === "custom" && item.customType === STATE_ENTRY)
    .at(-1) as { data?: { name?: string | null } } | undefined;
  if (!entry?.data || !("name" in entry.data)) return undefined;
  return entry.data.name ?? null;
}

export default function modePreset(pi: ExtensionAPI) {
  let config = readConfig();
  let activeName: string | undefined;
  let activePreset: Preset | undefined;
  let original: { thinkingLevel: ThinkingLevel; tools: string[] } | undefined;

  function publish(ctx: ExtensionContext) {
    ctx.ui.setStatus("preset", activeName ? ctx.ui.theme.fg("accent", `preset:${activeName}`) : undefined);
    pi.events.emit(MODE_EVENT, { mode: activeName });
  }

  function snapshot(_ctx: ExtensionContext) {
    if (original) return;
    original = { thinkingLevel: pi.getThinkingLevel(), tools: pi.getActiveTools() };
  }

  async function apply(name: string, preset: Preset, ctx: ExtensionContext, persist = true) {
    if (persist) snapshot(ctx);
    if (preset.provider && preset.model) {
      const model = ctx.modelRegistry.find(preset.provider, preset.model);
      if (model) await pi.setModel(model);
    }
    if (preset.thinkingLevel) pi.setThinkingLevel(preset.thinkingLevel);
    if (preset.tools?.length) {
      const valid = new Set(pi.getAllTools().map((tool) => tool.name));
      const expanded = preset.tools.flatMap((tool) => {
        if (!tool.endsWith("*")) return [tool];
        const prefix = tool.slice(0, -1);
        return [...valid].filter((name) => name.startsWith(prefix)).sort();
      });
      pi.setActiveTools([...new Set(expanded.filter((tool) => valid.has(tool)))]);
    }
    activeName = name;
    activePreset = preset;
    if (persist) pi.appendEntry(STATE_ENTRY, { name });
    publish(ctx);
  }

  async function clear(ctx: ExtensionContext, persist = true) {
    activeName = undefined;
    activePreset = undefined;
    pi.setThinkingLevel(original?.thinkingLevel ?? pi.getThinkingLevel());
    const valid = new Set(pi.getAllTools().map((tool) => tool.name));
    const expandedDefaults = config.defaultTools.flatMap((tool) => {
      if (!tool.endsWith("*")) return [tool];
      const prefix = tool.slice(0, -1);
      return [...valid].filter((name) => name.startsWith(prefix)).sort();
    });
    pi.setActiveTools(original?.tools ?? [...new Set(expandedDefaults.filter((tool) => valid.has(tool)))]);
    if (persist) pi.appendEntry(STATE_ENTRY, { name: null });
    publish(ctx);
  }

  async function activate(name: string, ctx: ExtensionContext) {
    const preset = config.presets[name];
    if (!preset) {
      ctx.ui.notify(`Unknown mode "${name}". Available: ${presetOrder(config.presets).join(", ") || "(none)"}`, "error");
      return;
    }
    await apply(name, preset, ctx);
  }

  async function choose(selected: string | undefined, ctx: ExtensionContext) {
    if (!selected) return;
    if (selected === "(none)") return clear(ctx);
    return activate(selected.replace(/ \(active\)$/u, ""), ctx);
  }

  pi.registerFlag(config.flagName, { description: "Mode preset to use", type: "string" });

  if (config.cycleShortcut) {
    pi.registerShortcut(config.cycleShortcut, {
      description: "Cycle modes",
      handler: async (ctx) => {
        config = readConfig();
        const names = presetOrder(config.presets);
        const cycle = ["(none)", ...names];
        const current = activeName ?? "(none)";
        await choose(cycle[(cycle.indexOf(current) + 1) % cycle.length] ?? cycle[0], ctx);
      },
    });
  }

  if (config.commandName) {
    pi.registerCommand(config.commandName, {
      description: "Switch mode preset",
      handler: async (args, ctx) => {
        config = readConfig();
        const arg = args.trim();
        if (arg) return choose(arg, ctx);
        const names = presetOrder(config.presets);
        const selected = await ctx.ui.select("Select mode", ["(none)", ...names.map((name) => name === activeName ? `${name} (active)` : name)]);
        await choose(selected, ctx);
      },
    });
  }

  pi.on("session_start", async (event, ctx) => {
    config = readConfig();
    const flag = pi.getFlag(config.flagName);
    if (typeof flag === "string" && flag) await activate(flag, ctx);
    else {
      const restored = lastState(ctx);
      const activeTools = new Set(pi.getActiveTools());
      const looksNormal = activeTools.has("bash") || activeTools.has("edit") || activeTools.has("write");
      if (event.reason === "reload" && looksNormal) {
        activeName = undefined;
        activePreset = undefined;
        if (restored !== null) pi.appendEntry(STATE_ENTRY, { name: null });
        publish(ctx);
        return;
      }

      if (typeof restored === "string" && config.presets[restored]) {
        await apply(restored, config.presets[restored], ctx, false);
      } else if (restored === null) {
        await clear(ctx, false);
      } else {
        publish(ctx);
      }
    }
  });

  pi.on("before_agent_start", async (event) => {
    if (!activePreset?.instructions) return;
    return { systemPrompt: `${event.systemPrompt}\n\n${activePreset.instructions}` };
  });

  pi.on("tool_call", async (event) => {
    // Defense-in-depth: active tool selection is prompt/provider-facing, but this
    // preflight guard enforces restrictive modes even if a model/provider still
    // emits a hidden or stale disallowed tool call.
    if (activeName === "readonly" && READONLY_BLOCKED_TOOLS.has(event.toolName)) {
      return {
        block: true,
        reason: `Readonly mode blocks the ${event.toolName} tool. Switch modes before modifying files or running commands.`,
      };
    }

    if (activeName === "ad-hoc" && !AD_HOC_ALLOWED_TOOLS.has(event.toolName)) {
      return {
        block: true,
        reason: `Ad-hoc mode only allows web_search and web_fetch. Switch modes before using ${event.toolName}.`,
      };
    }
  });

}
