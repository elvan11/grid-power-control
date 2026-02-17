import { createHash, createHmac } from "node:crypto";
import { HttpError } from "./http.ts";

const DEFAULT_BASE_URL = "https://www.soliscloud.com:13333";
const CONTENT_TYPE = "application/json;charset=UTF-8";
const RETRY_DELAYS_MS = [0, 2000, 5000, 10000];

export const SOLIS_CIDS = {
  PEAK_SHAVING_W: 5035,
  ALLOW_GRID_CHARGING: 5041,
} as const;

interface SolisEnvelope {
  success?: boolean;
  code?: string | number;
  msg?: string;
  data?: unknown;
  [key: string]: unknown;
}

export interface SolisCredentials {
  apiId: string;
  apiSecret: string;
  inverterSn: string;
  apiBaseUrl?: string;
}

export interface SolisRequestResult {
  ok: boolean;
  endpoint: string;
  httpStatus: number;
  code: string | null;
  message: string;
  durationMs: number;
  attempts: number;
  payload: Record<string, unknown>;
  responseData?: unknown;
}

export interface SolisApplyResult {
  ok: boolean;
  steps: SolisRequestResult[];
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function normalizeCode(code: string | number | undefined): string | null {
  if (code === undefined || code === null) {
    return null;
  }
  return String(code);
}

function isSuccess(status: number, envelope: SolisEnvelope | null): boolean {
  if (status < 200 || status >= 300 || !envelope) {
    return false;
  }
  const code = normalizeCode(envelope.code);
  return code === "0" && envelope.success !== false;
}

function isTransient(status: number, code: string | null): boolean {
  return status === 0 || status === 429 || status >= 500 || code === "429";
}

function requiredString(value: unknown, name: string): string {
  const text = typeof value === "string" ? value.trim() : "";
  if (!text) {
    throw new HttpError(400, `${name} is required`);
  }
  return text;
}

function resolveBaseUrl(value?: string): string {
  const configured = value?.trim() || Deno.env.get("SOLIS_API_BASE_URL") || "";
  const url = (configured || DEFAULT_BASE_URL).trim().replace(/\/+$/, "");
  if (!url.startsWith("https://")) {
    throw new HttpError(400, "Solis API URL must start with https://");
  }
  return url;
}

function parseBound(name: string, fallback: number): number {
  const raw = Deno.env.get(name);
  if (!raw) {
    return fallback;
  }
  const value = Number(raw);
  if (!Number.isFinite(value)) {
    throw new HttpError(500, `${name} must be numeric`);
  }
  return Math.trunc(value);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function signRequest(
  apiId: string,
  apiSecret: string,
  canonicalPath: string,
  body: string,
): Record<string, string> {
  const contentMd5 = createHash("md5").update(body).digest("base64");
  const date = new Date().toUTCString();
  const canonical = [
    "POST",
    contentMd5,
    CONTENT_TYPE,
    date,
    canonicalPath,
  ].join("\n");
  const signature = createHmac("sha1", apiSecret).update(canonical).digest(
    "base64",
  );

  return {
    "Content-Type": CONTENT_TYPE,
    "Content-MD5": contentMd5,
    Date: date,
    Authorization: `API ${apiId}:${signature}`,
  };
}

async function requestWithRetry(
  credentials: SolisCredentials,
  endpoint: string,
  payload: Record<string, unknown>,
): Promise<SolisRequestResult> {
  let attempts = 0;
  let last: SolisRequestResult | null = null;
  const baseUrl = resolveBaseUrl(credentials.apiBaseUrl);

  for (const delayMs of RETRY_DELAYS_MS) {
    attempts += 1;
    if (delayMs > 0) {
      await sleep(delayMs);
    }

    const started = Date.now();
    const body = JSON.stringify(payload);
    const url = `${baseUrl}${endpoint}`;
    const headers = signRequest(
      requiredString(credentials.apiId, "apiId"),
      requiredString(credentials.apiSecret, "apiSecret"),
      endpoint,
      body,
    );

    let responseText = "";
    let status = 0;
    let envelope: SolisEnvelope | null = null;

    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 30_000);
      const response = await fetch(url, {
        method: "POST",
        headers,
        body,
        signal: controller.signal,
      });
      clearTimeout(timeout);

      status = response.status;
      responseText = await response.text();
      envelope = responseText ? JSON.parse(responseText) as SolisEnvelope : null;
    } catch {
      status = 0;
      envelope = null;
    }

    const code = normalizeCode(envelope?.code);
    const ok = isSuccess(status, envelope);
    const result: SolisRequestResult = {
      ok,
      endpoint,
      httpStatus: status,
      code,
      message: envelope?.msg ?? (ok ? "success" : "Solis request failed"),
      durationMs: Date.now() - started,
      attempts,
      payload,
      responseData: envelope?.data ?? (responseText || null),
    };

    last = result;
    if (ok || !isTransient(status, code)) {
      return result;
    }
  }

