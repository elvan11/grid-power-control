import { createAdminClient, requirePlantRole, requireUser } from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { loadStoredSolisCredentials } from "../_shared/provider_store.ts";
import {
  applySolisControls,
  validatePeakShavingW,
} from "../_shared/solis.ts";
import { createProviderApplyControlHandler } from "./handler.ts";

const adminClient = createAdminClient();

const handler = createProviderApplyControlHandler({
  handleOptions,
  jsonResponse,
  errorResponse,
  readJson,
  requireUser,
  requirePlantRole,
  validatePeakShavingW,
  getRuntimeSnapshot: async (plantId) => {
    const { data } = await adminClient
      .from("plant_runtime")
      .select("last_applied_peak_shaving_w,last_applied_grid_charging_allowed")
      .eq("plant_id", plantId)
      .maybeSingle();
    return data ?? null;
  },
  loadStoredSolisCredentials: async (plantId) => {
    return await loadStoredSolisCredentials(adminClient, plantId);
  },
  applySolisControls,
  insertApplyLog: async (entry) => {
    const { error } = await adminClient.from("control_apply_log").insert(entry);
    if (error) {
      console.error("control_apply_log insert failed", error);
    }
  },
  upsertRuntime: async (entry) => {
    const { error } = await adminClient
      .from("plant_runtime")
      .upsert(entry, { onConflict: "plant_id" });
    if (error) {
      console.error("plant_runtime upsert failed", error);
    }
  },
  now: () => new Date(),
});

Deno.serve(handler);
