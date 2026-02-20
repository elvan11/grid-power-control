import { describe, expect, it } from "vitest";
import { HttpError } from "../_shared/http.ts";
import { createPlantSharingRemoveMemberHandler } from "./handler.ts";

describe("plant_sharing_remove_member handler", () => {
  it("returns 405 for non-POST", async () => {
    const handler = createPlantSharingRemoveMemberHandler({
      handleOptions: () => null,
      jsonResponse: (payload, status = 200) =>
        new Response(JSON.stringify(payload), { status }),
      errorResponse: (error) => {
        const status = error instanceof HttpError ? error.status : 500;
        return new Response(JSON.stringify({ error: "err" }), { status });
      },
      readJson: async () => ({ plantId: "p1", memberUserId: "u2" }),
      requireUser: async () => ({ userClient: {}, userId: "u1" }),
      requirePlantRole: async () => {},
      createAdminClient: () => ({ from: () => ({}) }),
    });

    const response = await handler(new Request("https://example.test", { method: "GET" }));
    expect(response.status).toBe(405);
  });

  it("validates memberUserId", async () => {
    const handler = createPlantSharingRemoveMemberHandler({
      handleOptions: () => null,
      jsonResponse: (payload, status = 200) =>
        new Response(JSON.stringify(payload), { status }),
      errorResponse: (error) => {
        const status = error instanceof HttpError ? error.status : 500;
        const message = error instanceof Error ? error.message : "Unexpected";
        return new Response(JSON.stringify({ error: message }), { status });
      },
      readJson: async () => ({ plantId: "p1", memberUserId: "" }),
      requireUser: async () => ({ userClient: {}, userId: "u1" }),
      requirePlantRole: async () => {},
      createAdminClient: () => ({ from: () => ({}) }),
    });

    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await response.json() as { error: string };
    expect(response.status).toBe(400);
    expect(body.error).toBe("memberUserId is required");
  });
});
