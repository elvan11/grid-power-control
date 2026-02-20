import { describe, expect, it } from "vitest";
import { HttpError } from "../_shared/http.ts";
import { createPlantSharingInviteHandler } from "./handler.ts";

describe("plant_sharing_invite handler", () => {
  it("returns 405 for non-POST", async () => {
    const handler = createPlantSharingInviteHandler({
      handleOptions: () => null,
      jsonResponse: (payload, status = 200) =>
        new Response(JSON.stringify(payload), { status }),
      errorResponse: (error) => {
        const status = error instanceof HttpError ? error.status : 500;
        return new Response(JSON.stringify({ error: "err" }), { status });
      },
      readJson: async () => ({ plantId: "plant-1", invitedEmail: "a@b.com" }),
      requireUser: async () => ({ userClient: {}, userId: "u1", userEmail: "u@x.com" }),
      requirePlantRole: async () => {},
      createAdminClient: () => ({ from: () => ({}) }),
      now: () => new Date("2026-02-19T00:00:00.000Z"),
    });

    const response = await handler(new Request("https://example.test", { method: "GET" }));
    expect(response.status).toBe(405);
  });

  it("validates invitedEmail before DB writes", async () => {
    const handler = createPlantSharingInviteHandler({
      handleOptions: () => null,
      jsonResponse: (payload, status = 200) =>
        new Response(JSON.stringify(payload), { status }),
      errorResponse: (error) => {
        const status = error instanceof HttpError ? error.status : 500;
        const message = error instanceof Error ? error.message : "Unexpected";
        return new Response(JSON.stringify({ error: message }), { status });
      },
      readJson: async () => ({ plantId: "plant-1", invitedEmail: "bad-email" }),
      requireUser: async () => ({ userClient: {}, userId: "u1", userEmail: "u@x.com" }),
      requirePlantRole: async () => {},
      createAdminClient: () => ({ from: () => ({}) }),
      now: () => new Date("2026-02-19T00:00:00.000Z"),
    });

    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await response.json() as { error: string };
    expect(response.status).toBe(400);
    expect(body.error).toBe("A valid email is required");
  });
});
