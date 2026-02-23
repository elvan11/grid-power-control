import { createAdminClient, requirePlantRole, requireUser } from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { loadStoredSolisCredentials } from "../_shared/provider_store.ts";
import { createProviderConnectionGetHandler } from "./handler.ts";

const adminClient = createAdminClient();

const handler = createProviderConnectionGetHandler({
  handleOptions,
  jsonResponse,
  errorResponse,
  readJson,
  requireUser,
  requirePlantRole,
  loadStoredSolisCredentials: async (plantId) => {
    return await loadStoredSolisCredentials(adminClient, plantId);
  },
});

Deno.serve(handler);
