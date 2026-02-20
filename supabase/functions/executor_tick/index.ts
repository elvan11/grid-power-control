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
  loadStoredSolisCredentials,
  applySolisControls,
  getEnv: (name: string) => Deno.env.get(name),
  now: () => new Date(),
  sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
});

Deno.serve(handler);
