// Transactional email via Brevo (HTTP API — Workers cannot do raw SMTP).
// env.BREVO_API_KEY must be set as a Pages secret. Missing key = skip
// silently (waitlist storage must never fail because email did).

const BREVO_URL = "https://api.brevo.com/v3/smtp/email";
const SENDER = { name: "ShamarrConnect", email: "hello@shamarrconnect.com" };
const WORDMARK = "https://shamarrconnect.com/wordmark-2x.png";

async function sendBrevo(env, msg) {
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

// Shared shell: 600px card, brand header, legal footer. Inline CSS only,
// table layout, no external fonts, no SVG — email-client safe.
function shell(preheader, bodyHtml) {
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><title>ShamarrConnect</title></head>
<body style="margin:0;padding:0;background:#F8FAFF;">
<div style="display:none;max-height:0;overflow:hidden;mso-hide:all;">${preheader}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F8FAFF;"><tr><td align="center" style="padding:32px 16px;">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#FFFFFF;border:1px solid #E6ECF5;border-radius:16px;overflow:hidden;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#0F1B33;">
  <tr><td style="padding:28px 32px 20px;border-bottom:1px solid #E6ECF5;">
    <img src="${WORDMARK}" width="220" height="25" alt="ShamarrConnect" style="display:block;height:25px;width:220px;">
  </td></tr>
  <tr><td style="padding:32px;font-size:16px;line-height:1.65;color:#26344D;">
    ${bodyHtml}
  </td></tr>
  <tr><td style="padding:20px 32px 28px;border-top:1px solid #E6ECF5;font-size:12px;line-height:1.6;color:#5A6B85;">
    ShamarrConnect · support@shamarrconnect.com<br>
    <a href="https://shamarrconnect.com/privacy" style="color:#2B5CE6;text-decoration:none;">Privacy</a> ·
    <a href="https://shamarrconnect.com/terms" style="color:#2B5CE6;text-decoration:none;">Terms</a> ·
    <a href="https://shamarrconnect.com/refund" style="color:#2B5CE6;text-decoration:none;">Refunds</a>
  </td></tr>
</table>
</td></tr></table>
</body></html>`;
}

// ── Subscriber confirmation ─────────────────────────────────────────────
export function waitlistConfirm(email, region) {
  const money = region === "ng"
    ? "Launch plans start from local pricing in your region."
    : "Launch plans start from $9/month.";
  const html = shell("You're on the ShamarrConnect launch list.", `
    <h1 style="margin:0 0 14px;font-size:24px;line-height:1.25;letter-spacing:-0.02em;color:#0F1B33;">You're on the list.</h1>
    <p style="margin:0 0 14px;">Thanks for your interest in ShamarrConnect — hosted remote desktop that is private by design and run for you. We'll email this address the moment doors open.</p>
    <p style="margin:0 0 14px;">${money} Early members hear first, and there will be a thank-you for the people who believed early.</p>
    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:22px 0 6px;"><tr><td style="background:#2B5CE6;border-radius:12px;">
      <a href="https://shamarrconnect.com" style="display:inline-block;padding:12px 24px;color:#FFFFFF;font-weight:600;font-size:15px;text-decoration:none;">See what ShamarrConnect does</a>
    </td></tr></table>
    <p style="margin:18px 0 0;font-size:13px;color:#5A6B85;">You signed up with ${email}. If that wasn't you, just ignore this email — nothing else happens.</p>`);
  const text = `You're on the ShamarrConnect launch list.\n\nWe'll email ${email} the moment doors open. ${money}\n\nhttps://shamarrconnect.com\n\nIf this wasn't you, ignore this email.`;
  return {
    to: [{ email }],
    subject: "You're on the ShamarrConnect list",
    htmlContent: html,
    textContent: text,
  };
}

// ── Owner notification (reply goes straight to the subscriber) ──────────
export function waitlistNotify(email, region, ts) {
  const html = shell(`New waitlist signup: ${email}`, `
    <h1 style="margin:0 0 14px;font-size:20px;color:#0F1B33;">New waitlist signup</h1>
    <table role="presentation" cellpadding="0" cellspacing="0" style="font-size:15px;">
      <tr><td style="padding:4px 16px 4px 0;color:#5A6B85;">Email</td><td style="padding:4px 0;font-weight:600;">${email}</td></tr>
      <tr><td style="padding:4px 16px 4px 0;color:#5A6B85;">Region</td><td style="padding:4px 0;">${region === "ng" ? "NG pricing" : "INTL pricing"}</td></tr>
      <tr><td style="padding:4px 16px 4px 0;color:#5A6B85;">Time</td><td style="padding:4px 0;">${ts}</td></tr>
    </table>
    <p style="margin:18px 0 0;font-size:13px;color:#5A6B85;">Hit reply to write back — replies go straight to ${email}.</p>`);
  return {
    to: [{ email: "hello@shamarrconnect.com" }],
    replyTo: { email },
    subject: `New waitlist signup: ${email}`,
    htmlContent: html,
    textContent: `New waitlist signup\nEmail: ${email}\nRegion: ${region}\nTime: ${ts}\nReply to this email to reach them directly.`,
  };
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
