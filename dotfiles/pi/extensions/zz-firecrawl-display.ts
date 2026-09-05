import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

type FirecrawlSearchResult = {
  url?: unknown;
  links?: unknown;
};

function urlsFrom(value: unknown): string[] {
  const urls = new Set<string>();
  const visit = (item: unknown) => {
    if (typeof item === "string") {
      if (/^https?:\/\//u.test(item)) urls.add(item);
      return;
    }
    if (!item || typeof item !== "object") return;
    if (Array.isArray(item)) {
      item.forEach(visit);
      return;
    }

    const result = item as FirecrawlSearchResult & Record<string, unknown>;
    if (typeof result.url === "string") urls.add(result.url);
    // Firecrawl has returned both data: [{ url }] and data: { web: [{ url }] }
    // across API versions; traverse result groups without displaying their metadata.
    Object.values(result).forEach(visit);
  };
  visit(value);
  return [...urls];
}

function resultUrls(result: { details?: unknown; content?: Array<{ type?: string; text?: string }> }): string[] {
  const direct = urlsFrom(result.details);
  if (direct.length > 0) return direct;

  const text = result.content?.find((part) => part.type === "text")?.text;
  if (!text) return [];
  try {
    return urlsFrom(JSON.parse(text));
  } catch {
    return urlsFrom(text);
  }
}

export default function firecrawlDisplay(pi: ExtensionAPI) {
  // Extension action methods are unavailable while extensions load. pi-firecrawl
  // registers first; wait for the session lifecycle before retrieving and wrapping it.
  pi.on("session_start", () => {
    const searchTool = pi.getAllTools().find((tool) => tool.name === "firecrawl_search");
    if (!searchTool) return;

    pi.registerTool({
      ...searchTool,
      renderCall(args, theme) {
        const query = typeof (args as { query?: unknown }).query === "string"
          ? (args as { query: string }).query
          : "";
        return new Text(
          theme.fg("toolTitle", "firecrawl_search ") + theme.fg("accent", query),
          0,
          0,
        );
      },
      renderResult(result, _options, theme) {
        const urls = resultUrls(result);
        if (urls.length === 0) return new Text(theme.fg("muted", "No addresses returned"), 0, 0);
        return new Text(urls.map((url) => theme.fg("accent", url)).join("\n"), 0, 0);
      },
    });
  });
}
