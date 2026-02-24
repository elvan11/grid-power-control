import { HttpError } from "../_shared/http.ts";
import type { SolisCredentials } from "../_shared/solis.ts";

export interface ProviderConnectionGetPayload {
  plantId: string;
}

export interface ProviderConnectionGetDeps {
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
  loadStoredSolisCredentials: (
    plantId: string,
  ) => Promise<{
    displayName: string;
    credentials: SolisCredentials;
  }>;
}

function requirePlantId(value: unknown): string {
  const plantId = typeof value === "string" ? value.trim() : "";
  if (!plantId) {
    throw new HttpError(400, "plantId is required");
  }
  return plantId;
}

export function createProviderConnectionGetHandler(deps: ProviderConnectionGetDeps) {
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
      const body = await deps.readJson<ProviderConnectionGetPayload>(req);
      const plantId = requirePlantId(body.plantId);

      await deps.requirePlantRole(userClient, plantId, ["owner", "admin", "member", "viewer"]);

      const stored = await deps.loadStoredSolisCredentials(plantId);

      return deps.jsonResponse({
        ok: true,
        plantId,
        providerType: "soliscloud",
        displayName: stored.displayName,
        config: {
          inverterSn: stored.credentials.inverterSn,
          stationId: stored.credentials.stationId ?? "",
          apiId: stored.credentials.apiId,
          apiSecret: stored.credentials.apiSecret,
          apiBaseUrl: stored.credentials.apiBaseUrl ?? "",
        },
      });
    } catch (error) {
      return deps.errorResponse(error);
    }
  };
}
