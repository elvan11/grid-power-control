import { describe, expect, it } from "vitest";
import { createProviderConnectionUpsertHandler } from "./handler.ts";
import { HttpError } from "../_shared/http.ts";

async function jsonOf(response: Response): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

function createBaseDeps() {
  const state = {
    called: false,
    receivedPlantId: "",
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
      ({
        plantId: "plant-1",
        displayName: "Solis Plant",
        inverterSn: "SN-001",
        apiId: "api-id",
        apiSecret: "api-secret",
      } as T),
    requireUser: async (_req: Request) => ({ userClient: {} }),
    requirePlantRole: async (
      _userClient: unknown,
      _plantId: string,
      _roles: string[],
    ) => {},
    upsertStoredSolisCredentials: async (input: { plantId: string }) => {
      state.called = true;
      state.receivedPlantId = input.plantId;
      return {
        connectionId: "conn-1",
        updatedAt: "2026-02-19T10:00:00.000Z",
      };
    },
  };

  return { deps, state };
}

describe("provider_connection_upsert handler", () => {
  it("upserts and returns metadata", async () => {
    const { deps, state } = createBaseDeps();
    const handler = createProviderConnectionUpsertHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.connectionId).toBe("conn-1");
    expect(state.called).toBe(true);
    expect(state.receivedPlantId).toBe("plant-1");
  });

  it("requires plantId", async () => {
    const { deps } = createBaseDeps();
    deps.readJson = async <T>(_req: Request): Promise<T> =>
      ({
        displayName: "Solis Plant",
        inverterSn: "SN-001",
        apiId: "api-id",
        apiSecret: "api-secret",
      } as T);

    const handler = createProviderConnectionUpsertHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(400);
    expect(body.error).toBe("plantId is required");
  });
});
