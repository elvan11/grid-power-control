import {
  createAdminClient,
  requirePlantRole,
  requireUser,
} from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { requireNonEmptyString } from "../_shared/sharing.ts";

interface RevokeInvitePayload {
  plantId: string;
  inviteId: string;
}

Deno.serve(async (req: Request) => {
  const preflight = handleOptions(req);
  if (preflight) {
    return preflight;
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const { userClient } = await requireUser(req);
    const body = await readJson<RevokeInvitePayload>(req);
    const plantId = requireNonEmptyString(body.plantId, "plantId");
    const inviteId = requireNonEmptyString(body.inviteId, "inviteId");

    await requirePlantRole(userClient, plantId, ["owner", "admin"]);

    const adminClient = createAdminClient();
    const { data: revokedInvite, error: revokeError } = await adminClient
      .from("plant_invites")
      .update({
        status: "revoked",
      })
      .eq("id", inviteId)
      .eq("plant_id", plantId)
      .eq("status", "pending")
      .select("id")
      .maybeSingle();
    if (revokeError) {
      throw revokeError;
    }
    if (!revokedInvite) {
      throw new HttpError(404, "Pending invite not found");
    }

    return jsonResponse({
      ok: true,
      plantId,
      inviteId,
      status: "revoked",
    });
  } catch (error) {
    return errorResponse(error);
  }
});
