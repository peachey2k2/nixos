import { createConnection, type Socket } from "node:net";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { StringEnum, Type } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

interface ReborderWindow {
  id: number;
  title: string | null;
  app_id: string | null;
  focused: boolean;
  x: number;
  y: number;
  width: number;
  height: number;
}

interface WindowGroup {
  name: string;
  windows: ReborderWindow[];
}

interface Screenshot {
  data: Buffer;
  width: number;
  height: number;
  originX: number;
  originY: number;
}

interface PointerState {
  width: number;
  height: number;
  originX: number;
  originY: number;
}

interface ControlResponse {
  ok: boolean;
  result?: unknown;
  error?: string;
}

const MAX_RESPONSE_BYTES = 1024 * 1024;
const MAX_TYPED_BYTES = 100 * 1024;
const CONTROL_TIMEOUT_MS = 30_000;
const BTN_LEFT = 0x110;
const BTN_RIGHT = 0x111;
const BTN_MIDDLE = 0x112;

let interactionTail: Promise<void> = Promise.resolve();

function withInteractionLock<T>(work: () => Promise<T>): Promise<T> {
  const result = interactionTail.then(work, work);
  interactionTail = result.then(
    () => undefined,
    () => undefined,
  );
  return result;
}

function runtimeDir(): string {
  const configured = process.env.XDG_RUNTIME_DIR?.trim();
  if (configured) return path.resolve(configured);
  if (typeof process.getuid === "function") return `/run/user/${process.getuid()}`;
  throw new Error("XDG_RUNTIME_DIR is not set and the current user ID is unavailable");
}

async function controlPath(): Promise<string> {
  const configured = process.env.REBORDER_CONTROL?.trim();
  if (configured) return path.resolve(configured);

  const metadataPath = path.join(runtimeDir(), "reborder.json");
  let metadata: { control_socket?: unknown };
  try {
    metadata = JSON.parse(await readFile(metadataPath, "utf8")) as { control_socket?: unknown };
  } catch (error) {
    throw new Error(
      `No live reborder session was discovered at ${metadataPath}. Start reborder headlessly or set REBORDER_CONTROL. ${String(error)}`,
    );
  }
  if (typeof metadata.control_socket !== "string" || metadata.control_socket.length === 0) {
    throw new Error(`Invalid reborder metadata at ${metadataPath}: control_socket is missing`);
  }
  return metadata.control_socket;
}

