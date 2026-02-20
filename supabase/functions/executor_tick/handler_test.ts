import { describe, expect, it } from "vitest";
import { HttpError } from "../_shared/http.ts";
import { createExecutorTickHandler } from "./handler.ts";

describe("executor_tick handler", () => {
  it("returns 405 for non-POST", async () => {
    const handler = createExecutorTickHandler({
      handleOptions: () => null,
      jsonResponse: (payload, status = 200) =>
        new Response(JSON.stringify(payload), { status }),
      errorResponse: (error) => {
        const status = error instanceof HttpError ? error.status : 500;
        return new Response(JSON.stringify({ error: "err" }), { status });
      },
      readJson: async () => ({}),
      createAdminClient: () => ({
        rpc: async () => ({ data: null, error: null }),
        from: () => ({}),
      }),
      loadStoredSolisCredentials: async () => ({
        credentials: { apiId: "id", apiSecret: "secret", inverterSn: "sn" },
      }),
      applySolisControls: async () => ({ ok: true, steps: [] }),
      getEnv: () => "secret",
      now: () => new Date("2026-02-19T00:00:00.000Z"),
      sleep: async () => {},
    });

    const response = await handler(new Request("https://example.test", { method: "GET" }));
    expect(response.status).toBe(405);
  });

  it("rejects missing executor secret", async () => {
    const handler = createExecutorTickHandler({
      handleOptions: () => null,
      jsonResponse: (payload, status = 200) =>
        new Response(JSON.stringify(payload), { status }),
      errorResponse: (error) => {
        const status = error instanceof HttpError ? error.status : 500;
        const message = error instanceof Error ? error.message : "Unexpected";
        return new Response(JSON.stringify({ error: message }), { status });
      },
      readJson: async () => ({}),
      createAdminClient: () => ({
        rpc: async () => ({ data: null, error: null }),
        from: () => ({}),
      }),
      loadStoredSolisCredentials: async () => ({
        credentials: { apiId: "id", apiSecret: "secret", inverterSn: "sn" },
      }),
      applySolisControls: async () => ({ ok: true, steps: [] }),
      getEnv: () => undefined,
      now: () => new Date("2026-02-19T00:00:00.000Z"),
      sleep: async () => {},
    });

    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await response.json() as { error: string };
    expect(response.status).toBe(401);
    expect(body.error).toBe("Unauthorized executor secret");
  });
});
