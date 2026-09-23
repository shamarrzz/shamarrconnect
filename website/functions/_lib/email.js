// Transactional email via Brevo (HTTP API — Workers cannot do raw SMTP).
// env.BREVO_API_KEY must be set as a Pages secret. Missing key = skip
// silently (waitlist storage must never fail because email did).
//
// Layout follows DailyLight's doorbell mail (greeting, one headline, optional
// callout, one button) in ShamarrConnect tokens. PNG S-mark only — no SVG.

const BREVO_URL = "https://api.brevo.com/v3/smtp/email";
const SENDER = { name: "ShamarrConnect", email: "hello@shamarrconnect.com" };
const MARK = "https://shamarrconnect.com/email-mark.png";
const SITE = "https://shamarrconnect.com";
const FONT =
  "-apple-system,BlinkMacSystemFont,'Segoe UI',Inter,Helvetica,Arial,sans-serif";

const C = {
  bg: "#F8FAFF",
  ink: "#0F1B33",
  muted: "#5A6B85",
  line: "#E6ECF5",
  cta: "#2B5CE6",
  ctaDk: "#1E3FA8",
  soft: "#EAF0FF",
};

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export async function sendBrevo(env, msg) {
  if (!env.BREVO_API_KEY) {
    console.error("email: BREVO_API_KEY missing, skipping send");
    return false;
  }
  try {
    const r = await fetch(BREVO_URL, {
      method: "POST",
      headers: { "api-key": env.BREVO_API_KEY, "Content-Type": "application/json" },
      body: JSON.stringify({ sender: SENDER, ...msg }),
    });
    if (!r.ok) console.error("email: brevo", r.status, await r.text());
    return r.ok;
  } catch (e) {
    console.error("email: brevo fetch failed", e);
    return false;
  }
}

function callout(innerHtml) {
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 24px 0;">
    <tr><td style="padding:16px 18px;background:${C.soft};border-radius:4px;border-left:3px solid ${C.cta};">
      ${innerHtml}
    </td></tr>
  </table>`;
}

function fieldTable(rows) {
  const trs = rows
    .map(
      ([k, v]) =>
        `<tr><td style="padding:4px 16px 4px 0;color:${C.muted};font-size:15px;vertical-align:top;">${escapeHtml(k)}</td><td style="padding:4px 0;font-weight:600;color:${C.ink};font-size:15px;">${escapeHtml(v)}</td></tr>`
    )
    .join("");
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0">${trs}</table>`;
}

