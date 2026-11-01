import { it, expect } from "vitest";
import { prepareSpotImports } from "./spot_preparation.ts";

it("shares cached area/date fetches, scans independently of due plants and isolates failed areas", async () => {
  const now = new Date("2026-10-31T00:00Z");
  const calls: string[] = [];
  const saved: any[] = [];
  const work = (id: string, area: string) => ({
    plant_id: id,
    segment_id: id,
    local_date: "2026-10-31",
    revision_key: "r",
    price_area: area,
    time_zone: "Europe/Stockholm",
    peak_shaving_w: 6000,
    target_wh: 1500,
    window_start: now.toISOString(),
    window_end: "2026-10-31T00:15Z",
    previous_plan: null,
    slots: [
      {
        start: now.toISOString(),
        end: "2026-10-31T00:15:00.000Z",
        eligible: true,
      },
    ],
  });
  const client = {
    rpc: async (name: string, args?: any) => {
      calls.push(name);
      if (name === "get_spot_import_work")
        return {
          data: [work("1", "SE3"), work("2", "SE3"), work("3", "SE4")],
          error: null,
        };
      saved.push(args.p_plan);
      return { data: true, error: null };
    },
    from: () => ({
      select: () => ({
        eq: () => ({
          eq: () => ({
            maybeSingle: async () => ({ data: null, error: null }),
          }),
        }),
      }),
      upsert: async () => ({ error: null }),
    }),
  };
  let fetches = 0;
  await prepareSpotImports(
    client,
    now,
    () => undefined,
    async (area) => {
      fetches++;
      if (area === "SE4") throw new Error("unavailable");
      return [
        {
          start: now.toISOString(),
          end: "2026-10-31T00:15:00.000Z",
          price_per_kwh: 1,
        },
      ];
    },
  );
  expect(fetches).toBe(2);
  expect(calls[0]).toBe("get_spot_import_work");
  expect(
    saved
      .sort((a, b) => a.plant_id.localeCompare(b.plant_id))
      .map((p) => p.status),
  ).toEqual(["ready", "ready", "pending_prices"]);
});

it("keeps published cached prices when refreshing the upstream service fails", async () => {
  const now = new Date("2026-10-31T00:00Z");
  const entries = [
    {
      start: now.toISOString(),
      end: "2026-10-31T00:15:00.000Z",
      price_per_kwh: 1,
    },
  ];
  let saved: any;
  const work = {
    plant_id: "p",
    segment_id: "s",
    local_date: "2026-10-31",
    revision_key: "r",
    price_area: "SE3",
    time_zone: "Europe/Stockholm",
    peak_shaving_w: 6000,
    target_wh: 1500,
    window_start: now.toISOString(),
    window_end: entries[0].end,
    previous_plan: null,
    slots: [{ ...entries[0], eligible: true }],
  };
  const client = {
    rpc: async (name: string, args?: any) => {
      if (name === "get_spot_import_work") return { data: [work], error: null };
      saved = args.p_plan;
      return { data: true, error: null };
    },
    from: () => ({
      select: () => ({
        eq: () => ({
          eq: () => ({
            maybeSingle: async () => ({
              data: { entries, fetched_at: "2026-10-30T23:00Z" },
              error: null,
            }),
          }),
        }),
      }),
      upsert: async () => ({ error: null }),
    }),
  };
  await prepareSpotImports(
    client,
    now,
    () => undefined,
    async () => {
      throw new Error("offline");
    },
  );
  expect(saved.status).toBe("ready");
  expect(saved.slots[0].selected).toBe(true);
});
