import { HttpError } from "../_shared/http.ts";
import type {
  SolisCredentials,
  SolisRequestResult,
} from "../_shared/solis.ts";

export interface ProviderBatterySocPayload {
  plantId: string;
}

export interface ProviderBatterySocDeps {
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
    credentials: SolisCredentials;
  }>;
  readSolisBatterySoc: (
    credentials: SolisCredentials,
  ) => Promise<{
    batteryPercentage: number;
    stationId: string;
    steps: SolisRequestResult[];
  }>;
  now: () => Date;
}

function requirePlantId(value: unknown): string {
  const plantId = typeof value === "string" ? value.trim() : "";
  if (!plantId) {
    throw new HttpError(400, "plantId is required");
  }
  return plantId;
}

function sanitizeStep(step: SolisRequestResult) {
  return {
    ok: step.ok,
    endpoint: step.endpoint,
    httpStatus: step.httpStatus,
    code: step.code,
    message: step.message,
    attempts: step.attempts,
    durationMs: step.durationMs,
    cid: step.payload.cid ?? null,
    stationId: step.payload.id ?? null,
  };
}

export function createProviderBatterySocHandler(deps: ProviderBatterySocDeps) {
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
      const body = await deps.readJson<ProviderBatterySocPayload>(req);
      const plantId = requirePlantId(body.plantId);

      await deps.requirePlantRole(
        userClient,
        plantId,
        ["owner", "admin", "member", "viewer"],
      );

      const { credentials } = await deps.loadStoredSolisCredentials(plantId);
      const socResult = await deps.readSolisBatterySoc(credentials);

      return deps.jsonResponse({
        ok: true,
        plantId,
        providerType: "soliscloud",
        batteryPercentage: socResult.batteryPercentage,
        stationId: socResult.stationId,
        fetchedAt: deps.now().toISOString(),
        attempts: socResult.steps.map(sanitizeStep),
      });
    } catch (error) {
      return deps.errorResponse(error);
    }
  };
}
