import { beforeAll, describe, expect, it } from "vitest";

type SolisModule = typeof import("./solis.ts");

interface MockFetchResponse {
  status: number;
  body: Record<string, unknown>;
}

interface DenoEnvLike {
  get: (name: string) => string | undefined;
  set: (name: string, value: string) => void;
  delete: (name: string) => void;
}

let solis: SolisModule;

const envStore = new Map<string, string>();
const denoShim: { env: DenoEnvLike } = {
  env: {
    get: (name: string) => envStore.get(name),
    set: (name: string, value: string) => {
      envStore.set(name, value);
    },
    delete: (name: string) => {
      envStore.delete(name);
    },
  },
};

beforeAll(async () => {
  // solis.ts references Deno.env at module load time.
  (globalThis as unknown as { Deno?: { env: DenoEnvLike } }).Deno = denoShim;
  solis = await import("./solis.ts");
});

function withMockedFetch(
  responses: MockFetchResponse[],
  run: (calls: { url: string; init: RequestInit | undefined }[]) => Promise<void>,
): Promise<void> {
  const originalFetch = globalThis.fetch;
  const calls: { url: string; init: RequestInit | undefined }[] = [];
  let index = 0;

  globalThis.fetch = async (
    input: Request | URL | string,
    init?: RequestInit,
  ): Promise<Response> => {
    const url = typeof input === "string" || input instanceof URL
      ? String(input)
      : input.url;
    calls.push({ url, init });

    const next = responses[index];
    if (!next) {
      throw new Error(`Unexpected fetch call #${index + 1} to ${url}`);
    }
    index += 1;

    return new Response(JSON.stringify(next.body), {
      status: next.status,
      headers: {
        "content-type": "application/json",
      },
    });
  };

  return run(calls).finally(() => {
    globalThis.fetch = originalFetch;
    expect(index).toBe(responses.length);
  });
}

function testCredentials() {
  return {
    apiId: "test-api-id",
    apiSecret: "test-api-secret",
    inverterSn: "SN123",
    apiBaseUrl: "https://solis.example.test",
  };
}

