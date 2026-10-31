import { loadElprisPrices, sourceDatesForSlots } from "./elpris_prices.ts";
import {
  type ImportWork,
  type PriceQuarter,
  planSpotImport,
} from "./spot_import.ts";

interface AdminClient {
  rpc: (
    name: string,
    args?: Record<string, unknown>,
  ) => PromiseLike<{ data: any; error: any }>;
  from: (table: string) => any;
}
/** Preparation does not claim control work and never sends inverter commands. */
export async function prepareSpotImports(
  client: AdminClient,
  now: Date,
  getEnv: (name: string) => string | undefined,
  loadPrices:
    | ((area: string, date: string) => Promise<PriceQuarter[]>)
    | undefined = undefined,
): Promise<void> {
  const { data, error } = await client.rpc("get_spot_import_work", {
    p_at: now.toISOString(),
  });
  if (error) throw new Error(`Import work lookup failed: ${error.message}`);
  const requests = new Map<string, Promise<PriceQuarter[]>>();
  async function prices(area: string, date: string) {
    const key = `${area}:${date}`;
    if (!requests.has(key))
      requests.set(
        key,
        (async () => {
          const { data: cached } = await client
            .from("spot_price_cache")
            .select("entries,fetched_at")
            .eq("area", area)
            .eq("source_date", date)
            .maybeSingle();
          if (cached && +now - Date.parse(cached.fetched_at) < 300000)
            return cached.entries as PriceQuarter[];
          let entries: PriceQuarter[];
          try {
            entries = await (loadPrices
              ? loadPrices(area, date)
              : loadElprisPrices(area, date, {
                  now,
                  secret: getEnv("ELPRIS_SIGNING_SECRET"),
                  baseUrl: getEnv("ELPRIS_BASE_URL"),
                }));
          } catch (error) {
            // Published prices are tied to their delivery date; their age does
            // not make an already covered window unusable during an outage.
            if (cached?.entries?.length)
              return cached.entries as PriceQuarter[];
            throw error;
          }
          const { error: cacheError } = await client
            .from("spot_price_cache")
            .upsert(
              {
                area,
                source_date: date,
                entries,
                fetched_at: now.toISOString(),
              },
              { onConflict: "area,source_date" },
            );
          if (cacheError)
            console.error("spot_price_cache_write_failed", cacheError.message);
          return entries;
        })(),
      );
    return requests.get(key)!;
  }
  // Bounded workers avoid one slow price area preventing the others from preparing.
  const work = (data ?? []) as ImportWork[];
  let index = 0;
  async function worker() {
    while (index < work.length) {
      const item = work[index++];
      const previous = item.previous_plan;
      if (
        previous?.revision_key === item.revision_key &&
        ((previous.status !== "pending_prices" &&
          Date.parse(item.window_start) < +now) ||
          Date.parse(previous.refresh_after) > +now)
      )
        continue;
      try {
        let entries: PriceQuarter[] = [];
        try {
          entries = (
            await Promise.all(
              sourceDatesForSlots(
                item.price_area,
                item.slots.filter((s) => Date.parse(s.start) >= +now),
              ).map((date) => prices(item.price_area, date)),
            )
          ).flat();
        } catch (error) {
          console.error(
            "spot_price_fetch_failed",
            item.price_area,
            error instanceof Error ? error.message : "fetch failed",
          );
        }
        const plan = planSpotImport(item, entries, now);
        const { error: saveError } = await client.rpc("save_spot_import_plan", {
          p_plan: plan,
        });
        if (saveError)
          console.error(
            "spot_plan_save_failed",
            item.plant_id,
            saveError.message,
          );
      } catch (error) {
        console.error(
          "spot_plan_preparation_failed",
          item.plant_id,
          error instanceof Error ? error.message : "preparation failed",
        );
      }
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(3, work.length) }, () => worker()),
  );
}
