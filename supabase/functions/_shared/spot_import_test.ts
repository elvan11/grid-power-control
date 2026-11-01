import { describe, it, expect } from "vitest";
import { planSpotImport, type ImportWork } from "./spot_import.ts";

const now = new Date("2026-10-31T00:00:00Z");
function fixture(): ImportWork {
  return {
    plant_id: "p",
    segment_id: "s",
    local_date: "2026-10-31",
    revision_key: "r",
    price_area: "SE3",
    time_zone: "Europe/Stockholm",
    peak_shaving_w: 6000,
    target_wh: 4500,
    window_start: now.toISOString(),
    window_end: "2026-10-31T02:00:00Z",
    previous_plan: null,
    slots: Array.from({ length: 8 }, (_, i) => ({
      start: new Date(+now + i * 900000).toISOString(),
      end: new Date(+now + (i + 1) * 900000).toISOString(),
      eligible: true,
    })),
  };
}
function prices(work: ImportWork) {
  return work.slots.map((s, i) => ({
    ...s,
    price_per_kwh: [8, 1, 6, 2, -1, 9, 7, 5][i],
  }));
}
describe("spot import planner", () => {
  it("buys 4.5 kWh in three cheapest nonconsecutive quarters at 6 kW", () => {
    const work = fixture();
    const plan = planSpotImport(work, prices(work), now);
    expect(plan.status).toBe("ready");
    expect(plan.slots.filter((s) => s.selected).map((s) => s.start)).toEqual([
      work.slots[1].start,
      work.slots[3].start,
      work.slots[4].start,
    ]);
    expect(plan.slots.reduce((n, s) => n + s.energy_wh, 0)).toBe(4500);
  });
  it("rounds targets up and breaks price ties chronologically", () => {
    const work = fixture();
    work.target_wh = 4000;
    const plan = planSpotImport(
      work,
      prices(work).map((s) => ({ ...s, price_per_kwh: 1 })),
      now,
    );
    expect(plan.slots.filter((s) => s.selected).map((s) => s.start)).toEqual(
      work.slots.slice(0, 3).map((s) => s.start),
    );
  });
  it("waits rather than optimizes an incomplete window", () => {
    const work = fixture();
    expect(planSpotImport(work, prices(work).slice(1), now).status).toBe(
      "pending_prices",
    );
  });
  it("excludes higher-priority quarters", () => {
    const work = fixture();
    work.slots[4].eligible = false;
    expect(planSpotImport(work, prices(work), now).slots[4].selected).toBe(
      false,
    );
  });
  it("late prices use only future full quarters and report a shortage", () => {
    const work = fixture();
    const plan = planSpotImport(
      work,
      prices(work),
      new Date(+now + 7 * 900000 + 1),
    );
    expect(plan.status).toBe("insufficient_capacity");
    expect(plan.slots.some((s) => s.selected)).toBe(false);
  });
  it("preserves locked choices on restart despite different prices", () => {
    const work = fixture();
    work.previous_plan = planSpotImport(work, prices(work), now);
    expect(
      planSpotImport(
        work,
        prices(work).map((s) => ({ ...s, price_per_kwh: -s.price_per_kwh })),
        new Date(+now + 1),
      ).slots,
    ).toEqual(work.previous_plan.slots);
  });
  it("edits retain elapsed allocation and do not buy missed quarters again", () => {
    const work = fixture();
    work.previous_plan = planSpotImport(work, prices(work), now);
    work.revision_key = "r2";
    const plan = planSpotImport(
      work,
      prices(work),
      new Date(+now + 4 * 900000 + 1),
    );
    expect(plan.slots.filter((s) => s.selected)).toHaveLength(3);
    expect(
      plan.slots.filter(
        (s) => s.selected && Date.parse(s.start) < +now + 4 * 900000 + 1,
      ),
    ).toHaveLength(3);
  });
  it("rejects malformed and duplicate price intervals", () => {
    const work = fixture();
    expect(
      planSpotImport(work, [...prices(work), prices(work)[0]], now).status,
    ).toBe("pending_prices");
    expect(
      planSpotImport(
        work,
        prices(work).map((s) => ({ ...s, price_per_kwh: NaN })),
        now,
      ).status,
    ).toBe("pending_prices");
  });
});
