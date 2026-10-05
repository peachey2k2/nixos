import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

const FIRECRAWL_TOOLS = new Set([
  "firecrawl_scrape",
  "firecrawl_crawl",
  "firecrawl_crawl_status",
  "firecrawl_map",
  "firecrawl_search",
]);

const WRAPPED = Symbol.for("me.pi.firecrawl-display.wrapped");

type Theme = {
  fg(color: string, text: string): string;
  bold(text: string): string;
};

type ToolLike = Record<string, any>;
type ResultLike = {
  content?: Array<{ type?: string; text?: string }>;
  details?: unknown;
  isError?: boolean;
};
type RenderOptions = { expanded?: boolean; isPartial?: boolean };
type RenderContext = { args?: unknown; isError?: boolean };

function bold(theme: Theme, text: string): string {
  return typeof theme.bold === "function" ? theme.bold(text) : text;
}

function title(theme: Theme, verb: string): string {
  return theme.fg("toolTitle", bold(theme, verb));
}

function toRecord(value: unknown): Record<string, any> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, any>)
    : {};
}

function textOf(result: ResultLike): string {
  const part = result.content?.find((p) => p?.type === "text" && typeof p.text === "string");
  return part?.text ?? "";
}

function payloadFrom(result: ResultLike): any {
  if (result.details !== undefined && result.details !== null) {
    if (typeof result.details === "string") {
      try {
        return JSON.parse(result.details);
      } catch {
        return result.details;
      }
    }
    return result.details;
  }
  const text = textOf(result);
  if (!text) return undefined;
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

function isError(result: ResultLike, context?: RenderContext): boolean {
  if (Boolean(result.isError) || Boolean(context?.isError)) return true;
  return textOf(result).startsWith("Error");
}

function errorText(result: ResultLike, theme: Theme, fallback: string): Text {
  const first = textOf(result).split("\n")[0]?.trim() || fallback;
  return new Text(theme.fg("error", first), 0, 0);
}

function truncate(text: string, max: number): string {
  const clean = text.replace(/\s+/g, " ").trim();
  return clean.length > max ? `${clean.slice(0, max - 1)}…` : clean;
}

function shortUrl(url: string, max = 80): string {
  return truncate(url, max);
}

function count(value: unknown): number {
  return Array.isArray(value) ? value.length : 0;
}

function errorOr<T>(fn: () => T, fallback: T): T {
  try {
    return fn();
  } catch {
    return fallback;
  }
}

// --- scrape ---

function scrapeData(payload: any): Record<string, any> {
  const data = toRecord(payload?.data);
  if (Object.keys(data).length > 0) return data;
  const p = toRecord(payload);
  return p.markdown || p.html || p.links || p.metadata ? p : {};
}

function renderScrapeCall(args: unknown, theme: Theme): Text {
  const a = toRecord(args);
  const url = typeof a.url === "string" ? a.url : "...";
  const formats = Array.isArray(a.formats) ? a.formats.filter((f) => typeof f === "string") : [];
  const suffix = formats.length > 0 ? theme.fg("muted", ` [${formats.join(", ")}]`) : "";
  return new Text(`${title(theme, "scrape")} ${theme.fg("accent", shortUrl(url))}${suffix}`, 0, 0);
}

function renderScrapeResult(result: ResultLike, options: RenderOptions, theme: Theme, context?: RenderContext): Text {
  if (options.isPartial) return new Text(theme.fg("warning", "Scraping…"), 0, 0);
  if (isError(result, context)) return errorText(result, theme, "Scrape failed.");
  const payload = errorOr(() => payloadFrom(result), undefined);
  const data = scrapeData(payload);
  const meta = toRecord(data.metadata);
  const argsUrl = typeof toRecord(context?.args).url === "string" ? toRecord(context?.args).url : "";
  const url = typeof meta.sourceURL === "string" && meta.sourceURL
    ? meta.sourceURL
    : typeof data.url === "string" && data.url
      ? data.url
      : argsUrl;
  const heading = typeof meta.title === "string" && meta.title.trim()
    ? truncate(meta.title, 100)
    : shortUrl(url || "scraped page");
  const lines: string[] = [`${theme.fg("success", "✓")} ${theme.fg("accent", heading)}`];
  const stats: string[] = [];
  if (typeof data.markdown === "string") stats.push(`${data.markdown.length.toLocaleString()} chars markdown`);
  if (typeof data.html === "string") stats.push(`${data.html.length.toLocaleString()} chars html`);
  if (Array.isArray(data.links)) stats.push(`${data.links.length} links`);
  if (typeof meta.description === "string" && meta.description.trim() && !options.expanded) {
    lines.push(theme.fg("muted", truncate(meta.description, 160)));
  }
  lines.push(theme.fg("muted", stats.length > 0 ? `↳ ${stats.join(" • ")}` : "↳ scraped"));
  if (options.expanded && typeof data.markdown === "string" && data.markdown.trim()) {
    const preview = data.markdown.split("\n").map((l) => l.trimEnd()).filter((l) => l.trim()).slice(0, 20);
    for (const line of preview) lines.push(theme.fg("dim", truncate(line, 160)));
  }
  return new Text(lines.join("\n"), 0, 0);
}

// --- crawl ---

function renderCrawlCall(args: unknown, theme: Theme): Text {
  const a = toRecord(args);
  const url = typeof a.url === "string" ? a.url : "...";
  const limit = typeof a.limit === "number" ? theme.fg("muted", ` (limit ${a.limit})`) : "";
  return new Text(`${title(theme, "crawl")} ${theme.fg("accent", shortUrl(url))}${limit}`, 0, 0);
}

function renderCrawlResult(result: ResultLike, options: RenderOptions, theme: Theme, context?: RenderContext): Text {
  if (options.isPartial) return new Text(theme.fg("warning", "Starting crawl…"), 0, 0);
  if (isError(result, context)) return errorText(result, theme, "Crawl failed.");
  const payload = toRecord(errorOr(() => payloadFrom(result), undefined));
  const id = typeof payload.id === "string" ? payload.id : "";
  const argsUrl = typeof toRecord(context?.args).url === "string" ? toRecord(context?.args).url : "";
  const url = typeof payload.url === "string" && payload.url ? payload.url : argsUrl;
  const lines = [`${theme.fg("success", "✓")} ${theme.fg("accent", "crawl started")}`];
  const detail = [id ? `id ${truncate(id, 32)}` : "", url ? shortUrl(url, 60) : ""].filter(Boolean).join(" • ");
  lines.push(theme.fg("muted", `↳ ${detail || "job created"} — check status with firecrawl_crawl_status`));
  return new Text(lines.join("\n"), 0, 0);
}

// --- crawl status ---

function renderCrawlStatusCall(args: unknown, theme: Theme): Text {
  const id = typeof toRecord(args).id === "string" ? toRecord(args).id : "...";
  return new Text(`${title(theme, "crawl status")} ${theme.fg("accent", truncate(id, 40))}`, 0, 0);
}

function pageTitle(page: any): string {
  const meta = toRecord(page?.metadata);
  if (typeof meta.title === "string" && meta.title.trim()) return truncate(meta.title, 80);
  if (typeof page?.url === "string") return shortUrl(page.url, 80);
  return "page";
}

function renderCrawlStatusResult(result: ResultLike, options: RenderOptions, theme: Theme, context?: RenderContext): Text {
  if (options.isPartial) return new Text(theme.fg("warning", "Checking crawl…"), 0, 0);
  if (isError(result, context)) return errorText(result, theme, "Crawl status failed.");
  const payload = toRecord(errorOr(() => payloadFrom(result), undefined));
  const status = typeof payload.status === "string" ? payload.status : "unknown";
  const total = typeof payload.total === "number" ? payload.total : count(payload.data);
  const completed = typeof payload.completed === "number" ? payload.completed : count(payload.data);
  const done = status === "completed";
  const icon = done ? theme.fg("success", "✓") : theme.fg("warning", "●");
  const lines = [`${icon} ${theme.fg("accent", status)}${theme.fg("muted", ` ${completed}/${total} pages`)}`];
  const pages = Array.isArray(payload.data) ? payload.data : [];
  const shown = pages.slice(0, options.expanded ? 15 : 5);
  for (const page of shown) {
    const url = typeof page?.url === "string" ? page.url : typeof toRecord(page?.metadata).sourceURL === "string" ? toRecord(page?.metadata).sourceURL : "";
    lines.push(theme.fg("dim", `  • ${pageTitle(page)}${url ? ` — ${shortUrl(url, 60)}` : ""}`));
  }
  if (pages.length > shown.length) {
    lines.push(theme.fg("muted", `  … ${pages.length - shown.length} more`));
  }
  return new Text(lines.join("\n"), 0, 0);
}

// --- map ---

function mapLinks(payload: any): string[] {
  if (Array.isArray(payload?.links)) return payload.links.filter((u): u is string => typeof u === "string");
  if (Array.isArray(payload?.data)) {
    return payload.data.map((d: any) => (typeof d === "string" ? d : d?.url)).filter((u: unknown): u is string => typeof u === "string");
  }
  return [];
}

function renderMapCall(args: unknown, theme: Theme): Text {
  const a = toRecord(args);
  const url = typeof a.url === "string" ? a.url : "...";
  const parts: string[] = [];
  if (typeof a.search === "string" && a.search) parts.push(`filter "${truncate(a.search, 30)}"`);
  if (typeof a.limit === "number") parts.push(`limit ${a.limit}`);
  const suffix = parts.length > 0 ? theme.fg("muted", ` (${parts.join(", ")})`) : "";
  return new Text(`${title(theme, "map")} ${theme.fg("accent", shortUrl(url))}${suffix}`, 0, 0);
}

function renderMapResult(result: ResultLike, options: RenderOptions, theme: Theme, context?: RenderContext): Text {
  if (options.isPartial) return new Text(theme.fg("warning", "Mapping…"), 0, 0);
  if (isError(result, context)) return errorText(result, theme, "Map failed.");
  const payload = errorOr(() => payloadFrom(result), undefined);
  const links = mapLinks(payload);
  const lines = [theme.fg("muted", `↳ ${links.length} ${links.length === 1 ? "url" : "urls"}`)];
  for (const link of links.slice(0, options.expanded ? 50 : 10)) {
    lines.push(theme.fg("accent", `  • ${shortUrl(link, 100)}`));
  }
  if (links.length > (options.expanded ? 50 : 10)) {
    lines.push(theme.fg("muted", `  … ${links.length - (options.expanded ? 50 : 10)} more`));
  }
  return new Text(lines.join("\n"), 0, 0);
}

// --- search ---

function searchItems(payload: any): any[] {
  if (Array.isArray(payload?.data)) return payload.data;
  if (Array.isArray(payload?.results)) return payload.results;
  if (Array.isArray(payload?.web)) return payload.web;
  return [];
}

function renderSearchCall(args: unknown, theme: Theme): Text {
  const a = toRecord(args);
  const query = typeof a.query === "string" ? a.query : "";
  const limit = typeof a.limit === "number" ? theme.fg("muted", ` (${a.limit})`) : "";
  return new Text(`${title(theme, "search")} ${theme.fg("accent", truncate(`"${query}"`, 100))}${limit}`, 0, 0);
}

function renderSearchResult(result: ResultLike, options: RenderOptions, theme: Theme, context?: RenderContext): Text {
  if (options.isPartial) return new Text(theme.fg("warning", "Searching…"), 0, 0);
  if (isError(result, context)) return errorText(result, theme, "Search failed.");
  const payload = errorOr(() => payloadFrom(result), undefined);
  const items = searchItems(payload);
  if (items.length === 0) return new Text(theme.fg("muted", "No results"), 0, 0);
  const max = options.expanded ? Math.min(items.length, 10) : Math.min(items.length, 5);
  const lines = [theme.fg("muted", `↳ ${items.length} ${items.length === 1 ? "result" : "results"}`)];
  items.slice(0, max).forEach((item, index) => {
    const r = toRecord(item);
    const itemTitle = typeof r.title === "string" && r.title.trim() ? truncate(r.title, 90) : "Untitled";
    const url = typeof r.url === "string" ? r.url : "";
    lines.push(`${theme.fg("accent", `${index + 1}. ${itemTitle}`)}`);
    if (url) lines.push(theme.fg("dim", `   ${shortUrl(url, 100)}`));
    if (options.expanded && typeof r.description === "string" && r.description.trim()) {
      lines.push(theme.fg("muted", `   ${truncate(r.description, 180)}`));
    }
  });
  if (items.length > max) lines.push(theme.fg("muted", `  … ${items.length - max} more`));
  return new Text(lines.join("\n"), 0, 0);
}

// --- wiring (in-place decoration, no vendor patching) ---

const RENDERERS: Record<string, { call: (args: unknown, theme: Theme) => Text; result: (result: ResultLike, options: RenderOptions, theme: Theme, context?: RenderContext) => Text }> = {
  firecrawl_scrape: { call: renderScrapeCall, result: renderScrapeResult },
  firecrawl_crawl: { call: renderCrawlCall, result: renderCrawlResult },
  firecrawl_crawl_status: { call: renderCrawlStatusCall, result: renderCrawlStatusResult },
  firecrawl_map: { call: renderMapCall, result: renderMapResult },
  firecrawl_search: { call: renderSearchCall, result: renderSearchResult },
};

function enhance(tool: unknown): boolean {
  const t = tool as ToolLike | null;
  if (!t || typeof t !== "object" || typeof t.name !== "string" || !FIRECRAWL_TOOLS.has(t.name)) return false;
  const renderer = RENDERERS[t.name];
  if (!renderer) return false;
  try {
    t.renderCall = renderer.call;
    t.renderResult = renderer.result;
    return true;
  } catch {
    return false;
  }
}

function enhanceAll(pi: ExtensionAPI): void {
  try {
    for (const tool of pi.getAllTools()) enhance(tool);
  } catch {
    // getAllTools is unavailable during extension load; session_start covers it.
  }
}

function restoreInterception(pi: ExtensionAPI): void {
  const withInterception = pi as ExtensionAPI & { [WRAPPED]?: { original: ExtensionAPI["registerTool"]; wrapped: ExtensionAPI["registerTool"] } };
  const state = withInterception[WRAPPED];
  if (state && pi.registerTool === state.wrapped) {
    pi.registerTool = state.original;
  }
  delete withInterception[WRAPPED];
}

export default function firecrawlDisplay(pi: ExtensionAPI) {
  enhanceAll(pi);

  const withInterception = pi as ExtensionAPI & { [WRAPPED]?: { original: ExtensionAPI["registerTool"]; wrapped: ExtensionAPI["registerTool"] } };
  if (typeof withInterception[WRAPPED] === "undefined") {
    const originalRegisterTool = pi.registerTool;
    const wrapped = function (this: ExtensionAPI, tool: unknown) {
      try {
        enhance(tool);
      } catch {
        // Never block tool registration on a display failure.
      }
      return originalRegisterTool.call(this, tool as never);
    } as ExtensionAPI["registerTool"];
    withInterception[WRAPPED] = { original: originalRegisterTool, wrapped };
    pi.registerTool = wrapped;
  }

  pi.on("session_start", () => enhanceAll(pi));
  pi.on("before_agent_start", () => enhanceAll(pi));
  pi.on("session_shutdown", (event) => {
    if ((event as { reason?: string })?.reason === "reload") restoreInterception(pi);
  });
}
