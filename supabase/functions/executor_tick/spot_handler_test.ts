import { describe, it, expect } from "vitest";
import { createExecutorTickHandler, type ExecutorTickDeps } from "./handler.ts";

function setup(current: string, future: string, lastSource = "schedule") {
  const calls: string[] = [];
  const applied: boolean[] = [];
  const now = new Date("2026-10-31T00:14:00Z");
  const deps: ExecutorTickDeps = {
    handleOptions: () => null,
    jsonResponse: (p, s = 200) => Response.json(p, { status: s }),
    errorResponse: (e) => Response.json({ error: String(e) }, { status: 500 }),
    readJson: async () => ({}) as any,
    createAdminClient: () => ({
      rpc: async (name, args) => {
        calls.push(`${name}:${args?.p_at ?? ""}`);
        if (name === "claim_due_plants")
          return { data: [{ plant_id: "p" }], error: null };
        return {
          data: [
            {
              desired_peak_shaving_w: 6000,
              desired_grid_charging_allowed:
                args?.p_at === now.toISOString() ? false : true,
              next_due_at: "2026-10-31T00:15:00Z",
              source: args?.p_at === now.toISOString() ? current : future,
            },
          ],
          error: null,
        };
      },
      from: (table) => ({
        select: () => ({
          eq: () => ({
            maybeSingle: async () => ({
              data: {
                next_due_at: "2026-10-31T00:00:00Z",
                last_control_source: lastSource,
              },
              error: null,
            }),
            lte: () => ({
              gt: () => ({
                order: () => ({
                  limit: () => ({
                    maybeSingle: async () => ({ data: null, error: null }),
                  }),
                }),
              }),
            }),
          }),
        }),
        upsert: async () => ({ error: null }),
        insert: async () => ({ error: null }),
      }),
    }),
    loadStoredSolisCredentials: async () => ({
      credentials: { apiId: "id", apiSecret: "s", inverterSn: "sn" },
    }),
    applySolisControls: async (_c, _p, g) => {
      applied.push(g);
      return { ok: true, steps: [] };
    },
    getEnv: () => "secret",
    now: () => now,
    sleep: async () => {},
  };
  return { deps, calls, applied };
}
describe("spot quarter execution", () => {
  it("recomputes a spot interval that expires while loading credentials", async () => {
    const { deps, calls } = setup("spot_peak_shave", "spot_import");
    const load = deps.loadStoredSolisCredentials;
    deps.loadStoredSolisCredentials = async (client, id) => {
      deps.now().setTime(Date.parse("2026-10-31T00:31:00Z"));
      return load(client, id);
    };
    await createExecutorTickHandler(deps)(
      new Request("https://test", {
        method: "POST",
        headers: { Authorization: "Bearer secret" },
        body: "{}",
      }),
    );
    expect(calls).toContain(
      "compute_plant_desired_control:2026-10-31T00:31:00.000Z",
    );
  });
  for (const [current, future, last] of [
    ["override", "override", "override"],
    ["spot_peak_shave", "spot_import", "spot_import"],
    ["schedule", "spot_import", "schedule"],
    ["schedule", "schedule", "spot_import"],
  ]) {
    it(`uses present controls across ${current}/${future}/${last} boundary`, async () => {
      const { deps, applied } = setup(current, future, last);
      const r = await createExecutorTickHandler(deps)(
        new Request("https://test", {
          method: "POST",
          headers: { Authorization: "Bearer secret" },
          body: "{}",
        }),
      );
      expect(r.status).toBe(200);
      expect(applied).toEqual([false]);
    });
  }
  it("applies controls before price preparation can block", async () => {
    const { deps, applied } = setup("spot_peak_shave", "spot_import");
    let prepared = false;
    deps.prepareSpotImports = async () => {
      expect(applied).toEqual([false]);
      prepared = true;
    };
    await createExecutorTickHandler(deps)(
      new Request("https://test", {
        method: "POST",
        headers: { Authorization: "Bearer secret" },
        body: "{}",
      }),
    );
    expect(prepared).toBe(true);
  });
  it("prepares when no plants are due and releases only its exact lease token", async () => {
    const { deps } = setup("spot_peak_shave", "spot_import");
    const client = deps.createAdminClient();
    const rpc = client.rpc;
    const lease = "2026-10-31T00:19:00.123456+00:00";
    const released: unknown[] = [];
    let claims = 0;
    client.rpc = async (name, args) => {
      if (name === "claim_due_plants")
        return {
          data: claims++ === 0 ? [{ plant_id: "p", lease_until: lease }] : [],
          error: null,
        };
      if (name === "release_plant_lease") {
        released.push(args);
        return { data: true, error: null };
      }
      return await rpc(name, args);
    };
    deps.createAdminClient = () => client;
    let prepared = 0;
    deps.prepareSpotImports = async () => {
      prepared++;
    };
    for (let i = 0; i < 2; i++)
      await createExecutorTickHandler(deps)(
        new Request("https://test", {
          method: "POST",
          headers: { Authorization: "Bearer secret" },
          body: "{}",
        }),
      );
    expect(prepared).toBe(2);
    expect(released).toEqual([{ p_plant_id: "p", p_lease_until: lease }]);
  });
});
