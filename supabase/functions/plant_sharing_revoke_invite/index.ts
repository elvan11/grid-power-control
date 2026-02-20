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
import { createPlantSharingRevokeInviteHandler } from "./handler.ts";

const handler = createPlantSharingRevokeInviteHandler({
  handleOptions,
  jsonResponse,
  errorResponse,
  readJson,
  requireUser,
  requirePlantRole,
  createAdminClient,
});

Deno.serve(handler);
