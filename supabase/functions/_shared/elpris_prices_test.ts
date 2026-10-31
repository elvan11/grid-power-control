import { describe, it, expect } from "vitest";
import { createHmac } from "node:crypto";
import { loadElprisPrices, sourceDatesForSlots } from "./elpris_prices.ts";
describe("ElprisLive adapter", () => {
  it("requests market-local dates across UTC boundaries", () => {
    expect(
      sourceDatesForSlots("FI", [
        { start: "2026-10-31T21:45:00Z", end: "2026-10-31T22:00:00Z" },
        { start: "2026-10-31T22:00:00Z", end: "2026-10-31T22:15:00Z" },
      ]),
    ).toEqual(["2026-10-31", "2026-11-01"]);
  });
  it("signs canonical protocol and accepts timestamped prices regardless of complete flag", async () => {
    const rows = await loadElprisPrices("SE3", "2026-10-31", {
      now: new Date("2026-10-31T00:00:12Z"),
      secret: "test",
      session: "grid",
      fetcher: async (input, init) => {
        expect(String(input)).toContain("get-prices?area=SE3&date=2026-10-31");
        const h = new Headers(init?.headers);
        expect(h.get("x-elpris-signature")).toBe(
          createHmac("sha256", "test")
            .update(
              "GET\n/get-prices\narea=SE3&date=2026-10-31\n2026-10-31T00:00Z\ngrid",
            )
            .digest("hex"),
        );
        return Response.json({
          area: "SE3",
          date: "2026-10-31",
          complete: false,
          entries: [
            {
              time_start: "2026-10-31T00:00Z",
              time_end: "2026-10-31T00:15Z",
              price_per_kwh: -1,
            },
          ],
        });
      },
    });
    expect(rows[0].price_per_kwh).toBe(-1);
  });
  it("rejects upstream failure, malformed intervals and wrong area", async () => {
    for (const response of [
      new Response("down", { status: 503 }),
      Response.json({ area: "SE4", date: "2026-10-31", entries: [] }),
      Response.json({
        area: "SE3",
        date: "2026-10-31",
        entries: [
          { time_start: "invalid", time_end: "invalid", price_per_kwh: 1 },
        ],
      }),
    ]) {
      await expect(
        loadElprisPrices("SE3", "2026-10-31", {
          now: new Date(),
          secret: "t",
          fetcher: async () => response,
        }),
      ).rejects.toThrow();
    }
  });
});
