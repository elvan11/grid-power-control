import { HttpError } from "../_shared/http.ts";
import type { SolisCredentials, SolisRequestResult } from "../_shared/solis.ts";

export interface ApplyControlPayload {
  plantId: string;
  peakShavingW: number;
  gridChargingAllowed: boolean;
}

export interface ApplyControlDeps {
  handleOptions: (req: Request) => Response | null;
  jsonResponse: (
    payload: unknown,
    status?: number,
    headers?: Record<string, string>,
  ) => Response;
  errorResponse: (error: unknown) => Response;
  readJson: <T>(req: Request) => Promise<T>;
  requireUser: (req: Request) => Promise<{ userClient: unknown; userId: string }>;
  requirePlantRole: (
    userClient: unknown,
    plantId: string,
    roles: string[],
  ) => Promise<void>;
  validatePeakShavingW: (value: number) => number;
  getRuntimeSnapshot: (plantId: string) => Promise<
    | {
      last_applied_peak_shaving_w: number | null;
      last_applied_grid_charging_allowed: boolean | null;
    }
    | null
  >;
  loadStoredSolisCredentials: (
    plantId: string,
  ) => Promise<{ credentials: SolisCredentials }>;
  applySolisControls: (
    credentials: SolisCredentials,
    peakShavingW: number,
    gridChargingAllowed: boolean,
  ) => Promise<{ ok: boolean; steps: SolisRequestResult[] }>;
  insertApplyLog: (entry: {
    plant_id: string;
    requested_peak_shaving_w: number;
    requested_grid_charging_allowed: boolean;
    provider_type: "soliscloud";
    provider_result: "success" | "failed" | "skipped";
    provider_http_status?: number | null;
    provider_response: Record<string, unknown>;
  }) => Promise<void>;
  upsertRuntime: (entry: {
    plant_id: string;
    last_applied_at?: string;
    last_applied_peak_shaving_w?: number;
    last_applied_grid_charging_allowed?: boolean;
  }) => Promise<void>;
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
  };
}

export function createProviderApplyControlHandler(deps: ApplyControlDeps) {
  return async (req: Request): Promise<Response> => {
    const preflight = deps.handleOptions(req);
    if (preflight) {
      return preflight;
    }

    if (req.method !== "POST") {
      return deps.jsonResponse({ error: "Method not allowed" }, 405);
    }

    try {
      const { userClient, userId } = await deps.requireUser(req);
      const body = await deps.readJson<ApplyControlPayload>(req);
      const plantId = requirePlantId(body.plantId);

      await deps.requirePlantRole(userClient, plantId, ["owner", "admin", "member"]);

      const peakShavingW = deps.validatePeakShavingW(body.peakShavingW);
      if (typeof body.gridChargingAllowed !== "boolean") {
        return deps.jsonResponse(
          { error: "gridChargingAllowed must be boolean" },
          400,
        );
      }

      const runtimeSnapshot = await deps.getRuntimeSnapshot(plantId);
      const noChangeNeeded = runtimeSnapshot &&
        runtimeSnapshot.last_applied_peak_shaving_w === peakShavingW &&
        runtimeSnapshot.last_applied_grid_charging_allowed === body.gridChargingAllowed;

      if (noChangeNeeded) {
        await deps.insertApplyLog({
          plant_id: plantId,
          requested_peak_shaving_w: peakShavingW,
          requested_grid_charging_allowed: body.gridChargingAllowed,
          provider_type: "soliscloud",
          provider_result: "skipped",
          provider_response: {
            user_id: userId,
            reason: "already_applied",
          },
        });

        return deps.jsonResponse({
          ok: true,
          skipped: true,
          plantId,
          providerType: "soliscloud",
          requested: {
            peakShavingW,
            gridChargingAllowed: body.gridChargingAllowed,
          },
          attempts: [],
        });
      }

      const { credentials } = await deps.loadStoredSolisCredentials(plantId);
      const applyResult = await deps.applySolisControls(
        credentials,
        peakShavingW,
        body.gridChargingAllowed,
      );

      const finalStep = applyResult.steps[applyResult.steps.length - 1];
      const providerResult = applyResult.ok ? "success" : "failed";

      await deps.insertApplyLog({
        plant_id: plantId,
        requested_peak_shaving_w: peakShavingW,
        requested_grid_charging_allowed: body.gridChargingAllowed,
        provider_type: "soliscloud",
        provider_result: providerResult,
        provider_http_status: finalStep?.httpStatus ?? null,
        provider_response: {
          user_id: userId,
          attempts: applyResult.steps.map(sanitizeStep),
        },
      });

      if (applyResult.ok) {
        await deps.upsertRuntime({
          plant_id: plantId,
          last_applied_at: deps.now().toISOString(),
          last_applied_peak_shaving_w: peakShavingW,
          last_applied_grid_charging_allowed: body.gridChargingAllowed,
        });
      }

      return deps.jsonResponse(
        {
          ok: applyResult.ok,
          plantId,
          providerType: "soliscloud",
          requested: {
            peakShavingW,
            gridChargingAllowed: body.gridChargingAllowed,
          },
          attempts: applyResult.steps.map(sanitizeStep),
        },
        applyResult.ok ? 200 : 502,
      );
    } catch (error) {
      return deps.errorResponse(error);
    }
  };
}
