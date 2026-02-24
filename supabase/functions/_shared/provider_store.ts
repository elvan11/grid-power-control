import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { HttpError } from "./http.ts";
import { decryptJson, encryptJson } from "./crypto.ts";
import type { SolisCredentials } from "./solis.ts";

const PROVIDER_TYPE = "soliscloud";

interface StoredSecretPayload {
  apiId: string;
  apiSecret: string;
}

function asNonEmptyString(value: unknown, name: string): string {
  const text = typeof value === "string" ? value.trim() : "";
  if (!text) {
    throw new HttpError(400, `${name} is required`);
  }
  return text;
}

export async function loadStoredSolisCredentials(
  adminClient: SupabaseClient,
  plantId: string,
): Promise<{
  connectionId: string;
  displayName: string;
  credentials: SolisCredentials;
}> {
  const { data: connection, error: connectionError } = await adminClient
    .from("provider_connections")
    .select("id, display_name, config_json")
    .eq("plant_id", plantId)
    .eq("provider_type", PROVIDER_TYPE)
    .maybeSingle();

  if (connectionError) {
    throw new HttpError(
      500,
      "Failed reading provider connection",
      connectionError,
    );
  }
  if (!connection) {
    throw new HttpError(404, "Solis provider connection is not configured");
  }

  const config = (connection.config_json ?? {}) as Record<string, unknown>;
  const inverterSn = asNonEmptyString(config.inverterSn, "inverterSn");
  const stationId = typeof config.stationId === "string"
    ? config.stationId.trim() || undefined
    : undefined;
  const apiBaseUrl = typeof config.apiBaseUrl === "string"
    ? config.apiBaseUrl
    : undefined;

  const configApiId = typeof config.apiId === "string" ? config.apiId : "";
  const configApiSecret = typeof config.apiSecret === "string"
    ? config.apiSecret
    : "";

  const { data: secretRow, error: secretError } = await adminClient
    .from("provider_secrets")
    .select("encrypted_json")
    .eq("plant_id", plantId)
    .eq("provider_type", PROVIDER_TYPE)
    .maybeSingle();

  if (secretError) {
    throw new HttpError(500, "Failed reading provider secret", secretError);
  }

  let apiId = configApiId;
  let apiSecret = configApiSecret;

  if (secretRow) {
    const secret = await decryptJson<StoredSecretPayload>(secretRow.encrypted_json);
    apiId = typeof secret.apiId === "string" ? secret.apiId : apiId;
    apiSecret = typeof secret.apiSecret === "string" ? secret.apiSecret : apiSecret;
  }

  return {
    connectionId: connection.id,
    displayName: connection.display_name,
    credentials: {
      apiId: asNonEmptyString(apiId, "apiId"),
      apiSecret: asNonEmptyString(apiSecret, "apiSecret"),
      inverterSn,
      stationId,
      apiBaseUrl,
    },
  };
}

export async function upsertStoredSolisCredentials(
  adminClient: SupabaseClient,
  input: {
    plantId: string;
    displayName: string;
    inverterSn: string;
    apiId: string;
    apiSecret: string;
    apiBaseUrl?: string;
  },
): Promise<{ connectionId: string; updatedAt: string }> {
  const configJson: Record<string, unknown> = {
    inverterSn: asNonEmptyString(input.inverterSn, "inverterSn"),
    apiId: asNonEmptyString(input.apiId, "apiId"),
    apiSecret: asNonEmptyString(input.apiSecret, "apiSecret"),
  };

  const cleanBaseUrl = input.apiBaseUrl?.trim();
  if (cleanBaseUrl) {
    configJson.apiBaseUrl = cleanBaseUrl;
  }

  const { data: connection, error: connectionError } = await adminClient
    .from("provider_connections")
    .upsert(
      {
        plant_id: input.plantId,
        provider_type: PROVIDER_TYPE,
        display_name: asNonEmptyString(input.displayName, "displayName"),
        config_json: configJson,
      },
      { onConflict: "plant_id,provider_type" },
    )
    .select("id, updated_at")
    .single();

  if (connectionError) {
    throw new HttpError(
      500,
      "Failed upserting provider connection",
      connectionError,
    );
  }

  const encryptedJson = await encryptJson({
    apiId: asNonEmptyString(input.apiId, "apiId"),
    apiSecret: asNonEmptyString(input.apiSecret, "apiSecret"),
  } satisfies StoredSecretPayload);

  const { error: secretError } = await adminClient
    .from("provider_secrets")
    .upsert(
      {
        plant_id: input.plantId,
        provider_type: PROVIDER_TYPE,
        encrypted_json: encryptedJson,
      },
      { onConflict: "plant_id,provider_type" },
    );

  if (secretError) {
    throw new HttpError(500, "Failed upserting provider secret", secretError);
  }

  return { connectionId: connection.id, updatedAt: connection.updated_at };
}

