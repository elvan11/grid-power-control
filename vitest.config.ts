import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["supabase/functions/**/*_test.ts"],
    exclude: ["app/**", "output/**", "references/**"],
  },
});
