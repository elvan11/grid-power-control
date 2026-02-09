import {
  createAdminClient,
  requirePlantRole,
  requireUser,
} from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { requireNonEmptyString } from "../_shared/sharing.ts";

interface ListPayload {
  plantId: string;
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
    const body = await readJson<ListPayload>(req);
    const plantId = requireNonEmptyString(body.plantId, "plantId");

    await requirePlantRole(userClient, plantId, ["owner", "admin"]);

    const adminClient = createAdminClient();

    const { data: members, error: membersError } = await adminClient
      .from("plant_members")
      .select("auth_user_id,role,created_at")
      .eq("plant_id", plantId)
      .order("created_at", { ascending: true });
    if (membersError) {
      throw membersError;
    }

    const enrichedMembers = [];
    for (const row of members ?? []) {
      const { data: userData } = await adminClient.auth.admin.getUserById(
        row.auth_user_id,
      );
      enrichedMembers.push({
        authUserId: row.auth_user_id,
        role: row.role,
        email: userData.user?.email?.toLowerCase() ?? null,
        createdAt: row.created_at,
      });
    }

    const { data: invites, error: invitesError } = await adminClient
      .from("plant_invites")
      .select("id,invited_email,role,status,expires_at,created_at")
      .eq("plant_id", plantId)
      .in("status", ["pending", "revoked", "accepted", "expired"])
      .order("created_at", { ascending: false })
      .limit(100);
    if (invitesError) {
      throw invitesError;
    }

    return jsonResponse({
      ok: true,
      plantId,
      members: enrichedMembers,
      invites: (invites ?? []).map((row) => ({
        id: row.id,
        invitedEmail: row.invited_email,
        role: row.role,
        status: row.status,
        expiresAt: row.expires_at,
        createdAt: row.created_at,
      })),
    });
  } catch (error) {
    return errorResponse(error);
  }
});