function ctaBlock(label, url) {
  if (!label || !url) return "";
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:8px 0 8px 0;">
    <tr><td align="center" style="border-radius:12px;background:${C.cta};">
      <a href="${escapeHtml(url)}" style="display:inline-block;padding:14px 24px;font-size:15px;font-weight:600;color:#FFFFFF;text-decoration:none;letter-spacing:0.2px;">${escapeHtml(label)}</a>
    </td></tr>
  </table>`;
}

// Open canvas, ~520px. Greeting + headline + body + optional callout + one button.
function shell({
  preheader,
  greeting,
  headline,
  bodyHtml,
  calloutHtml,
  ctaLabel,
  ctaUrl,
  extraHtml,
}) {
  const greet = greeting
    ? `<p style="margin:0 0 14px 0;font-size:15px;color:${C.muted};">${escapeHtml(greeting)}</p>`
    : "";
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="color-scheme" content="light">
  <title>ShamarrConnect</title>
</head>
<body style="margin:0;padding:0;background:${C.bg};font-family:${FONT};color:${C.ink};-webkit-font-smoothing:antialiased;">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;">${escapeHtml(preheader || "")}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:${C.bg};">
    <tr><td align="center" style="padding:40px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:520px;">

        <tr><td style="padding:0 4px 28px 4px;">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0">
            <tr>
              <td style="vertical-align:middle;padding-right:10px;">
                <img src="${MARK}" width="36" height="36" alt="" style="display:block;width:36px;height:36px;border:0;">
              </td>
              <td style="vertical-align:middle;font-weight:800;font-size:17px;letter-spacing:-0.03em;color:#0F1B33;font-family:${FONT};">Shamarr<span style="color:#2B5CE6;">Connect</span></td>
            </tr>
          </table>
        </td></tr>

        <tr><td style="padding:0 4px 16px 4px;">
          ${greet}
          <h1 style="margin:0;font-size:26px;line-height:1.25;font-weight:700;color:${C.ink};letter-spacing:-0.4px;">${escapeHtml(headline)}</h1>
        </td></tr>

        <tr><td style="padding:8px 4px 0 4px;font-size:16px;line-height:1.65;color:${C.ink};">
          ${bodyHtml || ""}
          ${calloutHtml || ""}
          ${ctaBlock(ctaLabel, ctaUrl)}
          ${extraHtml || ""}
        </td></tr>

        <tr><td style="padding:36px 4px 0 4px;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
            <tr><td style="border-top:1px solid ${C.line};padding-top:18px;">
              <p style="margin:0 0 8px 0;font-size:12px;line-height:1.6;color:${C.muted};">
                ShamarrConnect &middot; Your computers, when you need them.
              </p>
              <p style="margin:0;font-size:12px;line-height:1.6;color:${C.muted};">
                <a href="${SITE}/privacy" style="color:${C.cta};text-decoration:none;">Privacy</a> &middot;
                <a href="${SITE}/terms" style="color:${C.cta};text-decoration:none;">Terms</a> &middot;
                <a href="${SITE}/refund" style="color:${C.cta};text-decoration:none;">Refunds</a> &middot;
                <a href="mailto:support@shamarrconnect.com" style="color:${C.cta};text-decoration:none;">support@shamarrconnect.com</a>
              </p>
            </td></tr>
          </table>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function p(text) {
  return `<p style="margin:0 0 14px 0;">${text}</p>`;
}

function faint(text) {
  return `<p style="margin:18px 0 0 0;font-size:13px;color:${C.muted};">${text}</p>`;
}

function brevoMsg({ to, subject, html, text, replyTo }) {
  const msg = {
    to: Array.isArray(to) ? to : [{ email: to }],
    subject,
    htmlContent: html,
    textContent: text,
  };
  if (replyTo) msg.replyTo = typeof replyTo === "string" ? { email: replyTo } : replyTo;
  return msg;
}

function planLabel(plan) {
  const p0 = String(plan || "").toLowerCase();
  if (p0 === "team") return "Team";
  if (p0 === "solo" || p0 === "pro") return "Pro";
  return plan || "your plan";
}

// ── Waitlist (live) ──────────────────────────────────────────────────────

export function waitlistConfirm(email, region) {
  const money =
    region === "ng"
      ? "Launch plans start from local pricing in your region."
      : "Launch plans start from $9/month.";
  const html = shell({
    preheader: "You're on the ShamarrConnect launch list.",
    headline: "You're on the list.",
    bodyHtml:
      p("Thanks for your interest in ShamarrConnect. Hosted remote desktop that is private by design and run for you. We'll email this address the moment doors open.") +
      p(`${money} Early members hear first, and there will be a thank-you for the people who believed early.`),
    ctaLabel: "See what ShamarrConnect does",
    ctaUrl: SITE,
    extraHtml: faint(`You signed up with ${escapeHtml(email)}. If that wasn't you, ignore this email. Nothing else happens.`),
  });
  const text = `You're on the ShamarrConnect launch list.\n\nWe'll email ${email} the moment doors open. ${money}\n\n${SITE}\n\nIf this wasn't you, ignore this email.`;
  return brevoMsg({
    to: email,
    subject: "You're on the ShamarrConnect list",
    html,
    text,
  });
}

export function waitlistNotify(email, region, ts) {
  const html = shell({
    preheader: `New waitlist signup: ${email}`,
    headline: "New waitlist signup",
    calloutHtml: callout(
      fieldTable([
        ["Email", email],
        ["Region", region === "ng" ? "NG pricing" : "INTL pricing"],
        ["Time", ts],
      ])
    ),
    extraHtml: faint(`Hit reply to write back. Replies go to ${escapeHtml(email)}.`),
  });
  return brevoMsg({
    to: "hello@shamarrconnect.com",
    replyTo: email,
    subject: `New waitlist signup: ${email}`,
    html,
    text: `New waitlist signup\nEmail: ${email}\nRegion: ${region}\nTime: ${ts}\nReply to this email to reach them directly.`,
  });
}

