import { corsHeaders } from "./cors.ts";

export class HttpError extends Error {
  status: number;
  details?: unknown;

  constructor(status: number, message: string, details?: unknown) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export async function readJson<T>(req: Request): Promise<T> {
  try {
    return await req.json();
  } catch {
    throw new HttpError(400, "Invalid JSON payload");
  }
}

export function jsonResponse(
  payload: unknown,
  status = 200,
  headers: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      ...headers,
    },
  });
}

export function handleOptions(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}

export function errorResponse(error: unknown): Response {
  if (error instanceof HttpError) {
    return jsonResponse(
      { error: error.message, details: error.details ?? null },
      error.status,
    );
  }

  const message = error instanceof Error ? error.message : "Unexpected error";
  return jsonResponse({ error: message }, 500);
}

