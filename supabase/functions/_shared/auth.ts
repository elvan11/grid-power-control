import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { HttpError } from "./http.ts";

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function bearerToken(req: Request): string {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    throw new HttpError(401, "Missing Authorization bearer token");
  }
  return authHeader.replace("Bearer ", "").trim();
}

export function createAdminClient(): SupabaseClient {
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
  );
}

export function createUserClient(req: Request): SupabaseClient {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    throw new HttpError(401, "Missing Authorization header");
  }

  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    },
  );
}

export async function requireUser(req: Request): Promise<{
  userClient: SupabaseClient;
  userId: string;
  userEmail: string | null;
}> {
  const token = bearerToken(req);
  const userClient = createUserClient(req);
  const { data, error } = await userClient.auth.getUser(token);

  if (error || !data.user) {
    throw new HttpError(401, "Invalid or expired auth token", error ?? null);
  }

  return {
    userClient,
    userId: data.user.id,
    userEmail: data.user.email?.toLowerCase() ?? null,
  };
}

export async function requirePlantRole(
  userClient: SupabaseClient,
  plantId: string,
  roles: string[],
): Promise<void> {
  const { data, error } = await userClient.rpc("has_plant_role", {
    p_plant_id: plantId,
    p_roles: roles,
  });

  if (error) {
    throw new HttpError(500, "Failed to validate plant role", error);
  }

  if (!data) {
    throw new HttpError(403, "Insufficient permissions for plant");
  }
}
