import { createHmac } from "node:crypto";
import type { PriceQuarter } from "./spot_import.ts";

export const ELPRIS_BASE_URL =
  "https://jwloupeteavfmceuzfqx.supabase.co/functions/v1";
// Same public-client obfuscation secret as ElprisLive; not an authorization credential.
export const ELPRIS_SIGNING_SECRET =
  "elpris-live-poc-minute-signing-v1-2026-05-obfuscation-only";
const areaZones: Record<string, string> = {
  SE1: "Europe/Stockholm",
  SE2: "Europe/Stockholm",
  SE3: "Europe/Stockholm",
  SE4: "Europe/Stockholm",
  NO1: "Europe/Oslo",
  NO2: "Europe/Oslo",
  NO3: "Europe/Oslo",
  NO4: "Europe/Oslo",
  NO5: "Europe/Oslo",
  DK1: "Europe/Copenhagen",
  DK2: "Europe/Copenhagen",
  FI: "Europe/Helsinki",
};
export function sourceDatesForSlots(
  area: string,
  slots: { start: string; end: string }[],
): string[] {
  if (!areaZones[area]) throw new Error("Unsupported price area");
  const format = new Intl.DateTimeFormat("en-CA", {
    timeZone: areaZones[area],
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return [
    ...new Set(
      slots.flatMap((s) => [
        format.format(new Date(s.start)),
        format.format(new Date(Date.parse(s.end) - 1)),
      ]),
    ),
  ].sort();
}
export async function loadElprisPrices(
  area: string,
  date: string,
  options: {
    now: Date;
    secret?: string;
    session?: string;
    baseUrl?: string;
    fetcher?: typeof fetch;
  },
): Promise<PriceQuarter[]> {
  if (!areaZones[area]) throw new Error("Unsupported price area");
  const query = new URLSearchParams({ area, date }).toString();
  const minute = options.now.toISOString().slice(0, 16) + "Z";
  const session = options.session ?? "grid-power-control-backend";
  const signature = createHmac(
    "sha256",
    options.secret ?? ELPRIS_SIGNING_SECRET,
  )
    .update(["GET", "/get-prices", query, minute, session].join("\n"))
    .digest("hex");
  const response = await (options.fetcher ?? fetch)(
    `${options.baseUrl ?? ELPRIS_BASE_URL}/get-prices?${query}`,
    {
      headers: {
        "x-elpris-session": session,
        "x-elpris-utc-minute": minute,
        "x-elpris-signature": signature,
      },
      signal: AbortSignal.timeout(4000),
    },
  );
  if (!response.ok) throw new Error(`ElprisLive HTTP ${response.status}`);
  const payload = await response.json();
  if (
    payload.area !== area ||
    payload.date !== date ||
    !Array.isArray(payload.entries)
  )
    throw new Error("Unexpected ElprisLive response");
  const seen = new Set<number>();
  return payload.entries.map((entry: Record<string, unknown>) => {
    const start = Date.parse(String(entry.time_start)),
      end = Date.parse(String(entry.time_end));
    const price = entry.price_per_kwh;
    if (
      !Number.isFinite(start) ||
      end - start !== 900000 ||
      start % 900000 !== 0 ||
      typeof price !== "number" ||
      !Number.isFinite(price) ||
      seen.has(start)
    )
      throw new Error("Invalid ElprisLive quarter");
    seen.add(start);
    return {
      start: new Date(start).toISOString(),
      end: new Date(end).toISOString(),
      price_per_kwh: price,
    };
  });
}
