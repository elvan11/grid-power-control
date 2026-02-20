import { requireNonEmptyString } from "../_shared/sharing.ts";

interface ListPayload {
  plantId: string;
}

interface ListMemberRow {
  auth_user_id: string;
  role: string;
  created_at: string;
}

interface ListInviteRow {
  id: string;
  invited_email: string;
  role: string;
  status: string;
  expires_at: string;
  created_at: string;
}

export interface PlantSharingListDeps {
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
  createAdminClient: () => {
    from: (table: string) => any;
    auth: {
      admin: {
        getUserById: (id: string) => Promise<{
          data: { user?: { email?: string } };
        }>;
      };
    };
  };
}

export function createPlantSharingListHandler(deps: PlantSharingListDeps) {
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
      const body = await deps.readJson<ListPayload>(req);
      const plantId = requireNonEmptyString(body.plantId, "plantId");

      await deps.requirePlantRole(userClient, plantId, ["owner", "admin"]);

      const adminClient = deps.createAdminClient();

      const { data: members, error: membersError } = await adminClient
        .from("plant_members")
        .select("auth_user_id,role,created_at")
        .eq("plant_id", plantId)
        .order("created_at", { ascending: true });
      if (membersError) {
        throw membersError;
      }

      const enrichedMembers = [];
      for (const row of (members ?? []) as ListMemberRow[]) {
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

      return deps.jsonResponse({
        ok: true,
        plantId,
        members: enrichedMembers,
        invites: ((invites ?? []) as ListInviteRow[]).map((row) => ({
          id: row.id,
          invitedEmail: row.invited_email,
          role: row.role,
          status: row.status,
          expiresAt: row.expires_at,
          createdAt: row.created_at,
        })),
      });
    } catch (error) {
      return deps.errorResponse(error);
    }
  };
}
