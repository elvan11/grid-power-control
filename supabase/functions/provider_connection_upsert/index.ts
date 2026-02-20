import { createAdminClient, requirePlantRole, requireUser } from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { upsertStoredSolisCredentials } from "../_shared/provider_store.ts";
import { createProviderConnectionUpsertHandler } from "./handler.ts";

const adminClient = createAdminClient();

const handler = createProviderConnectionUpsertHandler({
  handleOptions,
  jsonResponse,
  errorResponse,
  readJson,
  requireUser,
  requirePlantRole,
  upsertStoredSolisCredentials: async (input) => {
    return await upsertStoredSolisCredentials(adminClient, input);
  },
});

Deno.serve(handler);
