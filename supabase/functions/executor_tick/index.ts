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

const EXECUTOR_LOOKAHEAD_MS = 5 * 60_000;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function extractBearerToken(req: Request): string {
  const authHeader = req.headers.get("Authorization") ?? "";
  return authHeader.startsWith("Bearer ")
    ? authHeader.replace("Bearer ", "").trim()
    : authHeader.trim();
}

async function requireExecutorSecret(
  req: Request,
  adminClient: ReturnType<typeof createAdminClient>,
): Promise<void> {
  const token = extractBearerToken(req);
  if (!token) {
    throw new HttpError(401, "Unauthorized executor secret");
  }

  const expectedEnv = Deno.env.get("EXECUTOR_SECRET")?.trim();
  if (expectedEnv && token === expectedEnv) {
    return;
  }

  const { data, error } = await adminClient.rpc(
    "get_executor_secret_from_vault",
  );
  if (error) {
    throw new HttpError(500, "Failed to read executor secret", error);
  }

  const expectedVault = typeof data === "string" ? data.trim() : "";
  if (!expectedVault || token !== expectedVault) {
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
  const now = new Date();
  const nowIso = now.toISOString();
  const lookaheadIso = new Date(now.getTime() + EXECUTOR_LOOKAHEAD_MS).toISOString();

  const { data: desiredRowsNow, error: desiredErrorNow } = await adminClient.rpc(
    "compute_plant_desired_control",
    {
      p_plant_id: plantId,
      p_at: nowIso,
    },
  );
  if (desiredErrorNow) {
    await upsertRuntime(adminClient, {
      plant_id: plantId,
      next_due_at: new Date(Date.now() + 60_000).toISOString(),
    });
    return {
      plantId,
      status: "failed",
      detail: `compute_desired_failed: ${desiredErrorNow.message}`,
    };
  }

  const desiredNow = (Array.isArray(desiredRowsNow) ? desiredRowsNow[0] : desiredRowsNow) as
    | DesiredControlRow
    | null;
  if (!desiredNow) {
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

  let desired = desiredNow;
  if (desiredNow.source !== "override") {
    const { data: desiredRowsLookahead, error: desiredErrorLookahead } = await adminClient.rpc(
      "compute_plant_desired_control",
      {
        p_plant_id: plantId,
        p_at: lookaheadIso,
      },
    );

    if (desiredErrorLookahead) {
      console.error("compute_desired_lookahead_failed", desiredErrorLookahead);
    } else {
      const desiredLookahead = (Array.isArray(desiredRowsLookahead)
        ? desiredRowsLookahead[0]
        : desiredRowsLookahead) as DesiredControlRow | null;
      if (desiredLookahead) {
        desired = desiredLookahead;
      }
    }
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
    const adminClient = createAdminClient();
    await requireExecutorSecret(req, adminClient);
    const body = await readJson<TickPayload>(req);
    const { limit, leaseSeconds } = normalizeTickInput(body ?? {});
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
