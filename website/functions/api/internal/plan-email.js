// POST /api/internal/plan-email
// Called by sc-cloud the moment a billing webhook extends a plan.
// Header: x-sc-mail-secret: <SC_MAIL_SECRET>
// Body: { to, kind, plan, expires, amount, currency, displayName, days_left, email, provider }
// kind: plan (aka plan-activated) | trial-reminder | payment-failed | unmatched-payment | refund-confirmation
// `unmatched-payment` uses email/provider/amount/currency from the payload
// and goes to hello@ instead of the user.

import {
  paymentFailedEmail,
  planActivatedEmail,
  refundConfirmationEmail,
  sendBrevo,
  trialReminderEmail,
  unmatchedPaymentEmail,
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
  const kind = String(body.kind || "plan");
  if (kind !== "unmatched-payment" && !EMAIL_RE.test(to)) {
    return json({ error: "bad email" }, 400);
  }
  if (kind === "unmatched-payment" && !EMAIL_RE.test(to) && !EMAIL_RE.test(String(body.email || "").trim())) {
    return json({ error: "bad email" }, 400);
  }

  const displayName = String(body.displayName || "").slice(0, 80);

  let msg;
  if (kind === "plan" || kind === "plan-activated") {
    msg = planActivatedEmail({
      toEmail: to,
      plan: body.plan || "",
      expires: body.expires || "",
      amount: body.amount || "",
      currency: body.currency || "",
      displayName,
    });
  } else if (kind === "trial-reminder") {
    msg = trialReminderEmail({
      toEmail: to,
      daysLeft: body.days_left,
      displayName,
    });
  } else if (kind === "payment-failed") {
    msg = paymentFailedEmail({
      toEmail: to,
      plan: body.plan || "",
      expires: body.expires || "",
      displayName,
    });
  } else if (kind === "unmatched-payment") {
    msg = unmatchedPaymentEmail({
      email: String(body.email || "").trim() || to,
      amount: String(body.amount || ""),
      currency: String(body.currency || ""),
      provider: String(body.provider || ""),
      plan: body.plan || "",
      ts: new Date().toUTCString(),
    });
  } else if (kind === "refund-confirmation") {
    msg = refundConfirmationEmail({ toEmail: to, displayName });
  } else {
    return json({ error: "bad kind" }, 400);
  }
  const ok = await sendBrevo(env, msg);
  return json({ ok }, ok ? 200 : 502);
}
