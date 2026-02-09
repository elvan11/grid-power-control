import { createAdminClient, requirePlantRole, requireUser } from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { upsertStoredSolisCredentials } from "../_shared/provider_store.ts";

interface UpsertPayload {
  plantId: string;
  displayName: string;
  inverterSn: string;
  apiId: string;
  apiSecret: string;
  apiBaseUrl?: string;
}

function requirePlantId(value: unknown): string {
  const plantId = typeof value === "string" ? value.trim() : "";
  if (!plantId) {
    throw new HttpError(400, "plantId is required");
  }
  return plantId;
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
    const { userClient } = await requireUser(req);
    const body = await readJson<UpsertPayload>(req);
    const plantId = requirePlantId(body.plantId);

    await requirePlantRole(userClient, plantId, ["owner", "admin"]);

    const adminClient = createAdminClient();
    const result = await upsertStoredSolisCredentials(adminClient, {
      ...body,
      plantId,
    });

    return jsonResponse({
      ok: true,
      plantId,
      providerType: "soliscloud",
      displayName: body.displayName,
      inverterSn: body.inverterSn,
      connectionId: result.connectionId,
      updatedAt: result.updatedAt,
      credentialsStored: true,
    });
  } catch (error) {
    return errorResponse(error);
  }
});
