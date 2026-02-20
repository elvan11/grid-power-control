import { HttpError } from "../_shared/http.ts";
import type { SolisCredentials } from "../_shared/solis.ts";

export interface ConnectionTestPayload {
  plantId: string;
  inverterSn?: string;
  apiId?: string;
  apiSecret?: string;
  apiBaseUrl?: string;
}

export interface ConnectionTestDeps {
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
  ) => Promise<{ credentials: SolisCredentials }>;
  testSolisConnection: (credentials: SolisCredentials) => Promise<{
    ok: boolean;
    endpoint: string;
    httpStatus: number;
    code: string | null;
    message: string;
    attempts: number;
    durationMs: number;
  }>;
}

function hasInlineCredentials(payload: ConnectionTestPayload): boolean {
  return Boolean(
    payload.apiId?.trim() && payload.apiSecret?.trim() && payload.inverterSn?.trim(),
  );
}

function hasAnyInlineCredential(payload: ConnectionTestPayload): boolean {
  return Boolean(
    payload.apiId?.trim() || payload.apiSecret?.trim() || payload.inverterSn?.trim(),
  );
}

function requirePlantId(value: unknown): string {
  const plantId = typeof value === "string" ? value.trim() : "";
  if (!plantId) {
    throw new HttpError(400, "plantId is required");
  }
  return plantId;
}

function buildInlineCredentials(payload: ConnectionTestPayload): SolisCredentials {
  return {
    apiId: payload.apiId!.trim(),
    apiSecret: payload.apiSecret!.trim(),
    inverterSn: payload.inverterSn!.trim(),
    apiBaseUrl: payload.apiBaseUrl?.trim() || undefined,
  };
}

export function createProviderConnectionTestHandler(deps: ConnectionTestDeps) {
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
      const body = await deps.readJson<ConnectionTestPayload>(req);
      const plantId = requirePlantId(body.plantId);

      await deps.requirePlantRole(userClient, plantId, ["owner", "admin"]);

      if (hasAnyInlineCredential(body) && !hasInlineCredentials(body)) {
        throw new HttpError(
          400,
          "When testing with inline credentials, apiId, apiSecret, and inverterSn are all required",
        );
      }

      const credentials = hasInlineCredentials(body)
        ? buildInlineCredentials(body)
        : (await deps.loadStoredSolisCredentials(plantId)).credentials;
      const result = await deps.testSolisConnection(credentials);

      return deps.jsonResponse({
        ok: result.ok,
        plantId,
        providerType: "soliscloud",
        endpoint: result.endpoint,
        httpStatus: result.httpStatus,
        code: result.code,
        message: result.message,
        attempts: result.attempts,
        durationMs: result.durationMs,
      }, result.ok ? 200 : 502);
    } catch (error) {
      return deps.errorResponse(error);
    }
  };
}
