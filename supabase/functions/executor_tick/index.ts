import { prepareSpotImports } from "../_shared/spot_preparation.ts";
import { createAdminClient } from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { loadStoredSolisCredentials } from "../_shared/provider_store.ts";
import { applySolisControls } from "../_shared/solis.ts";
import { createExecutorTickHandler } from "./handler.ts";

const handler = createExecutorTickHandler({
  handleOptions,
  jsonResponse,
  errorResponse,
  readJson,
  createAdminClient,
  loadStoredSolisCredentials: (client, plantId) =>
    loadStoredSolisCredentials(
      client as ReturnType<typeof createAdminClient>,
      plantId,
    ),
  applySolisControls,
  getSpotContext: async (client, plantId, at) => {
    const { data, error } = await client.rpc("get_spot_import_context", {
      p_plant_id: plantId,
      p_at: at.toISOString(),
    });
    if (error) {
      console.error("spot_context_lookup_failed", error.message);
      return null;
    }
    return Array.isArray(data) ? (data[0] ?? null) : data;
  },
  prepareSpotImports: (client, now) =>
    prepareSpotImports(client, now, (name) => Deno.env.get(name)),
  getEnv: (name: string) => Deno.env.get(name),
  now: () => new Date(),
  sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
});

Deno.serve(handler);
