import { describe, expect, it } from "vitest";
import { HttpError } from "../_shared/http.ts";
import { createPlantSharingAcceptInviteHandler } from "./handler.ts";

describe("plant_sharing_accept_invite handler", () => {
  it("returns 405 for non-POST", async () => {
    const handler = createPlantSharingAcceptInviteHandler({
      handleOptions: () => null,
      jsonResponse: (payload, status = 200) =>
        new Response(JSON.stringify(payload), { status }),
      errorResponse: (error) => {
        const status = error instanceof HttpError ? error.status : 500;
        return new Response(JSON.stringify({ error: "err" }), { status });
      },
      readJson: async () => ({ token: "abc" }),
      requireUser: async () => ({ userId: "u1", userEmail: "u@x.com" }),
      createAdminClient: () => ({ from: () => ({}) }),
      now: () => new Date("2026-02-19T00:00:00.000Z"),
    });

    const response = await handler(new Request("https://example.test", { method: "GET" }));
    expect(response.status).toBe(405);
  });

  it("requires authenticated user email", async () => {
    const handler = createPlantSharingAcceptInviteHandler({
      handleOptions: () => null,
      jsonResponse: (payload, status = 200) =>
        new Response(JSON.stringify(payload), { status }),
      errorResponse: (error) => {
        const status = error instanceof HttpError ? error.status : 500;
        const message = error instanceof Error ? error.message : "Unexpected";
        return new Response(JSON.stringify({ error: message }), { status });
      },
      readJson: async () => ({ token: "abc" }),
      requireUser: async () => ({ userId: "u1", userEmail: null }),
      createAdminClient: () => ({ from: () => ({}) }),
      now: () => new Date("2026-02-19T00:00:00.000Z"),
    });

    const response = await handler(new Request("https://example.test", { method: "POST" }));
    const body = await response.json() as { error: string };
    expect(response.status).toBe(400);
    expect(body.error).toBe("Authenticated user does not have an email");
  });
});
