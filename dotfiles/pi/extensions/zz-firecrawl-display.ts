import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

type FirecrawlSearchResult = {
  url?: unknown;
  links?: unknown;
};

type SearchDetails = {
  data?: unknown;
  web?: unknown;
  results?: unknown;
};

function urlsFrom(value: unknown): string[] {
  if (!Array.isArray(value)) return [];

  const urls = new Set<string>();
  for (const item of value) {
    if (typeof item === "string") urls.add(item);
    else if (item && typeof item === "object") {
      const result = item as FirecrawlSearchResult;
      if (typeof result.url === "string") urls.add(result.url);
      if (Array.isArray(result.links)) {
        for (const link of result.links) if (typeof link === "string") urls.add(link);
      }
    }
  }
  return [...urls];
}

function resultUrls(details: unknown): string[] {
  if (!details || typeof details !== "object") return [];
  const result = details as SearchDetails;
  for (const candidate of [result.data, result.web, result.results]) {
    const urls = urlsFrom(candidate);
    if (urls.length > 0) return urls;
  }
  return [];
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
        const urls = resultUrls(result.details);
        if (urls.length === 0) return new Text(theme.fg("muted", "No addresses returned"), 0, 0);
        return new Text(urls.map((url) => theme.fg("accent", url)).join("\n"), 0, 0);
      },
    });
  });
}