export async function sendWaitlistEmails(env, ctx, email, region) {
  const ts = new Date().toUTCString();
  const tasks = [
    sendBrevo(env, waitlistNotify(email, region, ts)),
    sendBrevo(env, waitlistConfirm(email, region)),
  ];
  if (ctx && ctx.waitUntil) ctx.waitUntil(Promise.all(tasks));
  else await Promise.all(tasks);
}

// ── Team invite (live) ───────────────────────────────────────────────────

export function teamInviteEmail({
  toEmail,
  orgName,
  role,
  inviterEmail,
  acceptUrl,
}) {
  const roleLabel = role === "admin" ? "admin" : "member";
  const safeOrg = String(orgName || "a ShamarrConnect team");
  const safeInviter = String(inviterEmail || "A teammate");
  const html = shell({
    preheader: `You're invited to ${safeOrg} on ShamarrConnect`,
    headline: `You're invited to join ${safeOrg}`,
    bodyHtml:
      p(`<strong>${escapeHtml(safeInviter)}</strong> invited you to their ShamarrConnect team as a <strong>${escapeHtml(roleLabel)}</strong>.`) +
      p(`Sign in with <strong>${escapeHtml(toEmail)}</strong> (the same address this email was sent to), then open the button below to accept.`),
    ctaLabel: "Accept invite",
    ctaUrl: acceptUrl,
    extraHtml:
      faint(`If the button does not work, paste this link into your browser:<br><a href="${escapeHtml(acceptUrl)}" style="color:${C.cta};word-break:break-all;">${escapeHtml(acceptUrl)}</a>`) +
      faint(`Need an account first? Create one with <strong>${escapeHtml(toEmail)}</strong> in the ShamarrConnect app, or ask your admin, then open the link again. This invite expires in 7 days. If you did not expect this, ignore the email.`),
  });
  const text =
    `You're invited to join ${safeOrg} on ShamarrConnect\n\n` +
    `${safeInviter} invited you as ${roleLabel}.\n\n` +
    `Sign in with ${toEmail}, then open:\n${acceptUrl}\n\n` +
    `Invite expires in 7 days.`;
  return brevoMsg({
    to: toEmail,
    subject: `Join ${safeOrg} on ShamarrConnect`,
    html,
    text,
  });
}

export async function sendTeamInvite(env, payload) {
  return sendBrevo(env, teamInviteEmail(payload));
}

// ── Unwired (copy ready; no API send yet) ────────────────────────────────

export function welcomeEmail({ toEmail, displayName }) {
  const first = (displayName || "").trim().split(/\s+/)[0];
  const html = shell({
    preheader: "Your ShamarrConnect account is ready.",
    greeting: first ? `Hi ${first},` : "",
    headline: "Your ShamarrConnect account is ready",
    bodyHtml: p(
      `Sign in with <strong>${escapeHtml(toEmail)}</strong> in the ShamarrConnect app. Your computers show up on your desk.`
    ),
    ctaLabel: "Open your desk",
    ctaUrl: `${SITE}/account`,
  });
  return brevoMsg({
    to: toEmail,
    subject: "Your ShamarrConnect account is ready",
    html,
    text: `Your ShamarrConnect account is ready.\n\nSign in with ${toEmail} in the app.\n${SITE}/account`,
  });
}

export function passwordResetEmail({ toEmail, resetUrl, displayName }) {
  const first = (displayName || "").trim().split(/\s+/)[0];
  const html = shell({
    preheader: "Reset your ShamarrConnect password.",
    greeting: first ? `Hi ${first},` : "",
    headline: "Reset your ShamarrConnect password",
    bodyHtml: p("Use the button below to choose a new password. This link expires in 1 hour."),
    ctaLabel: "Set a new password",
    ctaUrl: resetUrl,
    extraHtml: faint("If you did not ask for this, ignore the email. Your password stays the same."),
  });
  return brevoMsg({
    to: toEmail,
    subject: "Reset your ShamarrConnect password",
    html,
    text: `Reset your ShamarrConnect password.\n\n${resetUrl}\n\nThis link expires in 1 hour. If you did not ask for this, ignore the email.`,
  });
}

