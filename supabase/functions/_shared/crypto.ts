import { HttpError } from "./http.ts";

interface EncryptedPayload {
  v: number;
  alg: "AES-GCM";
  iv: string;
  data: string;
}

let cachedKey: CryptoKey | null = null;
let cachedKeySeed: string | null = null;

function toBase64(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes));
}

function fromBase64(value: string): Uint8Array {
  try {
    return Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
  } catch {
    throw new HttpError(500, "Invalid base64 encoding");
  }
}

async function getAesKey(): Promise<CryptoKey> {
  const raw = Deno.env.get("PROVIDER_SECRETS_ENCRYPTION_KEY");
  if (!raw) {
    throw new HttpError(
      500,
      "Missing PROVIDER_SECRETS_ENCRYPTION_KEY environment variable",
    );
  }

  if (cachedKey && cachedKeySeed === raw) {
    return cachedKey;
  }

  const keyBytes = fromBase64(raw);
  if (![16, 24, 32].includes(keyBytes.length)) {
    throw new HttpError(
      500,
      "PROVIDER_SECRETS_ENCRYPTION_KEY must decode to 16, 24, or 32 bytes",
    );
  }

  cachedKey = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  );
  cachedKeySeed = raw;
  return cachedKey;
}

export async function encryptJson(payload: unknown): Promise<string> {
  const key = await getAesKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const plainBytes = new TextEncoder().encode(JSON.stringify(payload));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    plainBytes,
  );

  const envelope: EncryptedPayload = {
    v: 1,
    alg: "AES-GCM",
    iv: toBase64(iv),
    data: toBase64(new Uint8Array(encrypted)),
  };

  return JSON.stringify(envelope);
}

export async function decryptJson<T>(cipherText: string): Promise<T> {
  let envelope: EncryptedPayload;
  try {
    envelope = JSON.parse(cipherText) as EncryptedPayload;
  } catch {
    throw new HttpError(500, "Stored provider secret payload is not valid JSON");
  }

  if (envelope.v !== 1 || envelope.alg !== "AES-GCM") {
    throw new HttpError(500, "Unsupported provider secret format");
  }

  const key = await getAesKey();
  const iv = fromBase64(envelope.iv);
  const data = fromBase64(envelope.data);

  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    key,
    data,
  );

  const plain = new TextDecoder().decode(decrypted);
  return JSON.parse(plain) as T;
}

