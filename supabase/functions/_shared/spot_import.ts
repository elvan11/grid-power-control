/** Nominal allocation only: selected quarters do not imply metered delivery. */
export interface CandidateQuarter {
  start: string;
  end: string;
  eligible: boolean;
}
export interface PriceQuarter {
  start: string;
  end: string;
  price_per_kwh: number;
}
export interface PlannedQuarter extends PriceQuarter {
  selected: boolean;
  energy_wh: number;
}
export interface ImportPlan {
  plant_id: string;
  segment_id: string;
  local_date: string;
  revision_key: string;
  price_area: string;
  peak_shaving_w: number;
  target_wh: number;
  window_start: string;
  window_end: string;
  status: "ready" | "pending_prices" | "insufficient_capacity";
  slots: PlannedQuarter[];
  prepared_at: string;
  refresh_after: string;
}
export interface ImportWork extends Omit<
  ImportPlan,
  "status" | "slots" | "prepared_at" | "refresh_after"
> {
  time_zone: string;
  slots: CandidateQuarter[];
  previous_plan: ImportPlan | null;
}
const QUARTER_MS = 900_000;
export function planSpotImport(
  work: ImportWork,
  prices: PriceQuarter[],
  now: Date,
): ImportPlan {
  if (
    !Number.isInteger(work.target_wh) ||
    work.target_wh <= 0 ||
    work.peak_shaving_w <= 0 ||
    work.peak_shaving_w % 100 !== 0
  )
    throw new Error("Invalid import target or power");
  const previous = work.previous_plan;
  if (
    previous &&
    previous.revision_key === work.revision_key &&
    previous.status !== "pending_prices" &&
    Date.parse(work.window_start) < +now
  )
    return previous;
  const elapsed =
    previous?.slots.filter((s) => s.selected && Date.parse(s.start) < +now) ??
    [];
  const priceMap = new Map<string, number>();
  let valid = true;
  for (const p of prices) {
    if (
      !Number.isFinite(p.price_per_kwh) ||
      Date.parse(p.end) - Date.parse(p.start) !== QUARTER_MS ||
      !Number.isFinite(Date.parse(p.start))
    ) {
      valid = false;
      break;
    }
    const key = Date.parse(p.start).toString();
    if (priceMap.has(key)) {
      valid = false;
      break;
    }
    priceMap.set(key, p.price_per_kwh);
  }
  const future = work.slots.filter((s) => Date.parse(s.start) >= +now);
  const covered =
    valid && future.every((s) => priceMap.has(Date.parse(s.start).toString()));
  const remaining = Math.max(
    0,
    work.target_wh - elapsed.reduce((n, s) => n + s.energy_wh, 0),
  );
  const required = Math.ceil((remaining * 4) / work.peak_shaving_w);
  const choices = covered
    ? future
        .filter((s) => s.eligible)
        .sort(
          (a, b) =>
            priceMap.get(Date.parse(a.start).toString())! -
              priceMap.get(Date.parse(b.start).toString())! ||
            Date.parse(a.start) - Date.parse(b.start),
        )
        .slice(0, required)
    : [];
  const selected = new Set(choices.map((s) => Date.parse(s.start)));
  const elapsedByStart = new Map(elapsed.map((s) => [Date.parse(s.start), s]));
  const slots: PlannedQuarter[] = work.slots.map(
    (s) =>
      elapsedByStart.get(Date.parse(s.start)) ?? {
        start: s.start,
        end: s.end,
        price_per_kwh: priceMap.get(Date.parse(s.start).toString()) ?? 0,
        selected: selected.has(Date.parse(s.start)),
        energy_wh: selected.has(Date.parse(s.start))
          ? work.peak_shaving_w / 4
          : 0,
      },
  );
  // Keep elapsed allocations even when an edit moves the window past them.
  for (const s of elapsed)
    if (!slots.some((q) => Date.parse(q.start) === Date.parse(s.start)))
      slots.push(s);
  slots.sort((a, b) => Date.parse(a.start) - Date.parse(b.start));
  return {
    plant_id: work.plant_id,
    segment_id: work.segment_id,
    local_date: work.local_date,
    revision_key: work.revision_key,
    price_area: work.price_area,
    peak_shaving_w: work.peak_shaving_w,
    target_wh: work.target_wh,
    window_start: work.window_start,
    window_end: work.window_end,
    status: !covered
      ? "pending_prices"
      : choices.length < required
        ? "insufficient_capacity"
        : "ready",
    slots,
    prepared_at: now.toISOString(),
    refresh_after: new Date(+now + 300_000).toISOString(),
  };
}