export function passwordChangedEmail({ toEmail, displayName }) {
  const first = (displayName || "").trim().split(/\s+/)[0];
  const html = shell({
    preheader: "Your ShamarrConnect password changed.",
    greeting: first ? `Hi ${first},` : "",
    headline: "Your ShamarrConnect password changed",
    bodyHtml: p("If you did this, you can ignore this email. If you did not, reset your password and write to support."),
    ctaLabel: "Review account",
    ctaUrl: `${SITE}/account`,
  });
  return brevoMsg({
    to: toEmail,
    subject: "Your ShamarrConnect password changed",
    html,
    text: `Your ShamarrConnect password changed.\n\nIf you did not do this, write to support@shamarrconnect.com\n${SITE}/account`,
  });
}

export function mfaChangedEmail({ toEmail, enabled, displayName }) {
  const first = (displayName || "").trim().split(/\s+/)[0];
  const on = !!enabled;
  const headline = on
    ? "Authenticator is on for your account"
    : "Authenticator is off for your account";
  const html = shell({
    preheader: headline + ".",
    greeting: first ? `Hi ${first},` : "",
    headline,
    bodyHtml: p(
      on
        ? "Sign-in now asks for a code from your authenticator app, as well as your password."
        : "Sign-in now uses your password only. You can turn the authenticator back on from your account."
    ),
    ctaLabel: "Review account",
    ctaUrl: `${SITE}/account`,
    extraHtml: faint("If you did not do this, reset your password and write to support."),
  });
  return brevoMsg({
    to: toEmail,
    subject: headline,
    html,
    text: `${headline}.\n\n${SITE}/account\n\nIf you did not do this, write to support@shamarrconnect.com`,
  });
}

export function planActivatedEmail({ toEmail, plan, expires, displayName }) {
  const first = (displayName || "").trim().split(/\s+/)[0];
  const label = planLabel(plan);
  const until = expires ? ` until ${expires}` : "";
  const rows = [["Plan", label]];
  if (expires) rows.push(["Active until", expires]);
  const html = shell({
    preheader: `Your ShamarrConnect ${label} plan is confirmed${until}.`,
    greeting: first ? `Hi ${first},` : "",
    headline: "Your plan is confirmed",
    bodyHtml:
      p(`Your ${escapeHtml(label)} plan is confirmed${escapeHtml(until)}.`) +
      p("Paystack sends the payment receipt. This note is only to confirm the account. Sign in with the same email you paid with. No license key."),
    calloutHtml: callout(fieldTable(rows)),
    ctaLabel: "Open your account",
    ctaUrl: `${SITE}/account`,
  });
  return brevoMsg({
    to: toEmail,
    subject: `Your ShamarrConnect ${label} plan is confirmed`,
    html,
    text: `Your ShamarrConnect ${label} plan is confirmed${until}.\n\nPaystack sends the payment receipt. Sign in with ${toEmail}.\n${SITE}/account`,
  });
}

export function paymentFailedEmail({ toEmail, plan, expires, displayName }) {
  const first = (displayName || "").trim().split(/\s+/)[0];
  const label = planLabel(plan);
  const html = shell({
    preheader: "We could not renew your ShamarrConnect plan.",
    greeting: first ? `Hi ${first},` : "",
    headline: "We could not renew your plan",
    bodyHtml: p(
      expires
        ? `Your ${escapeHtml(label)} access stays until ${escapeHtml(expires)}. After that the account returns to Free.`
        : `We could not take payment for your ${escapeHtml(label)} plan. Update billing to keep paid access.`
    ),
    ctaLabel: "Update billing",
    ctaUrl: `${SITE}/pricing`,
    extraHtml: faint("Need a hand? Write to support@shamarrconnect.com with the email you pay with."),
  });
  return brevoMsg({
    to: toEmail,
    subject: "We could not renew your ShamarrConnect plan",
    html,
    text: `We could not renew your ${label} plan.${expires ? ` Access stays until ${expires}.` : ""}\n\n${SITE}/pricing`,
  });
}

export function deletionReceivedEmail({ toEmail }) {
  const html = shell({
    preheader: "We received your ShamarrConnect deletion request.",
    headline: "We received your deletion request",
    bodyHtml:
      p(`We will delete the ShamarrConnect account for <strong>${escapeHtml(toEmail)}</strong> within 14 days.`) +
      p("You will get another email when the account is gone. Deleting the account does not issue a refund on its own."),
    extraHtml: faint(`If you did not ask for this, write to <a href="mailto:privacy@shamarrconnect.com" style="color:${C.cta};text-decoration:none;">privacy@shamarrconnect.com</a> from this address.`),
  });
  return brevoMsg({
    to: toEmail,
    subject: "We received your ShamarrConnect deletion request",
    html,
    text: `We received your request to delete ${toEmail}. We process this within 14 days. You will get another email when the account is gone.\n\nIf you did not ask for this, write to privacy@shamarrconnect.com`,
  });
}

