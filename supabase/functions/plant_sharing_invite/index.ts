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
import { createPlantSharingInviteHandler } from "./handler.ts";

const handler = createPlantSharingInviteHandler({
  handleOptions,
  jsonResponse,
  errorResponse,
  readJson,
  requireUser,
  requirePlantRole,
  createAdminClient,
  now: () => new Date(),
});

Deno.serve(handler);
