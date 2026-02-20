import { HttpError } from "../_shared/http.ts";
import { requireNonEmptyString } from "../_shared/sharing.ts";

interface RevokeInvitePayload {
  plantId: string;
  inviteId: string;
}

export interface PlantSharingRevokeInviteDeps {
  handleOptions: (req: Request) => Response | null;
  jsonResponse: (
    payload: unknown,
    status?: number,
    headers?: Record<string, string>,
  ) => Response;
  errorResponse: (error: unknown) => Response;
  readJson: <T>(req: Request) => Promise<T>;
  requireUser: (req: Request) => Promise<{ userClient: unknown }>;
  requirePlantRole: (
    userClient: unknown,
    plantId: string,
    roles: string[],
  ) => Promise<void>;
  createAdminClient: () => { from: (table: string) => any };
}

export function createPlantSharingRevokeInviteHandler(
  deps: PlantSharingRevokeInviteDeps,
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
      const { userClient } = await deps.requireUser(req);
      const body = await deps.readJson<RevokeInvitePayload>(req);
      const plantId = requireNonEmptyString(body.plantId, "plantId");
      const inviteId = requireNonEmptyString(body.inviteId, "inviteId");

      await deps.requirePlantRole(userClient, plantId, ["owner", "admin"]);

      const adminClient = deps.createAdminClient();
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

      return deps.jsonResponse({
        ok: true,
        plantId,
        inviteId,
        status: "revoked",
      });
    } catch (error) {
      return deps.errorResponse(error);
    }
  };
}
