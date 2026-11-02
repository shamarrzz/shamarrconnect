// POST /api/internal/auth-email
// Called by sc-cloud when a password code or a password-changed notice is ready.
// Header: x-sc-mail-secret: <SC_MAIL_SECRET>
// Body: { to, kind, code, displayName }
// kind: reset-code | signup-code | password-changed | welcome | signup-admin
// The code is never written to the log.

import {
  emailCodeEmail,
  passwordChangedEmail,
  sendBrevo,
  signupAdminEmail,
  welcomeEmail,
} from "../../_lib/email.js";

const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,253}\.[^\s@]{2,}$/;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function sameSecret(got, expect) {
  if (!expect || got.length !== expect.length) return false;
  let diff = 0;
  for (let i = 0; i < got.length; i++) diff |= got.charCodeAt(i) ^ expect.charCodeAt(i);
  return diff === 0;
}

export async function onRequestPost({ request, env }) {
  const expect = env.SC_MAIL_SECRET || "";
  const got = request.headers.get("x-sc-mail-secret") || "";
  if (!sameSecret(got, expect)) return json({ error: "unauthorized" }, 401);

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "bad json" }, 400);
  }
  const to = String(body.to || "").trim();
  if (!EMAIL_RE.test(to)) return json({ error: "bad email" }, 400);
  const kind = String(body.kind || "");
  const displayName = String(body.displayName || "").slice(0, 80);
  const code = String(body.code || "");

  let msg;
  if (kind === "reset-code" || kind === "signup-code") {
    if (!/^\d{6}$/.test(code)) return json({ error: "bad code" }, 400);
    msg = emailCodeEmail({ toEmail: to, code, displayName, kind });
  } else if (kind === "password-changed") {
    msg = passwordChangedEmail({ toEmail: to, displayName });
  } else if (kind === "welcome") {
    msg = welcomeEmail({ toEmail: to, displayName });
  } else if (kind === "signup-admin") {
    msg = signupAdminEmail({ email: to, ts: new Date().toUTCString() });
  } else {
    return json({ error: "bad kind" }, 400);
  }
  const ok = await sendBrevo(env, msg);
  return json({ ok }, ok ? 200 : 502);
}
