import { describe, expect, it } from "vitest";
import { HttpError } from "../_shared/http.ts";
import { createPlantSharingListHandler } from "./handler.ts";

describe("plant_sharing_list handler", () => {
  it("returns 405 for non-POST", async () => {
    const handler = createPlantSharingListHandler({
      handleOptions: () => null,
      jsonResponse: (payload, status = 200) =>
        new Response(JSON.stringify(payload), { status }),
      errorResponse: (error) => {
        const status = error instanceof HttpError ? error.status : 500;
        return new Response(JSON.stringify({ error: "err" }), { status });
      },
      readJson: async () => ({ plantId: "plant-1" }),
      requireUser: async () => ({ userClient: {} }),
      requirePlantRole: async () => {},
      createAdminClient: () => ({
        from: () => ({}),
        auth: { admin: { getUserById: async () => ({ data: {} }) } },
      }),
    });

    const response = await handler(new Request("https://example.test", { method: "GET" }));
    expect(response.status).toBe(405);
  });

  it("validates plantId", async () => {
    const handler = createPlantSharingListHandler({
      handleOptions: () => null,
      jsonResponse: (payload, status = 200) =>
        new Response(JSON.stringify(payload), { status }),
      errorResponse: (error) => {
        const status = error instanceof HttpError ? error.status : 500;
        const message = error instanceof Error ? error.message : "Unexpected";
        return new Response(JSON.stringify({ error: message }), { status });
      },
      readJson: async () => ({ plantId: "" }),
      requireUser: async () => ({ userClient: {} }),
      requirePlantRole: async () => {},
      createAdminClient: () => ({
        from: () => ({}),
        auth: { admin: { getUserById: async () => ({ data: {} }) } },
      }),
    });

    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await response.json() as { error: string };
    expect(response.status).toBe(400);
    expect(body.error).toBe("plantId is required");
  });
});
