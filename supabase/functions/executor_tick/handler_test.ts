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

  it("skips provider apply when schedule control is disabled", async () => {
    const runtimeUpserts: Record<string, unknown>[] = [];
    let applyCalled = false;

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
        rpc: async (name) => {
          if (name === "claim_due_plants") {
            return { data: [{ plant_id: "plant-1" }], error: null };
          }
          if (name === "compute_plant_desired_control") {
            return {
              data: [{
                desired_peak_shaving_w: 2000,
                desired_grid_charging_allowed: false,
                next_due_at: "2026-02-20T00:00:00.000Z",
                source: "disabled",
              }],
              error: null,
            };
          }
          return { data: null, error: null };
        },
        from: (table: string) => {
          if (table === "plant_runtime") {
            return {
              upsert: async (data: Record<string, unknown>) => {
                runtimeUpserts.push(data);
                return { error: null };
              },
            };
          }
          if (table === "control_apply_log") {
            return {
              insert: async () => ({ error: null }),
            };
          }
          return {};
        },
      }),
      loadStoredSolisCredentials: async () => ({
        credentials: { apiId: "id", apiSecret: "secret", inverterSn: "sn" },
      }),
      applySolisControls: async () => {
        applyCalled = true;
        return { ok: true, steps: [] };
      },
      getEnv: () => "executor-secret",
      now: () => new Date("2026-02-19T00:00:00.000Z"),
      sleep: async () => {},
    });

    const response = await handler(
      new Request("https://example.test", {
        method: "POST",
        headers: { Authorization: "Bearer executor-secret" },
      }),
    );

    const body = await response.json() as {
      ok: boolean;
      summary: { skipped: number };
      results: Array<{ status: string; detail: string }>;
    };
    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.summary.skipped).toBe(1);
    expect(body.results[0]?.status).toBe("skipped");
    expect(body.results[0]?.detail).toBe("schedule_control_disabled");
    expect(applyCalled).toBe(false);
    expect(runtimeUpserts).toHaveLength(1);
    expect(runtimeUpserts[0]?.["next_due_at"]).toBe("2026-02-20T00:00:00.000Z");
  });
});