describe("solis shared module", () => {
  it("testSolisConnection sends signed atRead request", async () => {
    await withMockedFetch(
      [
        {
          status: 200,
          body: {
            success: true,
            code: "0",
            msg: "ok",
            data: { msg: "5000", yuanzhi: "5000" },
          },
        },
      ],
      async (calls) => {
        const result = await solis.testSolisConnection(testCredentials());
        expect(result.ok).toBe(true);
        expect(result.endpoint).toBe("/v2/api/atRead");
        expect(result.code).toBe("0");
        expect(calls.length).toBe(1);
        expect(calls[0].url).toBe("https://solis.example.test/v2/api/atRead");

        const headers = new Headers(calls[0].init?.headers);
        expect(headers.get("Authorization") ?? "").toContain("API test-api-id:");
        expect(headers.has("Content-MD5")).toBe(true);
        expect(headers.has("Date")).toBe(true);
      },
    );
  });

  it("applySolisControls succeeds with mocked Solis API flow", async () => {
    await withMockedFetch(
      [
        {
          status: 200,
          body: {
            success: true,
            code: "0",
            msg: "ok",
            data: { yuanzhi: "4500" },
          },
        },
        {
          status: 200,
          body: {
            success: true,
            code: "0",
            msg: "ok",
            data: {},
          },
        },
        {
          status: 200,
          body: {
            success: true,
            code: "0",
            msg: "ok",
            data: { msg: "5000", yuanzhi: "4500" },
          },
        },
        {
          status: 200,
          body: {
            success: true,
            code: "0",
            msg: "ok",
            data: { yuanzhi: "0" },
          },
        },
        {
          status: 200,
          body: {
            success: true,
            code: "0",
            msg: "ok",
            data: {},
          },
        },
        {
          status: 200,
          body: {
            success: true,
            code: "0",
            msg: "ok",
            data: { msg: "1", yuanzhi: "0" },
          },
        },
      ],
      async (calls) => {
        const result = await solis.applySolisControls(testCredentials(), 5000, true);
        expect(result.ok).toBe(true);
        expect(result.steps.length).toBe(6);
        expect(result.steps.map((step) => step.payload.cid)).toEqual([
          solis.SOLIS_CIDS.PEAK_SHAVING_W,
          solis.SOLIS_CIDS.PEAK_SHAVING_W,
          solis.SOLIS_CIDS.PEAK_SHAVING_W,
          solis.SOLIS_CIDS.ALLOW_GRID_CHARGING,
          solis.SOLIS_CIDS.ALLOW_GRID_CHARGING,
          solis.SOLIS_CIDS.ALLOW_GRID_CHARGING,
        ]);
        expect(calls.map((call) => new URL(call.url).pathname)).toEqual([
          "/v2/api/atRead",
          "/v2/api/control",
          "/v2/api/atRead",
          "/v2/api/atRead",
          "/v2/api/control",
          "/v2/api/atRead",
        ]);
      },
    );
  });

  it("readSolisBatterySoc resolves station id from list and reads station detail", async () => {
    await withMockedFetch(
      [
        {
          status: 200,
          body: {
            success: true,
            code: "0",
            msg: "ok",
            data: {
              page: {
                records: [{ id: 1234, sno: "SN123" }],
              },
            },
          },
        },
        {
          status: 200,
          body: {
            success: true,
            code: "0",
            msg: "ok",
            data: {
              batteryPercentage: 74,
            },
          },
        },
      ],
      async (calls) => {
        const result = await solis.readSolisBatterySoc(testCredentials());
        expect(result.batteryPercentage).toBe(74);
        expect(result.stationId).toBe("1234");
        expect(result.steps.length).toBe(2);
        expect(calls.map((call) => new URL(call.url).pathname)).toEqual([
          "/v1/api/userStationList",
          "/v1/api/stationDetail",
        ]);
      },
    );
  });

  it("readSolisBatterySoc uses configured station id when available", async () => {
    await withMockedFetch(
      [
        {
          status: 200,
          body: {
            success: true,
            code: "0",
            msg: "ok",
            data: {
              batteryPercentage: "59%",
            },
          },
        },
      ],
      async (calls) => {
        const result = await solis.readSolisBatterySoc({
          ...testCredentials(),
          stationId: "999",
        });
        expect(result.batteryPercentage).toBe(59);
        expect(result.stationId).toBe("999");
        expect(calls.length).toBe(1);
        expect(calls[0].url).toBe("https://solis.example.test/v1/api/stationDetail");
      },
    );
  });

  it("validatePeakShavingW enforces step and configured bounds", () => {
    const oldMin = denoShim.env.get("SOLIS_PEAK_SHAVING_MIN_W");
    const oldMax = denoShim.env.get("SOLIS_PEAK_SHAVING_MAX_W");

    try {
      denoShim.env.set("SOLIS_PEAK_SHAVING_MIN_W", "1000");
      denoShim.env.set("SOLIS_PEAK_SHAVING_MAX_W", "9000");

      expect(solis.validatePeakShavingW(5000)).toBe(5000);
      expect(() => solis.validatePeakShavingW(5050)).toThrow(
        "peak_shaving_w must be in 100W steps",
      );
      expect(() => solis.validatePeakShavingW(9500)).toThrow(
        "peak_shaving_w must be within 1000..9000 W",
      );
    } finally {
      if (oldMin === undefined) {
        denoShim.env.delete("SOLIS_PEAK_SHAVING_MIN_W");
      } else {
        denoShim.env.set("SOLIS_PEAK_SHAVING_MIN_W", oldMin);
      }
      if (oldMax === undefined) {
        denoShim.env.delete("SOLIS_PEAK_SHAVING_MAX_W");
      } else {
        denoShim.env.set("SOLIS_PEAK_SHAVING_MAX_W", oldMax);
      }
    }
  });
});
