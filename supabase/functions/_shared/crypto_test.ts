import { afterEach, it, expect, vi } from "vitest";
import { decryptJson, encryptJson } from "./crypto.ts";
afterEach(() => vi.unstubAllGlobals());
it("round trips provider secrets with a fresh IV and rejects ciphertext tampering", async () => {
  vi.stubGlobal("Deno", {
    env: { get: () => btoa("12345678901234567890123456789012") },
  });
  const first = await encryptJson({ secret: "private" });
  const second = await encryptJson({ secret: "private" });
  expect(first).not.toBe(second);
  expect(await decryptJson(first)).toEqual({ secret: "private" });
  const envelope = JSON.parse(first);
  const bytes = Uint8Array.from(atob(envelope.data), (c) => c.charCodeAt(0));
  bytes[0] ^= 1;
  envelope.data = btoa(String.fromCharCode(...bytes));
  await expect(decryptJson(JSON.stringify(envelope))).rejects.toThrow();
});
