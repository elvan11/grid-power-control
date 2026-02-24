import { createHash, createHmac } from "node:crypto";
import { HttpError } from "./http.ts";

const DEFAULT_BASE_URL = "https://www.soliscloud.com:13333";
const CONTENT_TYPE = "application/json;charset=UTF-8";
const RETRY_DELAYS_MS = [0, 2000, 5000, 10000];
const CONTROL_VERIFY_POLL_DELAYS_MS = [0, 1500, 3000];
const CID_PROCEDURE_RETRY_DELAYS_MS = [0, 2000, 5000];
const DEFAULT_TRANSIENT_CODES = ["429", "B0600"];

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
  stationId?: string;
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

export interface SolisBatterySocResult {
  batteryPercentage: number;
  stationId: string;
  steps: SolisRequestResult[];
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function findFieldByKey(
  value: unknown,
  key: string,
): unknown | undefined {
  const record = asRecord(value);
  if (record) {
    if (Object.hasOwn(record, key)) {
      return record[key];
    }
    for (const child of Object.values(record)) {
      const nested = findFieldByKey(child, key);
      if (nested !== undefined) {
        return nested;
      }
    }
    return undefined;
  }

  if (Array.isArray(value)) {
    for (const entry of value) {
      const nested = findFieldByKey(entry, key);
      if (nested !== undefined) {
        return nested;
      }
    }
  }

  return undefined;
}

function normalizeCode(code: string | number | undefined): string | null {
  if (code === undefined || code === null) {
    return null;
  }
  return String(code);
}

function normalizeStationId(value: unknown): string | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(Math.trunc(value));
  }
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizePercentage(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  const withoutPercent = trimmed.endsWith("%")
    ? trimmed.slice(0, trimmed.length - 1).trim()
    : trimmed;
  const parsed = Number(withoutPercent);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeRetryCode(code: string | null): string | null {
  if (!code) {
    return null;
  }
  const normalized = code.trim().toUpperCase();
  return normalized || null;
}

function isSuccess(status: number, envelope: SolisEnvelope | null): boolean {
  if (status < 200 || status >= 300 || !envelope) {
    return false;
  }
  const code = normalizeCode(envelope.code);
  return code === "0" && envelope.success !== false;
}

function isTransient(status: number, code: string | null): boolean {
  const normalizedCode = normalizeRetryCode(code);
  return status === 0 ||
    status === 429 ||
    status >= 500 ||
    (normalizedCode !== null && transientSolisCodes.has(normalizedCode));
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

function parseTransientCodes(
  name: string,
  fallback: readonly string[],
): Set<string> {
  const raw = Deno.env.get(name);
  const list = (raw ?? "").split(",")
    .map((code) => code.trim().toUpperCase())
    .filter((code) => code.length > 0);
  const resolved = list.length > 0 ? list : [...fallback];
  return new Set(resolved);
}

const transientSolisCodes = parseTransientCodes(
  "SOLIS_TRANSIENT_CODES",
  DEFAULT_TRANSIENT_CODES,
);

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

function extractReadValue(step: SolisRequestResult): string | null {
  const data = asRecord(step.responseData);
  const fromMsg = normalizeYuanzhi(data?.msg);
  if (fromMsg !== null) {
    return fromMsg;
  }
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

function annotateStep(
  step: SolisRequestResult,
  fields: Record<string, unknown>,
): SolisRequestResult {
  return {
    ...step,
    payload: {
      ...step.payload,
      ...fields,
    },
  };
}

function verificationMismatchStep(
  inverterSn: string,
  cid: number,
  expectedValue: string,
  actualValue: string | null,
  rawMsgValue: string | null,
  rawYuanzhiValue: string | null,
): SolisRequestResult {
  return {
    ok: false,
    endpoint: "/v2/api/atRead",
    httpStatus: 0,
    code: "VERIFY_MISMATCH",
    message: actualValue === null
      ? `Solis verify read for CID ${cid} returned no value`
      : `Solis verify mismatch for CID ${cid}: expected ${expectedValue}, got ${actualValue}`,
    durationMs: 0,
    attempts: 1,
    payload: {
      inverterSn,
      cid,
      value: expectedValue,
      actualValue,
      rawMsgValue,
      rawYuanzhiValue,
    },
    responseData: {
      expectedValue,
      actualValue,
      rawMsgValue,
      rawYuanzhiValue,
    },
  };
}

function procedureFailedStep(
  inverterSn: string,
  cid: number,
  value: string,
  procedureAttempts: number,
): SolisRequestResult {
  return {
    ok: false,
    endpoint: "/v2/api/control",
    httpStatus: 0,
    code: "CID_APPLY_FAILED",
    message:
      `Solis apply for CID ${cid} failed after ${procedureAttempts} procedure attempts`,
    durationMs: 0,
    attempts: 1,
    payload: {
      inverterSn,
      cid,
      value,
      procedureAttempts,
    },
    responseData: null,
  };
}

interface VerifyCidResult {
  ok: boolean;
  steps: SolisRequestResult[];
}

async function verifyCidTargetValue(
  credentials: SolisCredentials,
  inverterSn: string,
  cid: number,
  expectedValue: string,
  procedureAttempt: number,
): Promise<VerifyCidResult> {
  const steps: SolisRequestResult[] = [];
  let lastActualValue: string | null = null;
  let lastRawMsgValue: string | null = null;
  let lastRawYuanzhiValue: string | null = null;

  for (let verifyAttempt = 1; verifyAttempt <= CONTROL_VERIFY_POLL_DELAYS_MS.length; verifyAttempt += 1) {
    const delayMs = CONTROL_VERIFY_POLL_DELAYS_MS[verifyAttempt - 1] ?? 0;
    if (delayMs > 0) {
      await sleep(delayMs);
    }

    const verifyRead = annotateStep(
      await requestWithRetry(credentials, "/v2/api/atRead", {
        inverterSn,
        cid,
      }),
      {
        procedureAttempt,
        verifyAttempt,
      },
    );
    steps.push(verifyRead);

    if (!verifyRead.ok) {
      continue;
    }

    const data = asRecord(verifyRead.responseData);
    const rawMsgValue = normalizeYuanzhi(data?.msg);
    const rawYuanzhiValue = normalizeYuanzhi(data?.yuanzhi);
    const actualValue = extractReadValue(verifyRead);
    lastActualValue = actualValue;
    lastRawMsgValue = rawMsgValue;
    lastRawYuanzhiValue = rawYuanzhiValue;
    if (actualValue === expectedValue) {
      return { ok: true, steps };
    }
  }

  steps.push(
    annotateStep(
      verificationMismatchStep(
        inverterSn,
        cid,
        expectedValue,
        lastActualValue,
        lastRawMsgValue,
        lastRawYuanzhiValue,
      ),
      {
        procedureAttempt,
        verifyAttempt: CONTROL_VERIFY_POLL_DELAYS_MS.length + 1,
      },
    ),
  );

  return { ok: false, steps };
}

interface CidApplyResult {
  ok: boolean;
  steps: SolisRequestResult[];
}

async function applyCidWithVerification(
  credentials: SolisCredentials,
  inverterSn: string,
  cid: number,
  targetValue: string,
): Promise<CidApplyResult> {
  const steps: SolisRequestResult[] = [];

  for (
    let procedureAttempt = 1;
    procedureAttempt <= CID_PROCEDURE_RETRY_DELAYS_MS.length;
    procedureAttempt += 1
  ) {
    const delayMs = CID_PROCEDURE_RETRY_DELAYS_MS[procedureAttempt - 1] ?? 0;
    if (delayMs > 0) {
      await sleep(delayMs);
    }

    const preRead = annotateStep(
      await requestWithRetry(credentials, "/v2/api/atRead", {
        inverterSn,
        cid,
      }),
      {
        procedureAttempt,
      },
    );
    steps.push(preRead);

    if (!preRead.ok) {
      continue;
    }

    const yuanzhi = extractYuanzhi(preRead);
    if (!yuanzhi) {
      steps.push(
        annotateStep(missingYuanzhiStep(inverterSn, cid, targetValue, preRead), {
          procedureAttempt,
        }),
      );
      continue;
    }

    const writeStep = annotateStep(
      await requestWithRetry(credentials, "/v2/api/control", {
        inverterSn,
        cid,
        value: targetValue,
        yuanzhi,
      }),
      {
        procedureAttempt,
      },
    );
    steps.push(writeStep);
    if (!writeStep.ok) {
      continue;
    }

    const verify = await verifyCidTargetValue(
      credentials,
      inverterSn,
      cid,
      targetValue,
      procedureAttempt,
    );
    steps.push(...verify.steps);
    if (verify.ok) {
      return { ok: true, steps };
    }
  }

  steps.push(
    procedureFailedStep(
      inverterSn,
      cid,
      targetValue,
      CID_PROCEDURE_RETRY_DELAYS_MS.length,
    ),
  );
  return { ok: false, steps };
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

  const peakApply = await applyCidWithVerification(
    credentials,
    inverterSn,
    SOLIS_CIDS.PEAK_SHAVING_W,
    peakValue,
  );
  if (!peakApply.ok) {
    return { ok: false, steps: peakApply.steps };
  }

  const gridApply = await applyCidWithVerification(
    credentials,
    inverterSn,
    SOLIS_CIDS.ALLOW_GRID_CHARGING,
    chargingValue,
  );
  return {
    ok: gridApply.ok,
    steps: [...peakApply.steps, ...gridApply.steps],
  };
}

function resolveStationIdFromList(
  userStationListStep: SolisRequestResult,
  inverterSn: string,
): string | null {
  const data = asRecord(userStationListStep.responseData);
  const page = asRecord(data?.page);
  const records = Array.isArray(page?.records) ? page.records : [];
  if (records.length === 0) {
    return null;
  }

  let firstStationId: string | null = null;
  for (const row of records) {
    const record = asRecord(row);
    if (!record) {
      continue;
    }
    const stationId = normalizeStationId(record.id);
    if (!stationId) {
      continue;
    }
    if (firstStationId === null) {
      firstStationId = stationId;
    }
    const stationSn = typeof record.sno === "string" ? record.sno.trim() : "";
    if (stationSn && stationSn === inverterSn) {
      return stationId;
    }
  }

  return firstStationId;
}

function extractBatteryPercentage(stationDetailStep: SolisRequestResult): number | null {
  const data = asRecord(stationDetailStep.responseData);
  const direct = normalizePercentage(
    findFieldByKey(data, "batteryPercentage"),
  );
  if (direct !== null) {
    return direct;
  }
  return normalizePercentage(findFieldByKey(data, "batteryCapacitySoc"));
}

export async function readSolisBatterySoc(
  credentials: SolisCredentials,
): Promise<SolisBatterySocResult> {
  const inverterSn = requiredString(credentials.inverterSn, "inverterSn");
  const steps: SolisRequestResult[] = [];

  let stationId = normalizeStationId(credentials.stationId);
  if (!stationId) {
    const stationList = await requestWithRetry(
      credentials,
      "/v1/api/userStationList",
      {
        pageNo: 1,
        pageSize: 100,
        state: 1,
      },
    );
    steps.push(stationList);

    if (!stationList.ok) {
      throw new HttpError(
        502,
        `Failed to load Solis stations: ${stationList.message}`,
      );
    }

    stationId = resolveStationIdFromList(stationList, inverterSn);
    if (!stationId) {
      throw new HttpError(404, "No enabled Solis station found");
    }
  }

  const stationDetail = await requestWithRetry(
    credentials,
    "/v1/api/stationDetail",
    {
      id: stationId,
    },
  );
  steps.push(stationDetail);

  if (!stationDetail.ok) {
    throw new HttpError(
      502,
      `Solis station detail failed: ${stationDetail.message}`,
    );
  }

  const batteryPercentage = extractBatteryPercentage(stationDetail);
  if (batteryPercentage === null) {
    throw new HttpError(404, "Solis station detail did not include battery percentage");
  }

  return {
    batteryPercentage,
    stationId,
    steps,
  };
}
