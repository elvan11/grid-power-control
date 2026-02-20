import { createAdminClient, requireUser } from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { createPlantSharingAcceptInviteHandler } from "./handler.ts";

const handler = createPlantSharingAcceptInviteHandler({
  handleOptions,
  jsonResponse,
  errorResponse,
  readJson,
  requireUser,
  createAdminClient,
  now: () => new Date(),
});

Deno.serve(handler);
