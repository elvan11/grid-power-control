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
import {
  type PlantMemberRole,
  requireNonEmptyString,
} from "../_shared/sharing.ts";

interface RemoveMemberPayload {
  plantId: string;
  memberUserId: string;
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
    const { userClient, userId } = await requireUser(req);
    const body = await readJson<RemoveMemberPayload>(req);
    const plantId = requireNonEmptyString(body.plantId, "plantId");
    const memberUserId = requireNonEmptyString(body.memberUserId, "memberUserId");

    await requirePlantRole(userClient, plantId, ["owner", "admin"]);

    const adminClient = createAdminClient();
    const { data: actorMembership, error: actorMembershipError } = await adminClient
      .from("plant_members")
      .select("role")
      .eq("plant_id", plantId)
      .eq("auth_user_id", userId)
      .single();
    if (actorMembershipError) {
      throw actorMembershipError;
    }

    const { data: targetMembership, error: targetMembershipError } = await adminClient
      .from("plant_members")
      .select("role")
      .eq("plant_id", plantId)
      .eq("auth_user_id", memberUserId)
      .maybeSingle();
    if (targetMembershipError) {
      throw targetMembershipError;
    }
    if (!targetMembership) {
      throw new HttpError(404, "Member not found");
    }

    const actorRole = actorMembership.role as PlantMemberRole;
    const targetRole = targetMembership.role as PlantMemberRole;
    if (targetRole === "owner" && actorRole !== "owner") {
      throw new HttpError(403, "Only owners can remove owner members");
    }

    if (targetRole === "owner") {
      const { count: ownerCount, error: ownerCountError } = await adminClient
        .from("plant_members")
        .select("auth_user_id", { count: "exact", head: true })
        .eq("plant_id", plantId)
        .eq("role", "owner");
      if (ownerCountError) {
        throw ownerCountError;
      }
      if ((ownerCount ?? 0) <= 1) {
        throw new HttpError(400, "Cannot remove the last owner from a plant");
      }
    }

    const { error: deleteError } = await adminClient
      .from("plant_members")
      .delete()
      .eq("plant_id", plantId)
      .eq("auth_user_id", memberUserId);
    if (deleteError) {
      throw deleteError;
    }

    return jsonResponse({
      ok: true,
      plantId,
      removedMemberUserId: memberUserId,
    });
  } catch (error) {
    return errorResponse(error);
  }
});
