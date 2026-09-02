import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const CLAUDE_CODE_VERSION = "2.1.251";
const BILLING_MARKER =
  `x-anthropic-billing-header: cc_version=${CLAUDE_CODE_VERSION}; cc_entrypoint=sdk-cli; cch=00000;`;

function isSlopClaude(ctx: { model?: { provider: string; id: string } }): boolean {
  return ctx.model?.provider === "slop" && ctx.model.id.startsWith("claude-");
}

export default function (pi: ExtensionAPI) {
  pi.on("before_provider_headers", (event, ctx) => {
    if (!isSlopClaude(ctx)) return;

    const existingBeta =
      event.headers["anthropic-beta"] ?? event.headers["Anthropic-Beta"] ?? "";
    const betas = new Set(
      existingBeta
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean),
    );
    betas.add("claude-code-20250219");

    const authorization =
      event.headers.Authorization ?? event.headers.authorization;
    if (authorization?.startsWith("Bearer ")) {
      event.headers["x-api-key"] = authorization.slice("Bearer ".length);
      event.headers.Authorization = null;
      event.headers.authorization = null;
    }

    const betaHeader = [...betas].join(",");
    event.headers["anthropic-beta"] = betaHeader;
    event.headers["Anthropic-Beta"] = betaHeader;
    event.headers["user-agent"] =
      `claude-cli/${CLAUDE_CODE_VERSION} (external, sdk-cli)`;
    event.headers["x-app"] = "cli";
    event.headers["anthropic-dangerous-direct-browser-access"] = "true";
  });

  pi.on("before_provider_request", (event, ctx) => {
    if (!isSlopClaude(ctx)) return;
    if (!event.payload || typeof event.payload !== "object") return;

    const payload = event.payload as Record<string, unknown>;
    const marker = {
      type: "text",
      text: BILLING_MARKER,
      cache_control: { type: "ephemeral" },
    };
    const system = payload.system;

    if (Array.isArray(system)) {
      const alreadyPresent = system.some(
        (block) =>
          block &&
          typeof block === "object" &&
          "text" in block &&
          typeof block.text === "string" &&
          block.text.startsWith("x-anthropic-billing-header:"),
      );
      if (alreadyPresent) return;
      return { ...payload, system: [marker, ...system] };
    }

    if (typeof system === "string") {
      return {
        ...payload,
        system: [marker, { type: "text", text: system }],
      };
    }

    return { ...payload, system: [marker] };
  });
}
