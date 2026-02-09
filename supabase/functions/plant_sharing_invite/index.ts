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
import {
  buildAcceptInviteUrl,
  generateInviteToken,
  requireEmail,
  requireInviteRole,
  requireNonEmptyString,
  sendInviteEmail,
  sha256Hex,
} from "../_shared/sharing.ts";

interface InvitePayload {
  plantId: string;
  invitedEmail: string;
  role?: "admin" | "member" | "viewer";
  acceptBaseUrl?: string;
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
    const { userClient, userId, userEmail } = await requireUser(req);
    const body = await readJson<InvitePayload>(req);
    const plantId = requireNonEmptyString(body.plantId, "plantId");
    const invitedEmail = requireEmail(body.invitedEmail);
    const role = requireInviteRole(body.role);

    await requirePlantRole(userClient, plantId, ["owner", "admin"]);

    const adminClient = createAdminClient();

    const { data: plantRow, error: plantError } = await adminClient
      .from("plants")
      .select("name")
      .eq("id", plantId)
      .single();
    if (plantError) {
      throw plantError;
    }

    const token = generateInviteToken();
    const tokenHash = await sha256Hex(token);
    const expiresAt = new Date(Date.now() + (7 * 24 * 60 * 60 * 1000)).toISOString();

    const { data: existingInvite, error: existingInviteError } = await adminClient
      .from("plant_invites")
      .select("id")
      .eq("plant_id", plantId)
      .eq("invited_email", invitedEmail)
      .eq("status", "pending")
      .maybeSingle();
    if (existingInviteError) {
      throw existingInviteError;
    }

    let inviteId: string;
    if (existingInvite?.id) {
      const { data: updatedInvite, error: updateError } = await adminClient
        .from("plant_invites")
        .update({
          role,
          token_hash: tokenHash,
          invited_by_auth_user_id: userId,
          expires_at: expiresAt,
        })
        .eq("id", existingInvite.id)
        .select("id")
        .single();
      if (updateError) {
        throw updateError;
      }
      inviteId = updatedInvite.id;
    } else {
      const { data: createdInvite, error: createError } = await adminClient
        .from("plant_invites")
        .insert({
          plant_id: plantId,
          invited_email: invitedEmail,
          invited_by_auth_user_id: userId,
          role,
          token_hash: tokenHash,
          status: "pending",
          expires_at: expiresAt,
        })
        .select("id")
        .single();
      if (createError) {
        throw createError;
      }
      inviteId = createdInvite.id;
    }

    const acceptUrl = buildAcceptInviteUrl(token, body.acceptBaseUrl);
    let emailDispatch;
    try {
      emailDispatch = await sendInviteEmail({
        invitedEmail,
        invitedByEmail: userEmail,
        plantName: plantRow.name,
        role,
        acceptUrl,
        expiresAtIso: expiresAt,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown email error";
      emailDispatch = {
        sent: false,
        provider: "disabled",
        providerMessage: `Invite created, but email delivery failed: ${message}`,
      };
    }

    return jsonResponse({
      ok: true,
      plantId,
      invite: {
        id: inviteId,
        invitedEmail,
        role,
        status: "pending",
        expiresAt,
      },
      emailDispatch,
      acceptUrlPreview: acceptUrl,
    });
  } catch (error) {
    return errorResponse(error);
  }
});
