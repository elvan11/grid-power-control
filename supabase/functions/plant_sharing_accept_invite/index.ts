import { createAdminClient, requireUser } from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import {
  type InviteRole,
  mergeRole,
  normalizeEmail,
  type PlantMemberRole,
  requireNonEmptyString,
  sha256Hex,
} from "../_shared/sharing.ts";

interface AcceptInvitePayload {
  token: string;
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
    const { userId, userEmail } = await requireUser(req);
    if (!userEmail) {
      throw new HttpError(400, "Authenticated user does not have an email");
    }

    const body = await readJson<AcceptInvitePayload>(req);
    const token = requireNonEmptyString(body.token, "token");
    const tokenHash = await sha256Hex(token);
    const normalizedUserEmail = normalizeEmail(userEmail);

    const adminClient = createAdminClient();
    const { data: invite, error: inviteError } = await adminClient
      .from("plant_invites")
      .select("id,plant_id,invited_email,role,expires_at")
      .eq("token_hash", tokenHash)
      .eq("status", "pending")
      .maybeSingle();
    if (inviteError) {
      throw inviteError;
    }
    if (!invite) {
      throw new HttpError(404, "Invite token is invalid or no longer active");
    }

    if (new Date(invite.expires_at).getTime() <= Date.now()) {
      await adminClient
        .from("plant_invites")
        .update({ status: "expired" })
        .eq("id", invite.id);
      throw new HttpError(410, "Invite has expired");
    }

    if (normalizeEmail(invite.invited_email) !== normalizedUserEmail) {
      throw new HttpError(
        403,
        "Invite email does not match the authenticated user email",
      );
    }

    const inviteRole = invite.role as InviteRole;
    const { data: existingMembership, error: membershipError } = await adminClient
      .from("plant_members")
      .select("role")
      .eq("plant_id", invite.plant_id)
      .eq("auth_user_id", userId)
      .maybeSingle();
    if (membershipError) {
      throw membershipError;
    }

    const finalRole: PlantMemberRole = existingMembership
      ? mergeRole(existingMembership.role as PlantMemberRole, inviteRole)
      : inviteRole;

    if (existingMembership) {
      const { error: updateMembershipError } = await adminClient
        .from("plant_members")
        .update({ role: finalRole })
        .eq("plant_id", invite.plant_id)
        .eq("auth_user_id", userId);
      if (updateMembershipError) {
        throw updateMembershipError;
      }
    } else {
      const { error: insertMembershipError } = await adminClient
        .from("plant_members")
        .insert({
          plant_id: invite.plant_id,
          auth_user_id: userId,
          role: finalRole,
        });
      if (insertMembershipError) {
        throw insertMembershipError;
      }
    }

    const { error: acceptError } = await adminClient
      .from("plant_invites")
      .update({
        status: "accepted",
        accepted_at: new Date().toISOString(),
        accepted_by_auth_user_id: userId,
      })
      .eq("id", invite.id);
    if (acceptError) {
      throw acceptError;
    }

    return jsonResponse({
      ok: true,
      plantId: invite.plant_id,
      inviteId: invite.id,
      role: finalRole,
    });
  } catch (error) {
    return errorResponse(error);
  }
});
