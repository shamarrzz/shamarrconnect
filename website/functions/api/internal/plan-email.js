// POST /api/internal/plan-email
// Called by sc-cloud the moment a billing webhook extends a plan.
// Header: x-sc-mail-secret: <SC_MAIL_SECRET>
// Body: { to, plan, expires, amount, currency, displayName }

import { planActivatedEmail, sendBrevo } from "../../_lib/email.js";

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

  const msg = planActivatedEmail({
    toEmail: to,
    plan: body.plan || "",
    expires: body.expires || "",
    amount: body.amount || "",
    currency: body.currency || "",
    displayName: body.displayName || "",
  });
  const ok = await sendBrevo(env, msg);
  return json({ ok }, ok ? 200 : 502);
}
