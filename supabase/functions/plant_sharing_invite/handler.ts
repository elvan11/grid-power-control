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

export interface PlantSharingInviteDeps {
  handleOptions: (req: Request) => Response | null;
  jsonResponse: (
    payload: unknown,
    status?: number,
    headers?: Record<string, string>,
  ) => Response;
  errorResponse: (error: unknown) => Response;
  readJson: <T>(req: Request) => Promise<T>;
  requireUser: (
    req: Request,
  ) => Promise<{ userClient: unknown; userId: string; userEmail: string | null }>;
  requirePlantRole: (
    userClient: unknown,
    plantId: string,
    roles: string[],
  ) => Promise<void>;
  createAdminClient: () => {
    from: (table: string) => any;
  };
  now: () => Date;
}

export function createPlantSharingInviteHandler(deps: PlantSharingInviteDeps) {
  return async (req: Request): Promise<Response> => {
    const preflight = deps.handleOptions(req);
    if (preflight) {
      return preflight;
    }

    if (req.method !== "POST") {
      return deps.jsonResponse({ error: "Method not allowed" }, 405);
    }

    try {
      const { userClient, userId, userEmail } = await deps.requireUser(req);
      const body = await deps.readJson<InvitePayload>(req);
      const plantId = requireNonEmptyString(body.plantId, "plantId");
      const invitedEmail = requireEmail(body.invitedEmail);
      const role = requireInviteRole(body.role);

      await deps.requirePlantRole(userClient, plantId, ["owner", "admin"]);

      const adminClient = deps.createAdminClient();
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
      const expiresAt = new Date(
        deps.now().getTime() + (7 * 24 * 60 * 60 * 1000),
      ).toISOString();

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

      return deps.jsonResponse({
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
      return deps.errorResponse(error);
    }
  };
}
