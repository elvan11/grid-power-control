import { describe, expect, it } from "vitest";
import { createProviderApplyControlHandler } from "./handler.ts";
import { HttpError } from "../_shared/http.ts";

async function jsonOf(response: Response): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

function createBaseDeps() {
  const state = {
    applyCalls: 0,
    upsertCalls: 0,
    logs: [] as Record<string, unknown>[],
  };

  const deps = {
    handleOptions: (_req: Request) => null,
    jsonResponse: (
      payload: unknown,
      status = 200,
      _headers: Record<string, string> = {},
    ) => new Response(JSON.stringify(payload), { status }),
    errorResponse: (error: unknown) => {
      const status = error instanceof HttpError ? error.status : 500;
      const message = error instanceof Error ? error.message : "Unexpected error";
      return new Response(JSON.stringify({ error: message }), { status });
    },
    readJson: async <T>(_req: Request): Promise<T> =>
      ({ plantId: "plant-1", peakShavingW: 5000, gridChargingAllowed: true } as T),
    requireUser: async (_req: Request) => ({ userClient: {}, userId: "user-1" }),
    requirePlantRole: async (
      _userClient: unknown,
      _plantId: string,
      _roles: string[],
    ) => {},
    validatePeakShavingW: (value: number) => value,
    getRuntimeSnapshot: async (_plantId: string) => null,
    loadStoredSolisCredentials: async (_plantId: string) => ({
      credentials: {
        apiId: "api-id",
        apiSecret: "api-secret",
        inverterSn: "inverter-1",
      },
    }),
    applySolisControls: async () => {
      state.applyCalls += 1;
      return {
        ok: true,
        steps: [
          {
            ok: true,
            endpoint: "/v2/api/control",
            httpStatus: 200,
            code: "0",
            message: "ok",
            durationMs: 10,
            attempts: 1,
            payload: { cid: 5035 },
          },
        ],
      };
    },
    insertApplyLog: async (entry: Record<string, unknown>) => {
      state.logs.push(entry);
    },
    upsertRuntime: async (_entry: Record<string, unknown>) => {
      state.upsertCalls += 1;
    },
    now: () => new Date("2026-02-19T10:00:00.000Z"),
  };

  return { deps, state };
}

describe("provider_apply_control handler", () => {
  it("skips when already applied", async () => {
    const { deps, state } = createBaseDeps();
    deps.getRuntimeSnapshot = async () => ({
      last_applied_peak_shaving_w: 5000,
      last_applied_grid_charging_allowed: true,
    });

    const handler = createProviderApplyControlHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.skipped).toBe(true);
    expect(state.applyCalls).toBe(0);
    expect(state.upsertCalls).toBe(0);
    expect(state.logs.length).toBe(1);
  });

  it("applies and updates runtime", async () => {
    const { deps, state } = createBaseDeps();
    const handler = createProviderApplyControlHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(state.applyCalls).toBe(1);
    expect(state.upsertCalls).toBe(1);
    expect(state.logs.length).toBe(1);
  });

  it("rejects non-boolean gridChargingAllowed", async () => {
    const { deps, state } = createBaseDeps();
    deps.readJson = async <T>(_req: Request): Promise<T> =>
      ({ plantId: "plant-1", peakShavingW: 5000, gridChargingAllowed: "yes" } as T);

    const handler = createProviderApplyControlHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(400);
    expect(body.error).toBe("gridChargingAllowed must be boolean");
    expect(state.applyCalls).toBe(0);
  });
});
