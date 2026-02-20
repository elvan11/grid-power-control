import { describe, expect, it } from "vitest";
import { createProviderConnectionTestHandler } from "./handler.ts";
import { HttpError } from "../_shared/http.ts";

async function jsonOf(response: Response): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

function createBaseDeps() {
  const state = {
    usedStoredCredentials: false,
    usedInlineCredentials: false,
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
      ({ plantId: "plant-1" } as T),
    requireUser: async (_req: Request) => ({ userClient: {} }),
    requirePlantRole: async (
      _userClient: unknown,
      _plantId: string,
      _roles: string[],
    ) => {},
    loadStoredSolisCredentials: async (_plantId: string) => {
      state.usedStoredCredentials = true;
      return {
        credentials: {
          apiId: "stored-id",
          apiSecret: "stored-secret",
          inverterSn: "stored-sn",
        },
      };
    },
    testSolisConnection: async (credentials: {
      apiId: string;
      apiSecret: string;
      inverterSn: string;
      apiBaseUrl?: string;
    }) => {
      if (credentials.apiId === "inline-id") {
        state.usedInlineCredentials = true;
      }
      return {
        ok: true,
        endpoint: "/v2/api/atRead",
        httpStatus: 200,
        code: "0",
        message: "ok",
        attempts: 1,
        durationMs: 5,
      };
    },
  };

  return { deps, state };
}

describe("provider_connection_test handler", () => {
  it("uses stored credentials by default", async () => {
    const { deps, state } = createBaseDeps();
    const handler = createProviderConnectionTestHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(state.usedStoredCredentials).toBe(true);
    expect(state.usedInlineCredentials).toBe(false);
  });

  it("uses inline credentials when complete", async () => {
    const { deps, state } = createBaseDeps();
    deps.readJson = async <T>(_req: Request): Promise<T> =>
      ({
        plantId: "plant-1",
        apiId: "inline-id",
        apiSecret: "inline-secret",
        inverterSn: "inline-sn",
        apiBaseUrl: "https://solis.example.test",
      } as T);

    const handler = createProviderConnectionTestHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(state.usedInlineCredentials).toBe(true);
  });

  it("rejects partial inline credentials", async () => {
    const { deps } = createBaseDeps();
    deps.readJson = async <T>(_req: Request): Promise<T> =>
      ({
        plantId: "plant-1",
        apiId: "inline-id",
        inverterSn: "inline-sn",
      } as T);

    const handler = createProviderConnectionTestHandler(deps);
    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await jsonOf(response);

    expect(response.status).toBe(400);
    expect(body.error).toBe(
      "When testing with inline credentials, apiId, apiSecret, and inverterSn are all required",
    );
  });
});
