// POST /api/team/send-invite
// Body: { email, accept_url, org_name, role, inviter_email? }
// Header: Authorization: Bearer <sc-cloud JWT>
// Verifies the JWT against api.shamarrconnect.com, then emails the invite via Brevo.

import { sendTeamInvite } from "../../_lib/email.js";

const SEC = {
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Cache-Control": "no-store",
};

const API = "https://api.shamarrconnect.com";
const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,253}\.[^\s@]{2,}$/;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...SEC },
  });
}

async function verifyBearer(request) {
  const auth = request.headers.get("Authorization") || "";
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  try {
    const r = await fetch(`${API}/api/currentUser`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${m[1]}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ id: "", uuid: "" }),
    });
    if (!r.ok) return null;
    return await r.json();
  } catch (e) {
    console.error("send-invite: verify failed", e);
    return null;
  }
}

export async function onRequestPost({ request, env }) {
  const user = await verifyBearer(request);
  if (!user) return json({ ok: false, error: "Sign in required" }, 401);

  let data;
  try {
    data = await request.json();
  } catch {
    return json({ ok: false, error: "bad request" }, 400);
  }

  const email = String((data && data.email) || "").trim().toLowerCase();
  const acceptUrl = String((data && data.accept_url) || "").trim();
  const orgName = String((data && data.org_name) || "a team").trim().slice(0, 80);
  const role = String((data && data.role) || "member").trim().toLowerCase();
  const inviterEmail =
    String((data && data.inviter_email) || user.email || user.name || "").trim();

  if (!EMAIL_RE.test(email)) {
    return json({ ok: false, error: "invalid email" }, 400);
  }
  if (
    !acceptUrl.startsWith("https://shamarrconnect.com/account/invite/") &&
    !acceptUrl.startsWith("https://www.shamarrconnect.com/account/invite/")
  ) {
    return json({ ok: false, error: "invalid accept link" }, 400);
  }
  if (!["member", "admin"].includes(role)) {
    return json({ ok: false, error: "invalid role" }, 400);
  }

  const sent = await sendTeamInvite(env, {
    toEmail: email,
    orgName,
    role,
    inviterEmail,
    acceptUrl,
  });

  if (!sent) {
    return json(
      {
        ok: false,
        error:
          "Could not send email right now. Copy the invite link and share it manually.",
      },
      502
    );
  }

  return json({ ok: true, emailed: email });
}

export async function onRequest() {
  return json({ ok: false, error: "method not allowed" }, 405);
}
