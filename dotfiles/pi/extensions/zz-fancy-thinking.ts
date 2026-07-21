import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext, WorkingIndicatorOptions } from "@earendil-works/pi-coding-agent";

type Config = {
  animationInterval?: number;
  spinner?: string[];
  spinnerText?: string[];
};

const DEFAULT_SPINNER = ["⠈⡱", "⢀⡱", "⢄⡰", "⢆⡠", "⢎⡀", "⢎⠁", "⠎⠑", "⠊⠱"];
const DEFAULT_SPINNER_TEXT = ["Thinking"];
const DEFAULT_ANIMATION_INTERVAL = 80;

function piAgentDir() {
  return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".config", "pi");
}

function configPath() {
  return join(piAgentDir(), "extensions", "fancy-thinking", "config.json");
}

function validStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.length > 0 && value.every((item) => typeof item === "string" && item.length > 0);
}

function readConfig(): Required<Config> {
  const fallback = {
    animationInterval: DEFAULT_ANIMATION_INTERVAL,
    spinner: DEFAULT_SPINNER,
    spinnerText: DEFAULT_SPINNER_TEXT,
  };
  const file = configPath();
  if (!existsSync(file)) return fallback;

  try {
    const parsed = JSON.parse(readFileSync(file, "utf8")) as Config;
    const animationInterval = typeof parsed.animationInterval === "number" && parsed.animationInterval > 0
      ? parsed.animationInterval
      : fallback.animationInterval;
    const spinner = validStringArray(parsed.spinner) ? parsed.spinner : fallback.spinner;
    const spinnerText = validStringArray(parsed.spinnerText) ? parsed.spinnerText : fallback.spinnerText;
    return { animationInterval, spinner, spinnerText };
  } catch {
    return fallback;
  }
}

function pick<T>(items: T[]): T {
  return items[Math.floor(Math.random() * items.length)]!;
}

function indicator(ctx: ExtensionContext, config: Required<Config>): WorkingIndicatorOptions {
  return {
    frames: config.spinner.map((frame) => ctx.ui.theme.fg("thinkingText", frame)),
    intervalMs: config.animationInterval,
  };
}

function apply(ctx: ExtensionContext, config: Required<Config>) {
  if (!ctx.hasUI) return;
  ctx.ui.setWorkingIndicator(indicator(ctx, config));
  ctx.ui.setWorkingMessage(ctx.ui.theme.fg("thinkingText", pick(config.spinnerText)));
}

export default function fancyThinking(pi: ExtensionAPI) {
  let config = readConfig();

  pi.on("session_start", async (_event, ctx) => {
    config = readConfig();
    apply(ctx, config);
  });

  pi.on("agent_start", async (_event, ctx) => {
    config = readConfig();
    apply(ctx, config);
  });

  pi.on("thinking_level_select", async (_event, ctx) => {
    apply(ctx, config);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (!ctx.hasUI) return;
    ctx.ui.setWorkingMessage();
    ctx.ui.setWorkingIndicator();
  });

  pi.registerCommand("fancy-thinking", {
    description: "Reload/show the fancy thinking loading text config",
    handler: async (args, ctx) => {
      const command = args.trim().toLowerCase();
      if (command && command !== "reload") {
        ctx.ui.notify(`Usage: /fancy-thinking [reload]`, "warning");
        return;
      }
      config = readConfig();
      apply(ctx, config);
      ctx.ui.notify(`Fancy thinking loaded ${config.spinner.length} frame(s), ${config.spinnerText.length} text item(s) from ${configPath()}`, "info");
    },
  });
}
