import { createAdminClient, requirePlantRole, requireUser } from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { loadStoredSolisCredentials } from "../_shared/provider_store.ts";
import {
  applySolisControls,
  type SolisRequestResult,
  validatePeakShavingW,
} from "../_shared/solis.ts";

interface ApplyControlPayload {
  plantId: string;
  peakShavingW: number;
  gridChargingAllowed: boolean;
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

Deno.serve(async (req: Request) => {
  const preflight = handleOptions(req);
  if (preflight) {
    return preflight;
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const { userClient, userId } = await requireUser(req);
    const body = await readJson<ApplyControlPayload>(req);
    const plantId = requirePlantId(body.plantId);

    await requirePlantRole(userClient, plantId, ["owner", "admin", "member"]);

    const peakShavingW = validatePeakShavingW(body.peakShavingW);
    if (typeof body.gridChargingAllowed !== "boolean") {
      return jsonResponse({ error: "gridChargingAllowed must be boolean" }, 400);
    }

    const adminClient = createAdminClient();
    const { credentials } = await loadStoredSolisCredentials(adminClient, plantId);
    const { data: runtimeSnapshot } = await adminClient
      .from("plant_runtime")
      .select("last_applied_peak_shaving_w,last_applied_grid_charging_allowed")
      .eq("plant_id", plantId)
      .maybeSingle();

    const noChangeNeeded = runtimeSnapshot &&
      runtimeSnapshot.last_applied_peak_shaving_w === peakShavingW &&
      runtimeSnapshot.last_applied_grid_charging_allowed === body.gridChargingAllowed;

    if (noChangeNeeded) {
      const { error: skippedLogError } = await adminClient
        .from("control_apply_log")
        .insert({
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
      if (skippedLogError) {
        console.error("control_apply_log skipped insert failed", skippedLogError);
      }

      return jsonResponse({
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

    const applyResult = await applySolisControls(
      credentials,
      peakShavingW,
      body.gridChargingAllowed,
    );

    const finalStep = applyResult.steps[applyResult.steps.length - 1];
    const providerResult = applyResult.ok ? "success" : "failed";

    const { error: logError } = await adminClient
      .from("control_apply_log")
      .insert({
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
    if (logError) {
      console.error("control_apply_log insert failed", logError);
    }

    if (applyResult.ok) {
      const { error: runtimeError } = await adminClient
        .from("plant_runtime")
        .upsert(
          {
            plant_id: plantId,
            last_applied_at: new Date().toISOString(),
            last_applied_peak_shaving_w: peakShavingW,
            last_applied_grid_charging_allowed: body.gridChargingAllowed,
          },
          { onConflict: "plant_id" },
        );
      if (runtimeError) {
        console.error("plant_runtime upsert failed", runtimeError);
      }
    }

    return jsonResponse(
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
    return errorResponse(error);
  }
});
