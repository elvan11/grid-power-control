import { HttpError } from "../_shared/http.ts";
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

export interface PlantSharingAcceptInviteDeps {
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
  ) => Promise<{ userId: string; userEmail: string | null }>;
  createAdminClient: () => { from: (table: string) => any };
  now: () => Date;
}

export function createPlantSharingAcceptInviteHandler(
  deps: PlantSharingAcceptInviteDeps,
) {
  return async (req: Request): Promise<Response> => {
    const preflight = deps.handleOptions(req);
    if (preflight) {
      return preflight;
    }

    if (req.method !== "POST") {
      return deps.jsonResponse({ error: "Method not allowed" }, 405);
    }

    try {
      const { userId, userEmail } = await deps.requireUser(req);
      if (!userEmail) {
        throw new HttpError(400, "Authenticated user does not have an email");
      }

      const body = await deps.readJson<AcceptInvitePayload>(req);
      const token = requireNonEmptyString(body.token, "token");
      const tokenHash = await sha256Hex(token);
      const normalizedUserEmail = normalizeEmail(userEmail);

      const adminClient = deps.createAdminClient();
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

      if (new Date(invite.expires_at).getTime() <= deps.now().getTime()) {
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
          accepted_at: deps.now().toISOString(),
          accepted_by_auth_user_id: userId,
        })
        .eq("id", invite.id);
      if (acceptError) {
        throw acceptError;
      }

      return deps.jsonResponse({
        ok: true,
        plantId: invite.plant_id,
        inviteId: invite.id,
        role: finalRole,
      });
    } catch (error) {
      return deps.errorResponse(error);
    }
  };
}