export function accountDeletedEmail({ toEmail }) {
  const html = shell({
    preheader: "Your ShamarrConnect account is gone.",
    headline: "Your ShamarrConnect account is gone",
    bodyHtml:
      p("We removed the account, saved devices, labels, and team membership.") +
      p("We do not store the contents of remote sessions, so there is nothing of that kind to delete. Invoices we must keep for tax stay on file and are not used to run the app."),
  });
  return brevoMsg({
    to: toEmail,
    subject: "Your ShamarrConnect account is gone",
    html,
    text: `Your ShamarrConnect account (${toEmail}) is gone.\n\nWe removed the account, devices, and team membership. Questions: privacy@shamarrconnect.com`,
  });
}

export function unmatchedPaymentEmail({ email, amount, currency, provider, plan, ts }) {
  const html = shell({
    preheader: `Payment with no matching account: ${email}`,
    headline: "Payment with no matching account",
    calloutHtml: callout(
      fieldTable(
        [
          ["Email", email || ""],
          ["Amount", [amount, currency].filter(Boolean).join(" ")],
          ["Provider", provider || ""],
          ["Plan", plan || ""],
          ["Time", ts || ""],
        ].filter(([, v]) => v)
      )
    ),
    extraHtml: faint("Logged with user_id empty. Apply the plan once the account email is confirmed."),
  });
  return brevoMsg({
    to: "hello@shamarrconnect.com",
    replyTo: email || undefined,
    subject: `Payment with no matching account: ${email}`,
    html,
    text: `Payment with no matching account\nEmail: ${email}\nAmount: ${amount} ${currency}\nProvider: ${provider}\nPlan: ${plan}\nTime: ${ts}`,
  });
}

// ── Preview gallery (Access-gated /preview/email) ────────────────────────

export function previewFixtures() {
  const acceptUrl = `${SITE}/account/invite/?token=preview-token`;
  const resetUrl = `${SITE}/account/reset/?token=preview-token`;
  const ts = "Mon, 21 Sep 2026 12:00:00 GMT";
  return [
    { id: "waitlist-confirm", live: true, title: "Waitlist confirm", msg: waitlistConfirm("ada@example.com", "ng") },
    { id: "waitlist-confirm-intl", live: true, title: "Waitlist confirm (intl)", msg: waitlistConfirm("ada@example.com", "intl") },
    { id: "waitlist-notify", live: true, title: "Waitlist → hello@", msg: waitlistNotify("ada@example.com", "ng", ts) },
    {
      id: "team-invite",
      live: true,
      title: "Team invite",
      msg: teamInviteEmail({
        toEmail: "ada@example.com",
        orgName: "North desk",
        role: "admin",
        inviterEmail: "hello@shamarrconnect.com",
        acceptUrl,
      }),
    },
    { id: "welcome", live: false, title: "Welcome", msg: welcomeEmail({ toEmail: "ada@example.com", displayName: "Ada" }) },
    { id: "password-reset", live: false, title: "Password reset", msg: passwordResetEmail({ toEmail: "ada@example.com", resetUrl, displayName: "Ada" }) },
    { id: "password-changed", live: false, title: "Password changed", msg: passwordChangedEmail({ toEmail: "ada@example.com", displayName: "Ada" }) },
    { id: "mfa-on", live: false, title: "MFA on", msg: mfaChangedEmail({ toEmail: "ada@example.com", enabled: true, displayName: "Ada" }) },
    { id: "mfa-off", live: false, title: "MFA off", msg: mfaChangedEmail({ toEmail: "ada@example.com", enabled: false, displayName: "Ada" }) },
    {
      id: "plan-activated",
      live: false,
      title: "Plan activated",
      msg: planActivatedEmail({
        toEmail: "ada@example.com",
        plan: "team",
        expires: "21 Oct 2026",
        amount: "₦15,000",
        currency: "",
        displayName: "Ada",
      }),
    },
    {
      id: "payment-failed",
      live: false,
      title: "Payment failed",
      msg: paymentFailedEmail({
        toEmail: "ada@example.com",
        plan: "team",
        expires: "21 Oct 2026",
        displayName: "Ada",
      }),
    },
    { id: "deletion-received", live: false, title: "Deletion received", msg: deletionReceivedEmail({ toEmail: "ada@example.com" }) },
    { id: "account-deleted", live: false, title: "Account deleted", msg: accountDeletedEmail({ toEmail: "ada@example.com" }) },
    {
      id: "unmatched-payment",
      live: false,
      title: "Unmatched payment (ops)",
      msg: unmatchedPaymentEmail({
        email: "ada@example.com",
        amount: "15000",
        currency: "NGN",
        provider: "paystack",
        plan: "team",
        ts,
      }),
    },
  ];
}

