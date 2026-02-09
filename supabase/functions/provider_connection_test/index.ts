import { createAdminClient, requirePlantRole, requireUser } from "../_shared/auth.ts";
import {
  errorResponse,
  handleOptions,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { loadStoredSolisCredentials } from "../_shared/provider_store.ts";
import { testSolisConnection, type SolisCredentials } from "../_shared/solis.ts";

interface ConnectionTestPayload {
  plantId: string;
  inverterSn?: string;
  apiId?: string;
  apiSecret?: string;
  apiBaseUrl?: string;
}

function hasInlineCredentials(payload: ConnectionTestPayload): boolean {
  return Boolean(
    payload.apiId?.trim() && payload.apiSecret?.trim() && payload.inverterSn?.trim(),
  );
}

function hasAnyInlineCredential(payload: ConnectionTestPayload): boolean {
  return Boolean(
    payload.apiId?.trim() || payload.apiSecret?.trim() || payload.inverterSn?.trim(),
  );
}

function requirePlantId(value: unknown): string {
  const plantId = typeof value === "string" ? value.trim() : "";
  if (!plantId) {
    throw new HttpError(400, "plantId is required");
  }
  return plantId;
}

function buildInlineCredentials(payload: ConnectionTestPayload): SolisCredentials {
  return {
    apiId: payload.apiId!.trim(),
    apiSecret: payload.apiSecret!.trim(),
    inverterSn: payload.inverterSn!.trim(),
    apiBaseUrl: payload.apiBaseUrl?.trim() || undefined,
  };
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
    const body = await readJson<ConnectionTestPayload>(req);
    const plantId = requirePlantId(body.plantId);

    await requirePlantRole(userClient, plantId, ["owner", "admin"]);

    if (hasAnyInlineCredential(body) && !hasInlineCredentials(body)) {
      throw new HttpError(
        400,
        "When testing with inline credentials, apiId, apiSecret, and inverterSn are all required",
      );
    }

    const adminClient = createAdminClient();
    const credentials = hasInlineCredentials(body)
      ? buildInlineCredentials(body)
      : (await loadStoredSolisCredentials(adminClient, plantId)).credentials;

    const result = await testSolisConnection(credentials);

    return jsonResponse({
      ok: result.ok,
      plantId,
      providerType: "soliscloud",
      endpoint: result.endpoint,
      httpStatus: result.httpStatus,
      code: result.code,
      message: result.message,
      attempts: result.attempts,
      durationMs: result.durationMs,
    }, result.ok ? 200 : 502);
  } catch (error) {
    return errorResponse(error);
  }
});