  if (!last) {
    throw new HttpError(500, "Solis request failed before execution");
  }
  return last;
}

export function validatePeakShavingW(value: number): number {
  const minW = parseBound("SOLIS_PEAK_SHAVING_MIN_W", 0);
  const maxW = parseBound("SOLIS_PEAK_SHAVING_MAX_W", 10_000);

  if (!Number.isFinite(value)) {
    throw new HttpError(400, "peak_shaving_w must be numeric");
  }
  const watts = Math.trunc(value);
  if (watts % 100 !== 0) {
    throw new HttpError(400, "peak_shaving_w must be in 100W steps");
  }
  if (watts < minW || watts > maxW) {
    throw new HttpError(
      400,
      `peak_shaving_w must be within ${minW}..${maxW} W`,
    );
  }
  return watts;
}

function normalizeYuanzhi(value: unknown): string | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(Math.trunc(value));
  }
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  const numeric = Number(trimmed);
  if (Number.isFinite(numeric)) {
    return String(Math.trunc(numeric));
  }
  return trimmed;
}

function extractYuanzhi(step: SolisRequestResult): string | null {
  const data = asRecord(step.responseData);
  return normalizeYuanzhi(data?.yuanzhi);
}

function missingYuanzhiStep(
  inverterSn: string,
  cid: number,
  value: string,
  preRead: SolisRequestResult,
): SolisRequestResult {
  return {
    ok: false,
    endpoint: "/v2/api/control",
    httpStatus: 0,
    code: "YUANZHI_MISSING",
    message: `Solis atRead for CID ${cid} returned no yuanzhi`,
    durationMs: 0,
    attempts: 1,
    payload: {
      inverterSn,
      cid,
      value,
    },
    responseData: preRead.responseData,
  };
}

export async function testSolisConnection(
  credentials: SolisCredentials,
): Promise<SolisRequestResult> {
  return await requestWithRetry(credentials, "/v2/api/atRead", {
    inverterSn: requiredString(credentials.inverterSn, "inverterSn"),
    cid: SOLIS_CIDS.PEAK_SHAVING_W,
  });
}

export async function applySolisControls(
  credentials: SolisCredentials,
  peakShavingW: number,
  gridChargingAllowed: boolean,
): Promise<SolisApplyResult> {
  const boundedPeak = validatePeakShavingW(peakShavingW);
  const inverterSn = requiredString(credentials.inverterSn, "inverterSn");
  const peakValue = String(boundedPeak);
  const chargingValue = gridChargingAllowed ? "1" : "0";

  const peakPreRead = await requestWithRetry(credentials, "/v2/api/atRead", {
    inverterSn,
    cid: SOLIS_CIDS.PEAK_SHAVING_W,
  });

  if (!peakPreRead.ok) {
    return { ok: false, steps: [peakPreRead] };
  }

  const peakYuanzhi = extractYuanzhi(peakPreRead);
  if (!peakYuanzhi) {
    return {
      ok: false,
      steps: [
        peakPreRead,
        missingYuanzhiStep(
          inverterSn,
          SOLIS_CIDS.PEAK_SHAVING_W,
          peakValue,
          peakPreRead,
        ),
      ],
    };
  }

  const first = await requestWithRetry(credentials, "/v2/api/control", {
    inverterSn,
    cid: SOLIS_CIDS.PEAK_SHAVING_W,
    value: peakValue,
    yuanzhi: peakYuanzhi,
  });

  if (!first.ok) {
    return { ok: false, steps: [peakPreRead, first] };
  }

  // Solis recommends max 2 requests/second per endpoint.
  await sleep(550);

  const preRead = await requestWithRetry(credentials, "/v2/api/atRead", {
    inverterSn,
    cid: SOLIS_CIDS.ALLOW_GRID_CHARGING,
  });

  if (!preRead.ok) {
    return { ok: false, steps: [peakPreRead, first, preRead] };
  }

  const yuanzhi = extractYuanzhi(preRead);
  if (!yuanzhi) {
    return {
      ok: false,
      steps: [
        peakPreRead,
        first,
        preRead,
        missingYuanzhiStep(
          inverterSn,
          SOLIS_CIDS.ALLOW_GRID_CHARGING,
          chargingValue,
          preRead,
        ),
      ],
    };
  }

  const second = await requestWithRetry(credentials, "/v2/api/control", {
    inverterSn,
    cid: SOLIS_CIDS.ALLOW_GRID_CHARGING,
    value: chargingValue,
    yuanzhi,
  });

  return {
    ok: second.ok,
    steps: [peakPreRead, first, preRead, second],
  };
}
