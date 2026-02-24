import { HttpError } from "../_shared/http.ts";

export interface UpsertPayload {
  plantId: string;
  displayName: string;
  inverterSn: string;
  stationId?: string;
  apiId: string;
  apiSecret: string;
  apiBaseUrl?: string;
}

export interface UpsertResult {
  connectionId: string;
  updatedAt: string;
}

export interface ProviderConnectionUpsertDeps {
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
  upsertStoredSolisCredentials: (
    input: UpsertPayload,
  ) => Promise<UpsertResult>;
}

function requirePlantId(value: unknown): string {
  const plantId = typeof value === "string" ? value.trim() : "";
  if (!plantId) {
    throw new HttpError(400, "plantId is required");
  }
  return plantId;
}

export function createProviderConnectionUpsertHandler(
  deps: ProviderConnectionUpsertDeps,
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
      const body = await deps.readJson<UpsertPayload>(req);
      const plantId = requirePlantId(body.plantId);

      await deps.requirePlantRole(userClient, plantId, ["owner", "admin"]);
      const result = await deps.upsertStoredSolisCredentials({
        ...body,
        plantId,
      });

      return deps.jsonResponse({
        ok: true,
        plantId,
        providerType: "soliscloud",
        displayName: body.displayName,
        inverterSn: body.inverterSn,
        connectionId: result.connectionId,
        updatedAt: result.updatedAt,
        credentialsStored: true,
      });
    } catch (error) {
      return deps.errorResponse(error);
    }
  };
}
