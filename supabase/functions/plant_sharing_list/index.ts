import {
  createAdminClient,
  requirePlantRole,
  requireUser,
} from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { createPlantSharingListHandler } from "./handler.ts";

const handler = createPlantSharingListHandler({
  handleOptions,
  jsonResponse,
  errorResponse,
  readJson,
  requireUser,
  requirePlantRole,
  createAdminClient,
});

Deno.serve(handler);
