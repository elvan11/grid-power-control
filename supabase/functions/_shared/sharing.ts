import { HttpError } from "./http.ts";

export type PlantMemberRole = "owner" | "admin" | "member" | "viewer";
export type InviteRole = "admin" | "member" | "viewer";

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

export function requireInviteRole(value: unknown): InviteRole {
  if (value === "admin" || value === "member" || value === "viewer") {
    return value;
  }
  return "member";
}

export function requireEmail(value: unknown): string {
  const email = typeof value === "string" ? normalizeEmail(value) : "";
  if (!email || !emailRegex.test(email)) {
    throw new HttpError(400, "A valid email is required");
  }
  return email;
}

export function requireNonEmptyString(
  value: unknown,
  fieldName: string,
): string {
  const normalized = typeof value === "string" ? value.trim() : "";
  if (!normalized) {
    throw new HttpError(400, `${fieldName} is required`);
  }
  return normalized;
}

export function generateInviteToken(): string {
  return `${crypto.randomUUID()}${crypto.randomUUID().replaceAll("-", "")}`;
}

export async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function roleRank(role: PlantMemberRole): number {
  switch (role) {
    case "owner":
      return 4;
    case "admin":
      return 3;
    case "member":
      return 2;
    case "viewer":
      return 1;
  }
}

export function mergeRole(
  existingRole: PlantMemberRole,
  inviteRole: InviteRole,
): PlantMemberRole {
  return roleRank(existingRole) >= roleRank(inviteRole) ? existingRole : inviteRole;
}

export function buildAcceptInviteUrl(token: string, explicitBaseUrl?: string): string {
  const configuredBase = explicitBaseUrl?.trim() ||
    Deno.env.get("SHARE_INVITES_BASE_URL")?.trim() ||
    "gridpowercontrol://auth/accept-invite";

  if (configuredBase.includes("{token}")) {
    return configuredBase.replaceAll("{token}", encodeURIComponent(token));
  }

  if (configuredBase.includes("#")) {
    const [prefix, fragment = ""] = configuredBase.split("#", 2);
    const joiner = fragment.includes("?") ? "&" : "?";
    return `${prefix}#${fragment}${joiner}token=${encodeURIComponent(token)}`;
  }

  const joiner = configuredBase.includes("?") ? "&" : "?";
  return `${configuredBase}${joiner}token=${encodeURIComponent(token)}`;
}

export async function sendInviteEmail(params: {
  invitedEmail: string;
  invitedByEmail: string | null;
  plantName: string;
  role: InviteRole;
  acceptUrl: string;
  expiresAtIso: string;
}): Promise<{
  sent: boolean;
  provider: "resend" | "disabled";
  providerMessage: string;
}> {
  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const fromEmail = Deno.env.get("SHARE_INVITES_FROM_EMAIL");

  if (!resendApiKey || !fromEmail) {
    return {
      sent: false,
      provider: "disabled",
      providerMessage:
        "Invite email provider is not configured (set RESEND_API_KEY and SHARE_INVITES_FROM_EMAIL).",
    };
  }

  const inviter = params.invitedByEmail ?? "A plant administrator";
  const subject = `${inviter} invited you to ${params.plantName}`;
  const text =
    `${inviter} invited you as ${params.role} to "${params.plantName}".\n\n` +
    `Accept invite: ${params.acceptUrl}\n` +
    `Invite expires at: ${params.expiresAtIso}\n`;

  const html = `
<p>${inviter} invited you as <strong>${params.role}</strong> to <strong>${params.plantName}</strong>.</p>
<p><a href="${params.acceptUrl}">Accept invitation</a></p>
<p>Invite expires at: ${params.expiresAtIso}</p>
`;

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: fromEmail,
      to: [params.invitedEmail],
      subject,
      text,
      html,
    }),
  });

  if (!response.ok) {
    const responseBody = await response.text();
    return {
      sent: false,
      provider: "resend",
      providerMessage: `Resend API error ${response.status}: ${responseBody}`,
    };
  }

  return {
    sent: true,
    provider: "resend",
    providerMessage: "Invite email sent using Resend.",
  };
}
