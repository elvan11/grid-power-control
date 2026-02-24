import { describe, expect, it } from "vitest";
import { HttpError } from "../_shared/http.ts";
import { createProviderBatterySocHandler } from "./handler.ts";

async function jsonOf(response: Response): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

function createBaseDeps() {
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
    readJson: async <T>(_req: Request): Promise<T> => ({ plantId: "plant-1" } as T),
    requireUser: async (_req: Request) => ({ userClient: {} }),
    requirePlantRole: async (
      _userClient: unknown,
      _plantId: string,
      _roles: string[],
    ) => {},
    loadStoredSolisCredentials: async (_plantId: string) => ({
      credentials: {
        inverterSn: "INV-001",
        apiId: "api-id",
        apiSecret: "api-secret",
      },
    }),
    readSolisBatterySoc: async (_credentials: unknown) => ({
      batteryPercentage: 67,
      stationId: "1001",
      steps: [
        {
          ok: true,
          endpoint: "/v1/api/userStationList",
          httpStatus: 200,
          code: "0",
          message: "ok",
          attempts: 1,
          durationMs: 12,
          payload: {},
        },
        {
          ok: true,
          endpoint: "/v1/api/stationDetail",
          httpStatus: 200,
          code: "0",
          message: "ok",
          attempts: 1,
          durationMs: 11,
          payload: { id: "1001" },
        },
      ],
    }),
    now: () => new Date("2026-02-24T10:00:00.000Z"),
  };

  return { deps };
}

describe("provider_battery_soc handler", () => {
  it("returns station battery percentage for plant", async () => {
    const { deps } = createBaseDeps();
    const handler = createProviderBatterySocHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.batteryPercentage).toBe(67);
    expect(body.stationId).toBe("1001");
    expect(body.fetchedAt).toBe("2026-02-24T10:00:00.000Z");
    expect((body.attempts as unknown[]).length).toBe(2);
  });

  it("requires plantId", async () => {
    const { deps } = createBaseDeps();
    deps.readJson = async <T>(_req: Request): Promise<T> => ({} as T);

    const handler = createProviderBatterySocHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(400);
    expect(body.error).toBe("plantId is required");
  });

  it("returns downstream provider error response", async () => {
    const { deps } = createBaseDeps();
    deps.readSolisBatterySoc = async () => {
      throw new HttpError(502, "Solis station detail failed");
    };

    const handler = createProviderBatterySocHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(502);
    expect(body.error).toBe("Solis station detail failed");
  });
});