export function previewGalleryHtml() {
  const items = previewFixtures()
    .map((s) => {
      const badge = s.live ? "LIVE" : "UNWIRED";
      const badgeBg = s.live ? C.soft : C.line;
      const badgeFg = s.live ? C.ctaDk : C.muted;
      const srcdoc = escapeHtml(s.msg.htmlContent);
      return `<section id="${escapeHtml(s.id)}" style="margin:0 0 48px 0;">
        <div style="display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;margin:0 0 10px 0;">
          <span style="font-size:11px;font-weight:700;letter-spacing:0.08em;padding:4px 8px;border-radius:999px;background:${badgeBg};color:${badgeFg};">${badge}</span>
          <h2 style="margin:0;font-size:16px;font-weight:700;letter-spacing:-0.02em;">${escapeHtml(s.title)}</h2>
        </div>
        <p style="margin:0 0 12px 0;font-size:13px;color:${C.muted};">${escapeHtml(s.msg.subject)}</p>
        <iframe title="${escapeHtml(s.title)}" srcdoc="${srcdoc}" class="frame" style="width:100%;height:780px;border:1px solid ${C.line};background:${C.bg};border-radius:8px;"></iframe>
      </section>`;
    })
    .join("\n");

  const nav = previewFixtures()
    .map((s) => `<a href="#${escapeHtml(s.id)}">${escapeHtml(s.title)}</a>`)
    .join(" · ");

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex">
<title>Email preview · ShamarrConnect</title>
<style>
  :root { --ink:#0F1B33; --muted:#5A6B85; --line:#E6ECF5; --bg:#F4F6FB; --brand:#2B5CE6; }
  * { box-sizing: border-box; }
  body { margin:0; font-family:${FONT}; color:var(--ink); background:var(--bg); }
  .bar { position:sticky; top:0; z-index:2; background:#fff; border-bottom:1px solid var(--line); padding:12px 20px; display:flex; gap:12px; flex-wrap:wrap; align-items:center; }
  .bar strong { letter-spacing:-0.02em; }
  .bar button { font:inherit; font-size:13px; font-weight:600; padding:7px 12px; border-radius:999px; border:1px solid var(--line); background:#fff; color:var(--ink); cursor:pointer; }
  .bar button[aria-pressed="true"] { background:var(--brand); color:#fff; border-color:var(--brand); }
  .nav { font-size:13px; line-height:1.7; color:var(--muted); padding:16px 20px 0; }
  .nav a { color:var(--brand); text-decoration:none; }
  .wrap { padding:20px; max-width:640px; margin:0 auto; transition:max-width .15s ease; }
  body.phone .wrap { max-width:395px; }
  body.phone .frame { height:860px; }
</style>
</head>
<body>
  <div class="bar">
    <strong>Email preview</strong>
    <button type="button" id="desk" aria-pressed="true">Desktop</button>
    <button type="button" id="phone" aria-pressed="false">Phone 375</button>
  </div>
  <p class="nav">${nav}</p>
  <div class="wrap">${items}</div>
  <script>
    const desk = document.getElementById('desk');
    const phone = document.getElementById('phone');
    function setPhone(on) {
      document.body.classList.toggle('phone', on);
      desk.setAttribute('aria-pressed', on ? 'false' : 'true');
      phone.setAttribute('aria-pressed', on ? 'true' : 'false');
    }
    desk.onclick = function(){ setPhone(false); };
    phone.onclick = function(){ setPhone(true); };
  </script>
</body>
</html>`;
}
