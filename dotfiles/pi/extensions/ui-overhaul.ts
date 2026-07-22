import path from "node:path";
import { spawn } from "node:child_process";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import {
  AssistantMessageComponent,
  CustomEditor,
  ToolExecutionComponent,
  UserMessageComponent,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type BgName = "userMessageBg" | "customMessageBg" | "toolPendingBg" | "toolSuccessBg" | "toolErrorBg" | "selectedBg";
type ThemeLike = {
  bg(color: BgName, text: string): string;
  fg(color: string, text: string): string;
  bold?(text: string): string;
  getBgAnsi?(color: BgName): string;
};
type Renderable = { render(width: number): string[] };
type EditorThemeLike = object;
type CtxWithUi = ExtensionContext & { ui: ExtensionContext["ui"] & { setHiddenThinkingLabel?: (label?: string) => void } };
type TuiLike = { stop(): void; start(): void; requestRender(force?: boolean): void };

type PatchedPrototype = Record<PropertyKey, unknown> & { [PATCHED]?: boolean; [ORIGINALS]?: Record<string, unknown> };
type RenderCacheEntry = { width: number; lines: string[] };

let userRenderCache = new WeakMap<object, RenderCacheEntry>();
let assistantRenderCache = new WeakMap<object, RenderCacheEntry>();
let toolRenderCache = new WeakMap<object, RenderCacheEntry>();

const PATCHED = Symbol.for("me.pi.ui-overhaul.patched");
const ORIGINALS = Symbol.for("me.pi.ui-overhaul.originals");
const NOTIFY_PATCHED = Symbol.for("me.pi.ui-overhaul.notify-patched");
const MARKDOWN_PATCHED = Symbol.for("me.pi.ui-overhaul.markdown-patched");
const THINKING_MARKDOWN_PATCHED = Symbol.for("me.pi.ui-overhaul.thinking-markdown-patched");
const USER_MESSAGE_BG = Symbol.for("me.pi.ui-overhaul.user-message-bg");
const BG_PATTERN = /\x1b\[(?:48;2;\d+;\d+;\d+|48;5;\d+|49)m/g;
const SGR_PATTERN = /\x1b\[[0-9;]*m/g;
const ANSI_PATTERN = /[\u001B\u009B][[\]()#;?]*(?:(?:(?:[a-zA-Z\d]*(?:;[a-zA-Z\d]*)*)?\u0007)|(?:(?:\d{1,4}(?:;\d{0,4})*)?[\dA-PR-TZcf-nq-uy=><~]))/g;
const BORDER_CHARS = /[╭╮╰╯─│]/g;
const commandName = "diff";

let currentCtx: ExtensionContext | undefined;
let currentTui: TuiLike | undefined;
let currentPreset: "normal" | "readonly" | "ad-hoc" | undefined;

function theme(): ThemeLike | undefined {
  return currentCtx?.ui.theme as ThemeLike | undefined;
}

async function openHxInCurrentTerminal(file: string, cwd: string): Promise<number | undefined> {
  if (!currentTui) return undefined;

  try {
    currentTui.stop();
    process.stdout.write(`Opening ${file} in hx. Pi will resume when hx exits.\n`);

    return await new Promise((resolve) => {
      const child = spawn("hx", [file], { cwd, stdio: "inherit" });
      child.on("error", () => resolve(undefined));
      child.on("close", (code) => resolve(code ?? 1));
    });
  } finally {
    currentTui.start();
    currentTui.requestRender(true);
  }
}

function stripBackground(line: string): string {
  return line.replace(BG_PATTERN, "");
}

function isVisiblyBlank(line: string): boolean {
  return visibleWidth(line.replace(ANSI_PATTERN, "")) === 0 || line.replace(ANSI_PATTERN, "").trim() === "";
}

function isSeparatorLine(line: string): boolean {
  const plain = line.replace(ANSI_PATTERN, "").trim();
  return plain.length >= 8 && /^[━─═╾╼╍╎┄┈\s]+$/u.test(plain);
}

function isEditorBorderLine(line: string): boolean {
  const plain = line.replace(ANSI_PATTERN, "").trim();
  return isSeparatorLine(line) || /^─── [↑↓] \d+ more [─\s]*$/u.test(plain);
}

function compactBoxLines(lines: string[]): string[] {
  return lines.filter((line) => !isVisiblyBlank(line) && !isSeparatorLine(line));
}

function padToWidth(line: string, width: number): string {
  const safe = truncateToWidth(line, Math.max(0, width), "", true);
  return safe + " ".repeat(Math.max(0, width - visibleWidth(safe)));
}

function bgAnsi(bg: BgName): string {
  const current = theme();
  if (!current) return "";
  if (typeof current.getBgAnsi === "function") return current.getBgAnsi(bg);
  const marker = "__PI_UI_BG__";
  return current.bg(bg, marker).split(marker)[0] ?? "";
}

function themedBg(line: string, width: number, bg: BgName): string {
  const bgStart = bgAnsi(bg);
  if (!bgStart) return padToWidth(line, width);
  const clean = stripBackground(line);
  const safe = truncateToWidth(clean, Math.max(0, width), "", true);
  const padding = " ".repeat(Math.max(0, width - visibleWidth(safe)));
  return `${bgStart}${safe.replace(SGR_PATTERN, (sgr) => `${sgr}${bgStart}`)}${padding}\x1b[49m`;
}

function themedFg(text: string, fg: string): string {
  return theme()?.fg(fg, text) ?? text;
}

function title(icon: string, label: string, fg: string): string {
  const raw = `${icon} ${label}`;
  const bold = theme()?.bold ? theme()!.bold!(raw) : raw;
  return themedFg(bold, fg);
}

function diffLineBg(line: string, fallback: BgName, failed = false, colorDiff = false): BgName {
  if (failed) return "toolErrorBg";
  if (!colorDiff) return fallback;
  const plain = line.replace(ANSI_PATTERN, "").trimStart();
  if (/^(?:[│┃▌▐▏▎▍▊▉ ]*)\+/.test(plain) || /^\+\s*\d+[|#:\s]/.test(plain) || /^\s*\d+(?:#[A-Za-z0-9]+)?[|:]\s*\+/.test(plain) || /[|│┃]\s*\+/.test(plain)) return "toolSuccessBg";
  if (/^(?:[│┃▌▐▏▎▍▊▉ ]*)-/.test(plain) || /^-\s*\d+[|#:\s]/.test(plain) || /^\s*\d+(?:#[A-Za-z0-9]+)?[|:]\s*-/.test(plain) || /[|│┃]\s*-/.test(plain)) return "toolErrorBg";
  return fallback;
}

function rectangle(lines: string[], width: number, bg: BgName, heading: string, failed = false, colorDiff = false): string[] {
  const body = compactBoxLines(lines);
  return [
    "",
    themedBg(` ${heading}`, width, failed ? "toolErrorBg" : bg),
    ...body.map((line) => themedBg(line, width, diffLineBg(line, bg, failed, colorDiff))),
  ];
}

type MarkdownLike = Renderable & {
  constructor?: { name?: string };
  invalidate?: () => void;
  [MARKDOWN_PATCHED]?: boolean;
  [THINKING_MARKDOWN_PATCHED]?: boolean;
};

type AssistantComponentLike = {
  contentContainer?: { children?: unknown[] };
};

function withoutThinkingLabel(message: AssistantMessage): AssistantMessage {
  let changed = false;
  const content = message.content.map((part) => {
    if (part.type !== "thinking") return part;
    const thinking = part.thinking
      .replace(ANSI_PATTERN, "")
      .replace(/^(?:thinking:\s*)+/iu, "")
      .trimStart();
    if (thinking === part.thinking) return part;
    changed = true;
    return { ...part, thinking };
  });
  return changed ? { ...message, content } : message;
}

function leadingVisibleSpaces(line: string): number {
  const plain = line.replace(ANSI_PATTERN, "");
  const match = plain.match(/^ +/u);
  return match?.[0].length ?? 0;
}

function stripVisibleSpaces(line: string, count: number): string {
  if (count <= 0) return line;
  let stripped = 0;
  let output = "";
  for (let index = 0; index < line.length;) {
    ANSI_PATTERN.lastIndex = index;
    const ansi = ANSI_PATTERN.exec(line);
    if (ansi?.index === index) {
      output += ansi[0];
      index = ANSI_PATTERN.lastIndex;
      continue;
    }

    const char = line[index]!;
    if (char === " " && stripped < count) {
      stripped += 1;
      index += 1;
      continue;
    }
    output += char;
    index += 1;
  }
  ANSI_PATTERN.lastIndex = 0;
  return output;
}

function normalizeCodeBlockLines(lines: string[]): string[] {
  const nonBlankIndents = lines
    .filter((line) => line.replace(ANSI_PATTERN, "").trim().length > 0)
    .map(leadingVisibleSpaces);
  if (nonBlankIndents.length === 0) return lines;

  // Markdown's code renderer adds a shared left gutter. Keep one cell of padding
  // for readability, but remove the common excess so every code line does not
  // look artificially indented inside our background rectangle.
  const commonIndent = Math.min(...nonBlankIndents);
  const stripCount = Math.min(4, Math.max(0, commonIndent - 1));
  return lines.map((line) => stripVisibleSpaces(line, stripCount));
}

function addCodeBlockBackground(lines: string[], width: number): string[] {
  const rendered: string[] = [];
  let inCodeBlock = false;
  let codeBlockLines: string[] = [];

  const flushCodeBlock = () => {
    rendered.push(...normalizeCodeBlockLines(codeBlockLines).map((line) => themedBg(line, width, "toolPendingBg")));
    codeBlockLines = [];
  };

  for (const line of lines) {
    const plain = line.replace(ANSI_PATTERN, "").trimStart();
    const fence = plain.match(/^```\s*([^\s`]*)/u);
    if (fence) {
      if (!inCodeBlock) {
        const language = fence[1] || "code";
        rendered.push(themedBg(` ${themedFg("", "mdCodeBlockBorder")}  ${themedFg(language, "mdCodeBlockBorder")}`, width, "toolPendingBg"));
        inCodeBlock = true;
        codeBlockLines = [];
      } else {
        flushCodeBlock();
        inCodeBlock = false;
      }
      continue;
    }

    if (inCodeBlock) {
      codeBlockLines.push(line);
    } else {
      rendered.push(line);
    }
  }

  if (inCodeBlock) flushCodeBlock();

  return rendered;
}

function decorateAssistantText(component: MarkdownLike): void {
  if (!component[MARKDOWN_PATCHED]) {
    const originalRender = component.render.bind(component);
    component.render = (width: number) => addCodeBlockBackground(originalRender(width), width);
    component[MARKDOWN_PATCHED] = true;
  }
  component.invalidate?.();
}

function removeBoldAnsi(line: string): string {
  return line.replace(/\x1b\[([0-9;]*)m/g, (sequence, parameters: string) => {
    const codes = parameters.split(";");
    if (!codes.includes("1")) return sequence;
    const remaining = codes.filter((code) => code !== "1");
    return remaining.length > 0 ? `\x1b[${remaining.join(";")}m` : "";
  });
}

function decorateThinkingText(component: MarkdownLike): void {
  if (!component[THINKING_MARKDOWN_PATCHED]) {
    const originalRender = component.render.bind(component);
    component.render = (width: number) => originalRender(width).map(removeBoldAnsi);
    component[THINKING_MARKDOWN_PATCHED] = true;
  }
  component.invalidate?.();
}

function decorateAssistantContent(component: AssistantComponentLike, message: AssistantMessage): void {
  const markdown = (component.contentContainer?.children ?? []).filter((child): child is MarkdownLike =>
    Boolean(child && typeof child === "object" && (child as MarkdownLike).constructor?.name === "Markdown"),
  );
  const visibleParts = message.content.filter((part) =>
    (part.type === "text" && part.text.trim()) || (part.type === "thinking" && part.thinking.trim()),
  );
  visibleParts.forEach((part, index) => {
    if (part.type === "text" && markdown[index]) decorateAssistantText(markdown[index]);
    if (part.type === "thinking" && markdown[index]) decorateThinkingText(markdown[index]);
  });
}

function inferPreset(pi: ExtensionAPI): "normal" | "readonly" | "ad-hoc" {
  if (currentPreset) return currentPreset;
  const active = new Set(pi.getActiveTools());
  if (active.has("edit") || active.has("write") || active.has("bash")) return "normal";
  if (active.has("read")) return "readonly";
  return "ad-hoc";
}

function editorBgForPreset(preset: "normal" | "readonly" | "ad-hoc"): BgName {
  if (preset === "normal") return "userMessageBg";
  if (preset === "readonly") return "toolSuccessBg";
  return "toolErrorBg";
}

class BorderlessPresetEditor extends CustomEditor {
  private lastWidth = -1;
  private lastText = "";
  private lastPreset: "normal" | "readonly" | "ad-hoc" = "normal";
  private lastCursor = "0:0";
  private lastAutocompleteVisible = false;
  private lastLines: string[] = [];

  constructor(tui: unknown, editorTheme: EditorThemeLike, keybindings: unknown, private readonly pi: ExtensionAPI) {
    super(tui as never, editorTheme as never, keybindings as never, { paddingX: 1 });
  }

  render(width: number): string[] {
    const text = this.getText();
    const cursor = this.getCursor();
    const cursorKey = `${cursor.line}:${cursor.col}`;
    const preset = inferPreset(this.pi);
    const autocompleteVisible = this.isShowingAutocomplete();
    if (this.lastWidth === width && this.lastText === text && this.lastPreset === preset && this.lastCursor === cursorKey && this.lastAutocompleteVisible === autocompleteVisible) return this.lastLines;

    const bg = editorBgForPreset(preset);
    const innerWidth = Math.max(0, width - 2);
    const rendered = super.render(innerWidth).map(stripBackground);
    const bottomBorderIndex = rendered.findIndex((line, index) => index > 0 && isEditorBorderLine(line));
    const editorLines = bottomBorderIndex >= 0 ? rendered.slice(1, bottomBorderIndex) : (rendered.length > 2 ? rendered.slice(1, -1) : rendered);
    const autocompleteLines = bottomBorderIndex >= 0 ? rendered.slice(bottomBorderIndex + 1) : [];

    const inputLines = (editorLines.length > 0 ? editorLines : [""])
      .map((line) => themedBg(` ${line.replace(BORDER_CHARS, " ")} `, width, bg));
    const completionLines = autocompleteLines.map((line) => padToWidth(` ${line.replace(BORDER_CHARS, " ")} `, width));
    this.lastLines = [...inputLines, ...completionLines];
    this.lastWidth = width;
    this.lastText = text;
    this.lastCursor = cursorKey;
    this.lastPreset = preset;
    this.lastAutocompleteVisible = autocompleteVisible;
    return this.lastLines;
  }

  handleInput(data: string): void {
    super.handleInput(data);
    this.lastWidth = -1;
  }

  invalidate(): void {
    this.lastWidth = -1;
    this.lastText = "";
    this.lastCursor = "0:0";
    this.lastAutocompleteVisible = false;
    this.lastLines = [];
    super.invalidate();
  }
}

function patchOnce(proto: PatchedPrototype, originals: Record<string, unknown>, apply: () => void) {
  if (proto[PATCHED]) return;
  proto[ORIGINALS] = originals;
  apply();
  proto[PATCHED] = true;
}

function restore(proto: PatchedPrototype) {
  const originals = proto[ORIGINALS];
  if (!originals) return;
  for (const [key, value] of Object.entries(originals)) proto[key] = value;
  proto[PATCHED] = false;
  proto[ORIGINALS] = undefined;
}

function invalidateRenderCache(target: object) {
  userRenderCache.delete(target);
  assistantRenderCache.delete(target);
  toolRenderCache.delete(target);
}

function cachedRender(
  cache: WeakMap<object, RenderCacheEntry>,
  target: object,
  width: number,
  render: () => string[],
): string[] {
  const cached = cache.get(target);
  if (cached?.width === width) return cached.lines;
  const lines = render();
  cache.set(target, { width, lines });
  return lines;
}

function installMessagePatches() {
  const userProto = UserMessageComponent.prototype as PatchedPrototype & Renderable;
  patchOnce(userProto, { render: userProto.render, invalidate: userProto.invalidate }, () => {
    userProto.invalidate = function patchedUserInvalidate(this: object): void {
      invalidateRenderCache(this);
      const originalInvalidate = userProto[ORIGINALS]!.invalidate as ((this: object) => void) | undefined;
      originalInvalidate?.call(this);
    };
    userProto.render = function patchedUserRender(this: Renderable & { [USER_MESSAGE_BG]?: BgName } & object, width: number): string[] {
      return cachedRender(userRenderCache, this, width, () => {
        const original = (userProto[ORIGINALS]!.render as (this: Renderable, width: number) => string[]).call(this, width);
        this[USER_MESSAGE_BG] ??= editorBgForPreset(currentPreset ?? "normal");
        return rectangle(original, width, this[USER_MESSAGE_BG], title("", "you", "warning"));
      });
    };
  });

  const assistantProto = AssistantMessageComponent.prototype as PatchedPrototype & AssistantComponentLike & Renderable;
  patchOnce(assistantProto, { render: assistantProto.render, invalidate: assistantProto.invalidate, updateContent: assistantProto.updateContent }, () => {
    assistantProto.invalidate = function patchedAssistantInvalidate(this: AssistantComponentLike & object): void {
      invalidateRenderCache(this);
      const originalInvalidate = assistantProto[ORIGINALS]!.invalidate as ((this: AssistantComponentLike) => void) | undefined;
      originalInvalidate?.call(this);
    };
    assistantProto.updateContent = function patchedAssistantUpdateContent(this: AssistantComponentLike & object, message: AssistantMessage, ...rest: unknown[]): unknown {
      invalidateRenderCache(this);
      const displayMessage = withoutThinkingLabel(message);
      const result = (assistantProto[ORIGINALS]!.updateContent as (this: AssistantComponentLike, message: AssistantMessage, ...args: unknown[]) => unknown)
        .call(this, displayMessage, ...rest);
      decorateAssistantContent(this, displayMessage);
      return result;
    };
    assistantProto.render = function patchedAssistantRender(this: Renderable & object, width: number): string[] {
      return cachedRender(assistantRenderCache, this, width, () =>
        (assistantProto[ORIGINALS]!.render as (this: Renderable, width: number) => string[]).call(this, width),
      );
    };
  });

  const toolProto = ToolExecutionComponent.prototype as PatchedPrototype & Renderable;
  patchOnce(toolProto, {
    render: toolProto.render,
    invalidate: toolProto.invalidate,
    updateArgs: toolProto.updateArgs,
    updateResult: toolProto.updateResult,
    markExecutionStarted: toolProto.markExecutionStarted,
    setArgsComplete: toolProto.setArgsComplete,
    setExpanded: toolProto.setExpanded,
    setShowImages: toolProto.setShowImages,
    setImageWidthCells: toolProto.setImageWidthCells,
  }, () => {
    const clearThen = (name: string) => function patchedToolMethod(this: object, ...args: unknown[]): unknown {
      invalidateRenderCache(this);
      const original = toolProto[ORIGINALS]![name] as ((this: object, ...args: unknown[]) => unknown) | undefined;
      return original?.call(this, ...args);
    };
    toolProto.invalidate = clearThen("invalidate");
    toolProto.updateArgs = clearThen("updateArgs");
    toolProto.updateResult = clearThen("updateResult");
    toolProto.markExecutionStarted = clearThen("markExecutionStarted");
    toolProto.setArgsComplete = clearThen("setArgsComplete");
    toolProto.setExpanded = clearThen("setExpanded");
    toolProto.setShowImages = clearThen("setShowImages");
    toolProto.setImageWidthCells = clearThen("setImageWidthCells");
    toolProto.render = function patchedToolRender(this: Renderable & { toolName?: string; result?: { isError?: boolean } } & object, width: number): string[] {
      return cachedRender(toolRenderCache, this, width, () => {
        const original = (toolProto[ORIGINALS]!.render as (this: Renderable, width: number) => string[]).call(this, width);
        const failed = Boolean(this.result?.isError);
        const colorDiff = this.toolName === "edit" || this.toolName === "write";
        return rectangle(
          original,
          width,
          "toolPendingBg",
          title("", `tool(${this.toolName ?? "unknown"})`, "bashMode"),
          failed,
          colorDiff,
        );
      });
    };
  });
}

function restoreMessagePatches() {
  restore(UserMessageComponent.prototype as PatchedPrototype);
  restore(AssistantMessageComponent.prototype as PatchedPrototype);
  restore(ToolExecutionComponent.prototype as PatchedPrototype);
  userRenderCache = new WeakMap<object, RenderCacheEntry>();
  assistantRenderCache = new WeakMap<object, RenderCacheEntry>();
  toolRenderCache = new WeakMap<object, RenderCacheEntry>();
}

function getStringPath(input: unknown) {
  if (!input || typeof input !== "object" || !("path" in input)) return undefined;
  return typeof input.path === "string" ? input.path : undefined;
}
function toAbsolute(cwd: string, filePath: string) {
  return path.isAbsolute(filePath) ? path.normalize(filePath) : path.resolve(cwd, filePath);
}
function toRelative(cwd: string, filePath: string) {
  const relative = path.relative(cwd, filePath);
  return relative && !relative.startsWith("..") && !path.isAbsolute(relative) ? relative : filePath;
}
function parseGitStatus(output: string, cwd: string) {
  const files = new Set<string>();
  for (const line of output.split("\n")) {
    if (line.length < 4) continue;
    const rawPath = line.slice(3).trim();
    if (!rawPath) continue;
    const targetPath = rawPath.includes(" -> ") ? rawPath.split(" -> ").at(-1) : rawPath;
    if (targetPath) files.add(toAbsolute(cwd, targetPath.replace(/^"|"$/g, "")));
  }
  return files;
}
async function getGitChangedFiles(pi: ExtensionAPI, cwd: string) {
  const result = await pi.exec("git", ["status", "--porcelain", "--untracked-files=all"], { cwd, timeout: 5000 });
  if (result.code !== 0) return new Set<string>();
  return parseGitStatus(result.stdout, cwd);
}
function difference(current: Set<string>, baseline: Set<string>) {
  return new Set([...current].filter((file) => !baseline.has(file)));
}

function suppressPresetNotifications(ctx: ExtensionContext) {
  const ui = ctx.ui as ExtensionContext["ui"] & Record<PropertyKey, unknown>;
  if (ui[NOTIFY_PATCHED]) return;
  const originalNotify = ctx.ui.notify.bind(ctx.ui);
  ctx.ui.notify = ((message: string, level?: Parameters<ExtensionContext["ui"]["notify"]>[1]) => {
    if (/^Preset "[^"]+" activated$/u.test(message) || message === "Preset cleared, defaults restored") return;
    return originalNotify(message, level);
  }) as ExtensionContext["ui"]["notify"];
  ui[NOTIFY_PATCHED] = true;
}

function install(ctx: ExtensionContext, pi: ExtensionAPI) {
  if (!ctx.hasUI) return;
  suppressPresetNotifications(ctx);
  currentCtx = ctx;
  const ui = ctx as CtxWithUi;
  ui.ui.setHiddenThinkingLabel?.("thinking");
  ctx.ui.setWorkingMessage(ctx.ui.theme.fg("thinkingText", "thinking"));
  ctx.ui.setWorkingIndicator({ frames: [ctx.ui.theme.fg("thinkingText", "·")] });
  ctx.ui.setEditorComponent((tui, theme, keybindings) => {
    currentTui = tui as TuiLike;
    return new BorderlessPresetEditor(tui, theme, keybindings, pi);
  });
  installMessagePatches();
}

export default function uiOverhaul(pi: ExtensionAPI) {
  let gitBaseline = new Set<string>();
  let changedFiles = new Set<string>();
  let toolTouchedFiles = new Set<string>();

  pi.events.on("me:mode-changed", (data: unknown) => {
    const mode = (data as { mode?: string | undefined })?.mode;
    currentPreset = mode === "normal" || mode === "readonly" || mode === "ad-hoc" ? mode : undefined;
  });

  pi.on("session_start", async (_event, ctx) => install(ctx, pi));
  pi.on("agent_start", async (_event, ctx) => {
    toolTouchedFiles = new Set();
    changedFiles = new Set();
    gitBaseline = await getGitChangedFiles(pi, ctx.cwd);
  });
  pi.on("tool_result", (event, ctx) => {
    if (event.toolName !== "edit" && event.toolName !== "write") return;
    const filePath = getStringPath(event.input);
    if (filePath) toolTouchedFiles.add(toAbsolute(ctx.cwd, filePath));
  });
  pi.on("agent_end", async (_event, ctx) => {
    const gitChanged = await getGitChangedFiles(pi, ctx.cwd);
    changedFiles = new Set([...difference(gitChanged, gitBaseline), ...toolTouchedFiles]);
    if (changedFiles.size > 0) ctx.ui.notify(`${changedFiles.size} changed file(s). Run /${commandName} to view/open in hx.`, "info");
  });
  pi.on("thinking_level_select", async (_event, ctx) => {
    ctx.ui.setWorkingMessage(ctx.ui.theme.fg("thinkingText", "thinking"));
  });
  pi.on("session_shutdown", async (event, ctx) => {
    if (ctx.hasUI) {
      ctx.ui.setEditorComponent(undefined);
      ctx.ui.setWorkingMessage();
      ctx.ui.setWorkingIndicator();
      (ctx as CtxWithUi).ui.setHiddenThinkingLabel?.();
    }
    currentCtx = undefined;
    currentTui = undefined;
    // Session replacement reloads extensions. Always restore prototype patches here so
    // the replacement extension instance can install fresh patched render methods
    // bound to its own module state. Keeping old closures across /resume caused
    // user-message headings such as "you" to disappear after switching sessions.
    restoreMessagePatches();
  });

  pi.registerCommand("variants", {
    description: "Switch thinking level for the current model",
    handler: async (args, ctx) => {
      const allLevels = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;
      type ThinkingLevel = typeof allLevels[number];
      const aliases: Record<string, ThinkingLevel> = {
        none: "off",
        no: "off",
        false: "off",
        min: "minimal",
        med: "medium",
        extra: "xhigh",
        x: "xhigh",
        ultra: "max",
      };
      const displayLevel = (level: ThinkingLevel): string => level;
      const normalize = (value: string): ThinkingLevel | undefined => {
        const key = value.trim().toLowerCase().replace(/ \(current\)$/u, "");
        return (allLevels as readonly string[]).includes(key) ? key as ThinkingLevel : aliases[key];
      };
      const current = ctx.model as (typeof ctx.model & { reasoning?: boolean; thinkingLevelMap?: Partial<Record<ThinkingLevel, string | null>> }) | undefined;
      const currentLevel = pi.getThinkingLevel() as ThinkingLevel;
      const levels = current?.reasoning
        ? allLevels.filter((level) => current.thinkingLevelMap?.[level] !== null)
        : ["off"] as readonly ThinkingLevel[];

      const arg = args.trim();
      const requested = arg ? normalize(arg) : undefined;
      if (arg && !requested) {
        ctx.ui.notify(`Unknown thinking variant: ${arg}. Use one of: ${allLevels.map(displayLevel).join(", ")}.`, "error");
        return;
      }

      const labels = levels.map((level) => `${displayLevel(level)}${level === currentLevel ? " (current)" : ""}`);
      const selected = requested ?? normalize(await ctx.ui.select(`Thinking variant for ${ctx.model?.id ?? "current model"}`, labels) ?? "");
      if (!selected) return;

      pi.setThinkingLevel(selected);
      const actual = pi.getThinkingLevel() as ThinkingLevel;
      if (actual === selected) {
        ctx.ui.notify(`Thinking variant: ${displayLevel(actual)}`, "info");
      } else {
        ctx.ui.notify(`Thinking variant requested ${displayLevel(selected)}; active is ${displayLevel(actual)} for this model.`, "warning");
      }
    },
  });

  pi.registerCommand(commandName, {
    description: "Show files changed by the last agent run and open one in hx",
    handler: async (args, ctx) => {
      await ctx.waitForIdle();
      const arg = args.trim();
      if (arg === "clear") {
        changedFiles = new Set();
        toolTouchedFiles = new Set();
        gitBaseline = await getGitChangedFiles(pi, ctx.cwd);
        ctx.ui.notify("Cleared changed file list", "info");
        return;
      }
      const files = [...changedFiles].sort((a, b) => toRelative(ctx.cwd, a).localeCompare(toRelative(ctx.cwd, b)));
      if (files.length === 0) {
        ctx.ui.notify("No changed files tracked from the last agent run", "info");
        return;
      }
      if (arg === "list") {
        ctx.ui.notify(`Changed files:\n${files.map((file) => `- ${toRelative(ctx.cwd, file)}`).join("\n")}`, "info");
        return;
      }
      if (arg) {
        ctx.ui.notify(`Unknown /${commandName} argument: ${arg}. Try /${commandName}, /${commandName} list, or /${commandName} clear.`, "warning");
        return;
      }
      const labels = files.map((file) => toRelative(ctx.cwd, file));
      const selected = await ctx.ui.select("Open changed file in hx", labels);
      if (!selected) return;
      const file = files[labels.indexOf(selected)];
      if (!file) return;
      const code = await openHxInCurrentTerminal(file, ctx.cwd);
      ctx.ui.notify(code === 0 ? `Opened ${selected} in hx` : `Failed to open ${selected} in hx`, code === 0 ? "info" : "error");
    },
  });
}
