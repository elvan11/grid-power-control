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

  it("applies current slot immediately after override ends instead of lookahead slot", async () => {
    const runtimeUpserts: Record<string, unknown>[] = [];
    const applyCalls: Array<{ peakShavingW: number; gridChargingAllowed: boolean }> = [];
    let computeCallCount = 0;

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
            computeCallCount += 1;
            if (computeCallCount === 1) {
              return {
                data: [{
                  desired_peak_shaving_w: 2500,
                  desired_grid_charging_allowed: false,
                  next_due_at: "2026-02-20T10:45:00.000Z",
                  source: "schedule",
                }],
                error: null,
              };
            }
            return {
              data: [{
                desired_peak_shaving_w: 3500,
                desired_grid_charging_allowed: true,
                next_due_at: "2026-02-20T11:00:00.000Z",
                source: "schedule",
              }],
              error: null,
            };
          }
          return { data: null, error: null };
        },
        from: (table: string) => {
          if (table === "overrides") {
            return {
              select: () => ({
                eq: () => ({
                  lte: () => ({
                    gt: () => ({
                      order: () => ({
                        limit: () => ({
                          maybeSingle: async () => ({
                            data: { id: "override-1" },
                            error: null,
                          }),
                        }),
                      }),
                    }),
                  }),
                }),
              }),
            };
          }

          if (table === "plant_runtime") {
            return {
              select: () => ({
                eq: () => ({
                  maybeSingle: async () => ({
                    data: {
                      last_applied_peak_shaving_w: 1000,
                      last_applied_grid_charging_allowed: true,
                    },
                    error: null,
                  }),
                }),
              }),
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
      applySolisControls: async (_credentials, peakShavingW, gridChargingAllowed) => {
        applyCalls.push({ peakShavingW, gridChargingAllowed });
        return { ok: true, steps: [] };
      },
      getEnv: () => "executor-secret",
      now: () => new Date("2026-02-20T10:41:00.000Z"),
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
      summary: { applied: number };
    };
    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.summary.applied).toBe(1);
    expect(computeCallCount).toBe(1);
    expect(applyCalls).toEqual([
      { peakShavingW: 2500, gridChargingAllowed: false },
    ]);
    expect(runtimeUpserts).toHaveLength(1);
    expect(runtimeUpserts[0]?.["next_due_at"]).toBe("2026-02-20T10:45:00.000Z");
  });

  it("recomputes desired state at overdue next_due_at and skips lookahead", async () => {
    const applyCalls: Array<{ peakShavingW: number; gridChargingAllowed: boolean }> = [];
    let computeCalls: Array<{ p_at: string }> = [];

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
        rpc: async (name, args) => {
          if (name === "claim_due_plants") {
            return { data: [{ plant_id: "plant-1" }], error: null };
          }
          if (name === "compute_plant_desired_control") {
            computeCalls.push({ p_at: String(args?.["p_at"] ?? "") });
            const pAt = String(args?.["p_at"] ?? "");
            if (pAt === "2026-02-20T10:00:00.000Z") {
              return {
                data: [{
                  desired_peak_shaving_w: 1800,
                  desired_grid_charging_allowed: false,
                  next_due_at: "2026-02-20T10:15:00.000Z",
                  source: "schedule",
                }],
                error: null,
              };
            }
            return {
              data: [{
                desired_peak_shaving_w: 2600,
                desired_grid_charging_allowed: true,
                next_due_at: "2026-02-20T10:45:00.000Z",
                source: "schedule",
              }],
              error: null,
            };
          }
          return { data: null, error: null };
        },
        from: (table: string) => {
          if (table === "overrides") {
            return {
              select: () => ({
                eq: () => ({
                  lte: () => ({
                    gt: () => ({
                      order: () => ({
                        limit: () => ({
                          maybeSingle: async () => ({
                            data: null,
                            error: null,
                          }),
                        }),
                      }),
                    }),
                  }),
                }),
              }),
            };
          }

          if (table === "plant_runtime") {
            return {
              select: () => ({
                eq: () => ({
                  maybeSingle: async () => ({
                    data: {
                      next_due_at: "2026-02-20T10:00:00.000Z",
                      last_applied_peak_shaving_w: 999,
                      last_applied_grid_charging_allowed: false,
                    },
                    error: null,
                  }),
                }),
              }),
              upsert: async () => ({ error: null }),
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
      applySolisControls: async (_credentials, peakShavingW, gridChargingAllowed) => {
        applyCalls.push({ peakShavingW, gridChargingAllowed });
        return { ok: true, steps: [] };
      },
      getEnv: () => "executor-secret",
      now: () => new Date("2026-02-20T10:14:00.000Z"),
      sleep: async () => {},
    });

    const response = await handler(
      new Request("https://example.test", {
        method: "POST",
        headers: { Authorization: "Bearer executor-secret" },
      }),
    );

    expect(response.status).toBe(200);
    expect(computeCalls).toEqual([
      { p_at: "2026-02-20T10:14:00.000Z" },
      { p_at: "2026-02-20T10:00:00.000Z" },
    ]);
    expect(applyCalls).toEqual([{ peakShavingW: 1800, gridChargingAllowed: false }]);
  });

  it("falls back to installation defaults when a slot ends with no following slot", async () => {
    const applyCalls: Array<{ peakShavingW: number; gridChargingAllowed: boolean }> = [];
    const computeCalls: Array<{ p_at: string }> = [];

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
        rpc: async (name, args) => {
          if (name === "claim_due_plants") {
            return { data: [{ plant_id: "plant-1" }], error: null };
          }
          if (name === "compute_plant_desired_control") {
            const pAt = String(args?.["p_at"] ?? "");
            computeCalls.push({ p_at: pAt });
            if (pAt === "2026-02-20T15:00:00.000Z") {
              return {
                data: [{
                  desired_peak_shaving_w: 2000,
                  desired_grid_charging_allowed: false,
                  next_due_at: "2026-02-21T06:00:00.000Z",
                  source: "default",
                }],
                error: null,
              };
            }
            return {
              data: [{
                desired_peak_shaving_w: 3200,
                desired_grid_charging_allowed: true,
                next_due_at: "2026-02-20T15:00:00.000Z",
                source: "schedule",
              }],
              error: null,
            };
          }
          return { data: null, error: null };
        },
        from: (table: string) => {
          if (table === "overrides") {
            return {
              select: () => ({
                eq: () => ({
                  lte: () => ({
                    gt: () => ({
                      order: () => ({
                        limit: () => ({
                          maybeSingle: async () => ({
                            data: null,
                            error: null,
                          }),
                        }),
                      }),
                    }),
                  }),
                }),
              }),
            };
          }

          if (table === "plant_runtime") {
            return {
              select: () => ({
                eq: () => ({
                  maybeSingle: async () => ({
                    data: {
                      next_due_at: "2026-02-20T15:00:00.000Z",
                      last_applied_peak_shaving_w: 3200,
                      last_applied_grid_charging_allowed: true,
                    },
                    error: null,
                  }),
                }),
              }),
              upsert: async () => ({ error: null }),
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
      applySolisControls: async (_credentials, peakShavingW, gridChargingAllowed) => {
        applyCalls.push({ peakShavingW, gridChargingAllowed });
        return { ok: true, steps: [] };
      },
      getEnv: () => "executor-secret",
      now: () => new Date("2026-02-20T15:14:00.000Z"),
      sleep: async () => {},
    });

    const response = await handler(
      new Request("https://example.test", {
        method: "POST",
        headers: { Authorization: "Bearer executor-secret" },
      }),
    );

    expect(response.status).toBe(200);
    expect(computeCalls).toEqual([
      { p_at: "2026-02-20T15:14:00.000Z" },
      { p_at: "2026-02-20T15:00:00.000Z" },
    ]);
    expect(applyCalls).toEqual([{ peakShavingW: 2000, gridChargingAllowed: false }]);
  });
});