async function sendControl(request: Record<string, unknown>, signal?: AbortSignal): Promise<unknown> {
  if (signal?.aborted) throw new Error("Cancelled");
  const socketPath = await controlPath();

  return await new Promise<unknown>((resolve, reject) => {
    let socket: Socket | undefined;
    let settled = false;
    let bytes = 0;
    let response = "";

    const finish = (error?: Error, value?: unknown) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      signal?.removeEventListener("abort", abort);
      socket?.destroy();
      if (error) reject(error);
      else resolve(value);
    };

    const abort = () => finish(new Error("Cancelled"));
    signal?.addEventListener("abort", abort, { once: true });
    const timer = setTimeout(
      () => finish(new Error(`reborder control request timed out after ${CONTROL_TIMEOUT_MS}ms`)),
      CONTROL_TIMEOUT_MS,
    );

    socket = createConnection(socketPath);
    socket.setEncoding("utf8");
    socket.on("error", (error) => finish(new Error(`Could not connect to reborder at ${socketPath}: ${error.message}`)));
    socket.on("connect", () => {
      socket?.write(`${JSON.stringify(request)}\n`);
    });
    socket.on("data", (chunk: string) => {
      bytes += Buffer.byteLength(chunk);
      if (bytes > MAX_RESPONSE_BYTES) {
        finish(new Error(`reborder response exceeded ${MAX_RESPONSE_BYTES} bytes`));
        return;
      }
      response += chunk;
      const newline = response.indexOf("\n");
      if (newline < 0) return;

      let parsed: ControlResponse;
      try {
        parsed = JSON.parse(response.slice(0, newline)) as ControlResponse;
      } catch (error) {
        finish(new Error(`reborder returned invalid JSON: ${String(error)}`));
        return;
      }
      if (!parsed.ok) {
        finish(new Error(parsed.error || "reborder rejected the request"));
      } else {
        finish(undefined, parsed.result ?? {});
      }
    });
    socket.on("end", () => {
      if (!settled && !response.includes("\n")) {
        finish(new Error("reborder closed the control connection without a complete response"));
      }
    });
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function numberField(value: Record<string, unknown>, key: string): number {
  const field = value[key];
  if (typeof field !== "number" || !Number.isFinite(field)) {
    throw new Error(`reborder response has an invalid ${key}`);
  }
  return field;
}

async function getWindows(signal?: AbortSignal): Promise<ReborderWindow[]> {
  const value = await sendControl({ op: "list_windows" }, signal);
  if (!Array.isArray(value)) throw new Error("reborder returned an invalid window list");
  return value.map((entry) => {
    if (!isRecord(entry)) throw new Error("reborder returned an invalid window entry");
    return {
      id: numberField(entry, "id"),
      title: typeof entry.title === "string" ? entry.title : null,
      app_id: typeof entry.app_id === "string" ? entry.app_id : null,
      focused: entry.focused === true,
      x: numberField(entry, "x"),
      y: numberField(entry, "y"),
      width: numberField(entry, "width"),
      height: numberField(entry, "height"),
    };
  });
}

function aliasFor(window: ReborderWindow): string {
  const appId = window.app_id?.trim();
  if (appId) return appId;
  return `Window ${window.id}`;
}

function groupWindows(windows: ReborderWindow[]): WindowGroup[] {
  const groups = new Map<string, WindowGroup>();
  for (const window of windows) {
    const name = aliasFor(window);
    const key = name.toLocaleLowerCase();
    const group = groups.get(key) ?? { name, windows: [] };
    group.windows.push(window);
    groups.set(key, group);
  }
  for (const group of groups.values()) {
    group.windows.sort((left, right) => Number(right.focused) - Number(left.focused) || left.id - right.id);
  }
  return [...groups.values()].sort((left, right) => left.name.localeCompare(right.name));
}

function selectWindow(groups: WindowGroup[], name: string, instance?: number): { name: string; instance: number; window: ReborderWindow } {
  const group = groups.find((candidate) => candidate.name === name)
    ?? groups.find((candidate) => candidate.name.toLocaleLowerCase() === name.toLocaleLowerCase());
  const available = groups.map((candidate) => candidate.name).join(", ") || "none";
  if (!group) throw new Error(`Unknown reborder window ${JSON.stringify(name)}. Available: ${available}`);
  if (instance === undefined && group.windows.length > 1) {
    throw new Error(`${JSON.stringify(group.name)} has ${group.windows.length} instances; pass instance from 1 to ${group.windows.length}`);
  }
  const selectedInstance = instance ?? 1;
  if (!Number.isInteger(selectedInstance) || selectedInstance < 1 || selectedInstance > group.windows.length) {
    throw new Error(`Instance ${selectedInstance} is unavailable for ${JSON.stringify(group.name)}`);
  }
  return { name: group.name, instance: selectedInstance, window: group.windows[selectedInstance - 1]! };
}

async function ensureWindow(id: number, signal?: AbortSignal): Promise<ReborderWindow> {
  const window = (await getWindows(signal)).find((candidate) => candidate.id === id);
  if (!window) throw new Error(`Reborder window ${id} closed`);
  return window;
}

function pngDimensions(data: Buffer): { width: number; height: number } {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (data.length < 24 || !data.subarray(0, 8).equals(signature)) {
    throw new Error("reborder did not produce a valid PNG");
  }
  return { width: data.readUInt32BE(16), height: data.readUInt32BE(20) };
}

async function captureWindow(window: ReborderWindow, signal?: AbortSignal): Promise<Screenshot> {
  const directory = await mkdtemp(path.join(tmpdir(), "pi-reborder-window-"));
  const screenshotPath = path.join(directory, "window.png");
  try {
    const value = await sendControl({ op: "screenshot", path: screenshotPath, window: window.id }, signal);
    if (!isRecord(value)) throw new Error("reborder returned invalid screenshot metadata");
    const data = await readFile(screenshotPath);
    const dimensions = pngDimensions(data);
    const width = typeof value.width === "number" ? value.width : dimensions.width;
    const height = typeof value.height === "number" ? value.height : dimensions.height;
    return {
      data,
      width,
      height,
      originX: typeof value.origin_x === "number" ? value.origin_x : window.x,
      originY: typeof value.origin_y === "number" ? value.origin_y : window.y,
    };
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}

function imageContent(name: string, instance: number, screenshot: Screenshot) {
  return [
    {
      type: "text" as const,
      text: `Captured ${name} (instance ${instance}) at ${screenshot.width}x${screenshot.height}. Mouse coordinates use this image's pixel grid.`,
    },
    { type: "image" as const, data: screenshot.data.toString("base64"), mimeType: "image/png" },
  ];
}

function sleep(milliseconds: number, signal?: AbortSignal): Promise<void> {
  if (!Number.isFinite(milliseconds) || milliseconds < 0 || milliseconds > 30_000) {
    throw new Error("wait duration must be between 0 and 30000ms");
  }
  if (signal?.aborted) return Promise.reject(new Error("Cancelled"));
  return new Promise((resolve, reject) => {
    const timer = setTimeout(done, milliseconds);
    const abort = () => {
      clearTimeout(timer);
      signal?.removeEventListener("abort", abort);
      reject(new Error("Cancelled"));
    };
    function done() {
      signal?.removeEventListener("abort", abort);
      resolve();
    }
    signal?.addEventListener("abort", abort, { once: true });
  });
}

function validateCoordinate(value: unknown, label: string, maximum: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value >= maximum) {
    throw new Error(`${label} must be between 0 and ${Math.max(0, maximum - 1)}`);
  }
  return value;
}

function mouseButton(value: unknown): number {
  if (value === undefined || value === "left") return BTN_LEFT;
  if (value === "right") return BTN_RIGHT;
  if (value === "middle") return BTN_MIDDLE;
  throw new Error(`Unsupported mouse button ${JSON.stringify(value)}`);
}

async function movePointer(pointer: PointerState, xValue: unknown, yValue: unknown, signal?: AbortSignal): Promise<void> {
  const x = validateCoordinate(xValue, "x", pointer.width);
  const y = validateCoordinate(yValue, "y", pointer.height);
  await sendControl(
    {
      op: "pointer_move",
      x: pointer.originX + x,
      y: pointer.originY + y,
      source: "agent",
    },
    signal,
  );
}

const EVDEV_KEYS: Record<string, number> = {
  ESC: 1,
  ESCAPE: 1,
  "1": 2,
  "2": 3,
  "3": 4,
  "4": 5,
  "5": 6,
  "6": 7,
  "7": 8,
  "8": 9,
  "9": 10,
  "0": 11,
  MINUS: 12,
  EQUAL: 13,
  BACKSPACE: 14,
  TAB: 15,
  Q: 16,
  W: 17,
  E: 18,
  R: 19,
  T: 20,
  Y: 21,
  U: 22,
  I: 23,
  O: 24,
  P: 25,
  LEFTBRACE: 26,
  RIGHTBRACE: 27,
  ENTER: 28,
  RETURN: 28,
  CTRL: 29,
  CONTROL: 29,
  A: 30,
  S: 31,
  D: 32,
  F: 33,
  G: 34,
  H: 35,
  J: 36,
  K: 37,
  L: 38,
  SEMICOLON: 39,
  APOSTROPHE: 40,
  GRAVE: 41,
  SHIFT: 42,
  BACKSLASH: 43,
  Z: 44,
  X: 45,
  C: 46,
  V: 47,
  B: 48,
  N: 49,
  M: 50,
  COMMA: 51,
  DOT: 52,
  PERIOD: 52,
  SLASH: 53,
  ALT: 56,
  SPACE: 57,
  CAPSLOCK: 58,
  F1: 59,
  F2: 60,
  F3: 61,
  F4: 62,
  F5: 63,
  F6: 64,
  F7: 65,
  F8: 66,
  F9: 67,
  F10: 68,
  F11: 87,
  F12: 88,
  HOME: 102,
  UP: 103,
  PAGEUP: 104,
  LEFT: 105,
  RIGHT: 106,
  END: 107,
  DOWN: 108,
  PAGEDOWN: 109,
  INSERT: 110,
  DELETE: 111,
  DEL: 111,
  SUPER: 125,
  META: 125,
  LOGO: 125,
};

const MODIFIERS = new Set(["CTRL", "CONTROL", "SHIFT", "ALT", "SUPER", "META", "LOGO"]);

function keyCode(value: string): number {
  const normalized = value.length === 1 ? value.toUpperCase() : value.toUpperCase().replaceAll("_", "");
  const code = EVDEV_KEYS[normalized];
  if (code === undefined) throw new Error(`Unsupported key ${JSON.stringify(value)}`);
  return code;
}

async function pressKeys(values: string[] | undefined, signal?: AbortSignal): Promise<void> {
  if (!values || values.length === 0) throw new Error("key action requires a non-empty keys array");
  const flattened = values.flatMap((value) => value.split("+")).map((value) => value.trim()).filter(Boolean);
  const modifiers = flattened.filter((value) => MODIFIERS.has(value.toUpperCase()));
  const keys = flattened.filter((value) => !MODIFIERS.has(value.toUpperCase()));
  if (keys.length === 0) throw new Error("key action requires at least one non-modifier key");

  const pressed: number[] = [];
  try {
    for (const modifier of modifiers) {
      const code = keyCode(modifier);
      await sendControl({ op: "key", code, state: "pressed", source: "agent" }, signal);
      pressed.push(code);
    }
    for (const key of keys) {
      await sendControl({ op: "keypress", code: keyCode(key), source: "agent" }, signal);
    }
  } finally {
    for (const code of pressed.reverse()) {
      await sendControl({ op: "key", code, state: "released", source: "agent" }).catch(() => undefined);
    }
  }
}

function textByteLength(value: string): number {
  return Buffer.byteLength(value, "utf8");
}

async function typeText(text: unknown, signal?: AbortSignal): Promise<void> {
  if (typeof text !== "string") throw new Error("type action requires text");
  if (textByteLength(text) > MAX_TYPED_BYTES) {
    throw new Error(`type text is limited to ${MAX_TYPED_BYTES} UTF-8 bytes`);
  }
  await sendControl({ op: "type_text", text, source: "agent" }, signal);
}

const ActionType = StringEnum([
  "click",
  "double_click",
  "move",
  "drag",
  "scroll",
  "type",
  "key",
  "wait",
] as const);

const MouseButton = StringEnum(["left", "right", "middle"] as const);

const InteractionAction = Type.Object({
  type: ActionType,
  x: Type.Optional(Type.Number({ description: "Target x coordinate in screenshot pixels" })),
  y: Type.Optional(Type.Number({ description: "Target y coordinate in screenshot pixels" })),
  fromX: Type.Optional(Type.Number({ description: "Drag start x coordinate in screenshot pixels" })),
  fromY: Type.Optional(Type.Number({ description: "Drag start y coordinate in screenshot pixels" })),
  button: Type.Optional(MouseButton),
  deltaX: Type.Optional(Type.Number({ description: "Horizontal scroll amount" })),
  deltaY: Type.Optional(Type.Number({ description: "Vertical scroll amount" })),
  text: Type.Optional(Type.String({ description: "Text for type" })),
  keys: Type.Optional(Type.Array(Type.String(), { description: 'Simultaneous keys, e.g. ["CTRL", "L"]' })),
  durationMs: Type.Optional(Type.Number({ description: "Duration for wait or drag" })),
});

type Interaction = {
  type: string;
  x?: number;
  y?: number;
  fromX?: number;
  fromY?: number;
  button?: "left" | "right" | "middle";
  deltaX?: number;
  deltaY?: number;
  text?: string;
  keys?: string[];
  durationMs?: number;
};

async function performInteraction(
  selected: { name: string; instance: number; window: ReborderWindow },
  actions: Interaction[],
  screenshotAfter: boolean,
  signal?: AbortSignal,
) {
  if (actions.length === 0) throw new Error("At least one interaction action is required");
  if (actions.length > 50) throw new Error("A window_interact call is limited to 50 actions");
  await sendControl({ op: "focus", id: selected.window.id }, signal);
  const needsPointer = actions.some((action) => ["click", "double_click", "move", "drag"].includes(action.type));
  const initial = needsPointer ? await captureWindow(selected.window, signal) : undefined;
  const pointer = initial
    ? { width: initial.width, height: initial.height, originX: initial.originX, originY: initial.originY }
    : undefined;

  for (const action of actions) {
    if (signal?.aborted) throw new Error("Cancelled");
    await ensureWindow(selected.window.id, signal);

    switch (action.type) {
      case "move":
        await movePointer(pointer!, action.x, action.y, signal);
        break;
      case "click":
        await movePointer(pointer!, action.x, action.y, signal);
        await sendControl({ op: "click", button: mouseButton(action.button), source: "agent" }, signal);
        break;
      case "double_click": {
        await movePointer(pointer!, action.x, action.y, signal);
        const button = mouseButton(action.button);
        await sendControl({ op: "click", button, source: "agent" }, signal);
        await sleep(90, signal);
        await sendControl({ op: "click", button, source: "agent" }, signal);
        break;
      }
      case "drag": {
        const button = mouseButton(action.button);
        await movePointer(pointer!, action.fromX, action.fromY, signal);
        await sendControl({ op: "pointer_button", button, state: "pressed", source: "agent" }, signal);
        try {
          const duration = action.durationMs ?? 300;
          if (!Number.isFinite(duration) || duration < 0 || duration > 10_000) {
            throw new Error("drag duration must be between 0 and 10000ms");
          }
          const targetX = validateCoordinate(action.x, "x", pointer!.width);
          const targetY = validateCoordinate(action.y, "y", pointer!.height);
          const startX = validateCoordinate(action.fromX, "fromX", pointer!.width);
          const startY = validateCoordinate(action.fromY, "fromY", pointer!.height);
          const steps = Math.max(1, Math.min(30, Math.ceil(duration / 25)));
          for (let step = 1; step <= steps; step++) {
            await movePointer(
              pointer!,
              startX + ((targetX - startX) * step) / steps,
              startY + ((targetY - startY) * step) / steps,
              signal,
            );
            if (duration > 0) await sleep(duration / steps, signal);
          }
        } finally {
          await sendControl({ op: "pointer_button", button, state: "released", source: "agent" }).catch(() => undefined);
        }
        break;
      }
      case "scroll": {
        const horizontal = action.deltaX ?? 0;
        const vertical = action.deltaY ?? 0;
        if (!Number.isFinite(horizontal) || !Number.isFinite(vertical)) {
          throw new Error("scroll deltas must be finite numbers");
        }
        await sendControl({ op: "pointer_scroll", horizontal, vertical, source: "agent" }, signal);
        break;
      }
      case "type":
        await typeText(action.text, signal);
        break;
      case "key":
        await pressKeys(action.keys, signal);
        break;
      case "wait":
        await sleep(action.durationMs ?? 250, signal);
        break;
      default:
        throw new Error(`Unsupported interaction action ${JSON.stringify(action.type)}`);
    }
  }

  const finalWindow = await ensureWindow(selected.window.id, signal);
  const screenshot = screenshotAfter ? await captureWindow(finalWindow, signal) : undefined;
  const summary = `Completed ${actions.length} action${actions.length === 1 ? "" : "s"} on ${selected.name} (instance ${selected.instance}).`;
  const content = screenshot
    ? imageContent(selected.name, selected.instance, screenshot)
    : [{ type: "text" as const, text: summary }];
  content[0] = {
    type: "text" as const,
    text: screenshot ? `${summary}\n\nResult screenshot: ${screenshot.width}x${screenshot.height}.` : summary,
  } as (typeof content)[0];

  return {
    content,
    details: {
      name: selected.name,
      instance: selected.instance,
      id: selected.window.id,
      actionCount: actions.length,
      screenshot: screenshot ? { width: screenshot.width, height: screenshot.height } : undefined,
    },
  };
}

export default function windowControl(pi: ExtensionAPI) {
  pi.registerCommand("reborder-status", {
    description: "Show the active hidden reborder session status",
    handler: async (_args, ctx) => {
      try {
        const status = await sendControl({ op: "status" });
        ctx.ui.notify(`Reborder: ${JSON.stringify(status)}`, "info");
      } catch (error) {
        ctx.ui.notify(String(error), "error");
      }
    },
  });

  pi.registerCommand("reborder-self-test", {
    description: "Test direct reborder discovery, control, and capture",
    handler: async (_args, ctx) => {
      try {
        const windows = await getWindows();
        if (windows.length === 0) {
          ctx.ui.notify("Reborder control is healthy; no application windows are open.", "info");
          return;
        }
        const screenshot = await captureWindow(windows[0]!);
        ctx.ui.notify(
          `Reborder control and capture are healthy: ${windows.length} window${windows.length === 1 ? "" : "s"}, first capture ${screenshot.width}x${screenshot.height}.`,
          "info",
        );
      } catch (error) {
        ctx.ui.notify(String(error), "error");
      }
    },
  });

  pi.registerTool({
    name: "window_list",
    label: "Reborder Windows",
    description:
      "List application aliases and instance counts inside the agent's private reborder compositor. Reborder is headless by default, so these windows do not appear on or disrupt the user's desktop.",
    promptSnippet: "List windows in the agent-owned hidden reborder compositor",
    promptGuidelines: [
      "Use window_list before window_observe or window_interact when the reborder alias or instance is unknown.",
    ],
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, signal) {
      const groups = groupWindows(await getWindows(signal));
      const entries = groups.map((group) => ({
        name: group.name,
        instances: group.windows.length,
        permissions: ["see", "input"],
      }));
      const text = entries.length
        ? entries
            .map((entry) => `${entry.name}: ${entry.instances} instance${entry.instances === 1 ? "" : "s"}; permissions=see,input`)
            .join("\n")
        : "The hidden reborder session currently has no application windows.";
      return { content: [{ type: "text" as const, text }], details: { windows: entries } };
    },
    renderCall(_args, theme) {
      return new Text(theme.fg("toolTitle", theme.bold("window_list")), 0, 0);
    },
  });

  pi.registerTool({
    name: "window_observe",
    label: "Observe Reborder Window",
    description:
      "Capture a window in the hidden reborder compositor by alias. Returns a PNG and pixel dimensions; use those dimensions for window_interact coordinates.",
    promptSnippet: "Capture a hidden reborder window without exposing it on the user's desktop",
    promptGuidelines: [
      "Use window_observe to inspect a reborder window before choosing window_interact coordinates.",
    ],
    parameters: Type.Object({
      name: Type.String({ description: "Window alias from window_list" }),
      instance: Type.Optional(Type.Integer({ minimum: 1, description: "1-based instance when an alias has multiple windows" })),
    }),
    async execute(_toolCallId, params, signal) {
      return await withInteractionLock(async () => {
        const selected = selectWindow(groupWindows(await getWindows(signal)), params.name, params.instance);
        const screenshot = await captureWindow(selected.window, signal);
        return {
          content: imageContent(selected.name, selected.instance, screenshot),
          details: {
            name: selected.name,
            instance: selected.instance,
            id: selected.window.id,
            width: screenshot.width,
            height: screenshot.height,
          },
        };
      });
    },
    renderCall(args, theme) {
      const instance = args.instance ? ` [${args.instance}]` : "";
      return new Text(
        `${theme.fg("toolTitle", theme.bold("window_observe "))}${theme.fg("accent", args.name)}${theme.fg("dim", instance)}`,
        0,
        0,
      );
    },
  });

  pi.registerTool({
    name: "window_interact",
    label: "Interact with Reborder Window",
    description:
      "Interact directly with a hidden reborder window by alias. Supports mouse movement, clicks, dragging, scrolling, US-keymap text, key chords, and waits. Coordinates come from window_observe. Actions are serialized and return a fresh PNG by default.",
    promptSnippet: "Control windows through reborder's private protocol without desktop focus or shell automation",
    promptGuidelines: [
      "Use window_interact only with aliases returned by window_list, and base mouse coordinates on the latest window_observe or window_interact image.",
    ],
    parameters: Type.Object({
      name: Type.String({ description: "Window alias from window_list" }),
      instance: Type.Optional(Type.Integer({ minimum: 1, description: "1-based instance when an alias has multiple windows" })),
      actions: Type.Array(InteractionAction, { minItems: 1, maxItems: 50 }),
      screenshotAfter: Type.Optional(Type.Boolean({ description: "Return a fresh screenshot after all actions (default true)" })),
    }),
    async execute(_toolCallId, params, signal) {
      return await withInteractionLock(async () => {
        const selected = selectWindow(groupWindows(await getWindows(signal)), params.name, params.instance);
        return await performInteraction(selected, params.actions, params.screenshotAfter ?? true, signal);
      });
    },
    renderCall(args, theme) {
      const instance = args.instance ? ` [${args.instance}]` : "";
      const count = Array.isArray(args.actions) ? args.actions.length : 0;
      return new Text(
        `${theme.fg("toolTitle", theme.bold("window_interact "))}${theme.fg("accent", args.name)}${theme.fg("dim", `${instance} · ${count} action${count === 1 ? "" : "s"}`)}`,
        0,
        0,
      );
    },
  });

  pi.registerTool({
    name: "window_launch",
    label: "Launch in Reborder",
    description:
      "Launch an application directly inside the hidden reborder compositor. argv is executed without a shell. Returns the child PID; use window_list to discover windows after startup.",
    promptSnippet: "Launch applications in the hidden agent-owned compositor without spawning desktop windows",
    parameters: Type.Object({
      argv: Type.Array(Type.String(), { minItems: 1, maxItems: 128, description: "Program and argument vector; no shell parsing" }),
    }),
    async execute(_toolCallId, params, signal) {
      const result = await sendControl({ op: "launch", argv: params.argv }, signal);
      return {
        content: [{ type: "text" as const, text: `Queued in hidden reborder: ${params.argv[0]}` }],
        details: result,
      };
    },
    renderCall(args, theme) {
      return new Text(
        `${theme.fg("toolTitle", theme.bold("window_launch "))}${theme.fg("accent", args.argv?.[0] ?? "")}`,
        0,
        0,
      );
    },
  });

  pi.registerTool({
    name: "window_close",
    label: "Close Reborder Window",
    description: "Request that a window in the hidden reborder compositor close.",
    promptSnippet: "Close an application window in the hidden agent-owned compositor",
    parameters: Type.Object({
      name: Type.String({ description: "Window alias from window_list" }),
      instance: Type.Optional(Type.Integer({ minimum: 1, description: "1-based instance when an alias has multiple windows" })),
    }),
    async execute(_toolCallId, params, signal) {
      return await withInteractionLock(async () => {
        const selected = selectWindow(groupWindows(await getWindows(signal)), params.name, params.instance);
        await sendControl({ op: "close", id: selected.window.id }, signal);
        return {
          content: [{ type: "text" as const, text: `Close requested for ${selected.name} (instance ${selected.instance}).` }],
          details: { name: selected.name, instance: selected.instance, id: selected.window.id },
        };
      });
    },
    renderCall(args, theme) {
      const instance = args.instance ? ` [${args.instance}]` : "";
      return new Text(
        `${theme.fg("toolTitle", theme.bold("window_close "))}${theme.fg("accent", args.name)}${theme.fg("dim", instance)}`,
        0,
        0,
      );
    },
  });
}
