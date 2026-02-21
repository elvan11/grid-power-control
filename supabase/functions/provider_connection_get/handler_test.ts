import { describe, expect, it } from "vitest";
import { createProviderConnectionGetHandler } from "./handler.ts";
import { HttpError } from "../_shared/http.ts";

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
      displayName: "Main inverter",
      credentials: {
        inverterSn: "INV-001",
        apiId: "api-id",
        apiSecret: "api-secret",
        apiBaseUrl: "https://api.example.com",
      },
    }),
  };

  return { deps };
}

describe("provider_connection_get handler", () => {
  it("returns stored Solis credentials for the plant", async () => {
    const { deps } = createBaseDeps();
    const handler = createProviderConnectionGetHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.displayName).toBe("Main inverter");
    expect(body.config).toEqual({
      inverterSn: "INV-001",
      apiId: "api-id",
      apiSecret: "api-secret",
      apiBaseUrl: "https://api.example.com",
    });
  });

  it("requires plantId", async () => {
    const { deps } = createBaseDeps();
    deps.readJson = async <T>(_req: Request): Promise<T> => ({} as T);

    const handler = createProviderConnectionGetHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(400);
    expect(body.error).toBe("plantId is required");
  });
});
