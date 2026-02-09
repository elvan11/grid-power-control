import { createAdminClient } from "../_shared/auth.ts";
import { errorResponse, handleOptions, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { loadStoredSolisCredentials } from "../_shared/provider_store.ts";
import { applySolisControls, type SolisRequestResult } from "../_shared/solis.ts";

interface TickPayload {
  limit?: number;
  leaseSeconds?: number;
}

interface DesiredControlRow {
  desired_peak_shaving_w: number;
  desired_grid_charging_allowed: boolean;
  next_due_at: string;
  source: string;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function requireExecutorSecret(req: Request): void {
  const expected = Deno.env.get("EXECUTOR_SECRET");
  if (!expected) {
    throw new HttpError(500, "Missing EXECUTOR_SECRET environment variable");
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.replace("Bearer ", "").trim()
    : authHeader.trim();

  if (!token || token !== expected) {
    throw new HttpError(401, "Unauthorized executor secret");
  }
}

function normalizeTickInput(payload: TickPayload) {
  const limit = Math.min(Math.max(Math.trunc(payload.limit ?? 30), 1), 100);
  const leaseSeconds = Math.min(
    Math.max(Math.trunc(payload.leaseSeconds ?? 55), 10),
    300,
  );
  return { limit, leaseSeconds };
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

async function upsertRuntime(
  adminClient: ReturnType<typeof createAdminClient>,
  data: Record<string, unknown>,
): Promise<void> {
  const { error } = await adminClient
    .from("plant_runtime")
    .upsert(data, { onConflict: "plant_id" });
  if (error) {
    console.error("plant_runtime upsert failed", error);
  }
}

async function insertApplyLog(
  adminClient: ReturnType<typeof createAdminClient>,
  data: Record<string, unknown>,
): Promise<void> {
  const { error } = await adminClient.from("control_apply_log").insert(data);
  if (error) {
    console.error("control_apply_log insert failed", error);
  }
}

async function processPlant(
  adminClient: ReturnType<typeof createAdminClient>,
  plantId: string,
): Promise<{ plantId: string; status: "applied" | "skipped" | "failed"; detail: string }> {
  const nowIso = new Date().toISOString();

  const { data: desiredRows, error: desiredError } = await adminClient.rpc(
    "compute_plant_desired_control",
    {
      p_plant_id: plantId,
      p_at: nowIso,
    },
  );
  if (desiredError) {
    await upsertRuntime(adminClient, {
      plant_id: plantId,
      next_due_at: new Date(Date.now() + 60_000).toISOString(),
    });
    return {
      plantId,
      status: "failed",
      detail: `compute_desired_failed: ${desiredError.message}`,
    };
  }

  const desired = (Array.isArray(desiredRows) ? desiredRows[0] : desiredRows) as
    | DesiredControlRow
    | null;
  if (!desired) {
    await upsertRuntime(adminClient, {
      plant_id: plantId,
      next_due_at: new Date(Date.now() + 60_000).toISOString(),
    });
    return {
      plantId,
      status: "failed",
      detail: "compute_desired_returned_empty",
    };
  }

  const { data: runtimeSnapshot } = await adminClient
    .from("plant_runtime")
    .select("last_applied_peak_shaving_w,last_applied_grid_charging_allowed")
    .eq("plant_id", plantId)
    .maybeSingle();

  const idempotentSkip = runtimeSnapshot &&
    runtimeSnapshot.last_applied_peak_shaving_w === desired.desired_peak_shaving_w &&
    runtimeSnapshot.last_applied_grid_charging_allowed ===
      desired.desired_grid_charging_allowed;

  if (idempotentSkip) {
    await insertApplyLog(adminClient, {
      plant_id: plantId,
      requested_peak_shaving_w: desired.desired_peak_shaving_w,
      requested_grid_charging_allowed: desired.desired_grid_charging_allowed,
      provider_type: "soliscloud",
      provider_result: "skipped",
      provider_response: {
        source: desired.source,
        reason: "already_applied",
        by: "executor_tick",
      },
    });

    await upsertRuntime(adminClient, {
      plant_id: plantId,
      next_due_at: desired.next_due_at,
    });

    return { plantId, status: "skipped", detail: "already_applied" };
  }

  try {
    const { credentials } = await loadStoredSolisCredentials(adminClient, plantId);
    const applyResult = await applySolisControls(
      credentials,
      desired.desired_peak_shaving_w,
      desired.desired_grid_charging_allowed,
    );
    const finalStep = applyResult.steps[applyResult.steps.length - 1];

    await insertApplyLog(adminClient, {
      plant_id: plantId,
      requested_peak_shaving_w: desired.desired_peak_shaving_w,
      requested_grid_charging_allowed: desired.desired_grid_charging_allowed,
      provider_type: "soliscloud",
      provider_result: applyResult.ok ? "success" : "failed",
      provider_http_status: finalStep?.httpStatus ?? null,
      provider_response: {
        source: desired.source,
        by: "executor_tick",
        attempts: applyResult.steps.map(sanitizeStep),
      },
    });

    if (applyResult.ok) {
      await upsertRuntime(adminClient, {
        plant_id: plantId,
        next_due_at: desired.next_due_at,
        last_applied_at: new Date().toISOString(),
        last_applied_peak_shaving_w: desired.desired_peak_shaving_w,
        last_applied_grid_charging_allowed: desired.desired_grid_charging_allowed,
      });
      return { plantId, status: "applied", detail: "applied" };
    }

    await upsertRuntime(adminClient, {
      plant_id: plantId,
      next_due_at: new Date(Date.now() + 60_000).toISOString(),
    });
    return {
      plantId,
      status: "failed",
      detail: finalStep?.message ?? "provider_apply_failed",
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : "provider_setup_failed";
    await insertApplyLog(adminClient, {
      plant_id: plantId,
      requested_peak_shaving_w: desired.desired_peak_shaving_w,
      requested_grid_charging_allowed: desired.desired_grid_charging_allowed,
      provider_type: "soliscloud",
      provider_result: "failed",
      provider_response: {
        source: desired.source,
        by: "executor_tick",
        error: message,
      },
    });

    await upsertRuntime(adminClient, {
      plant_id: plantId,
      next_due_at: new Date(Date.now() + 5 * 60_000).toISOString(),
    });
    return { plantId, status: "failed", detail: message };
  }
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
    requireExecutorSecret(req);
    const body = await readJson<TickPayload>(req);
    const { limit, leaseSeconds } = normalizeTickInput(body ?? {});

    const adminClient = createAdminClient();
    const { data: claimed, error: claimError } = await adminClient.rpc(
      "claim_due_plants",
      {
        p_limit: limit,
        p_lease_seconds: leaseSeconds,
      },
    );
    if (claimError) {
      throw new HttpError(500, "Failed to claim due plants", claimError);
    }

    const claimedPlantIds = (claimed ?? []).map((row: { plant_id: string }) =>
      row.plant_id
    );

    const results: Array<{ plantId: string; status: "applied" | "skipped" | "failed"; detail: string }> = [];
    for (const plantId of claimedPlantIds) {
      const result = await processPlant(adminClient, plantId);
      results.push(result);
      await sleep(600);
    }

    const summary = {
      claimed: claimedPlantIds.length,
      applied: results.filter((r) => r.status === "applied").length,
      skipped: results.filter((r) => r.status === "skipped").length,
      failed: results.filter((r) => r.status === "failed").length,
    };

    return jsonResponse({
      ok: true,
      summary,
      results,
    });
  } catch (error) {
    return errorResponse(error);
  }
});

