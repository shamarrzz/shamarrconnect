// Waitlist capture for the pre-launch landing page.
// POST /api/waitlist  { "email": "...", "company": "<honeypot>" }
// Stores one KV entry per email (key = email, so duplicates overwrite for free).
// Binding: KV namespace bound as WAITLIST in the Pages project settings.
// If the binding is missing the endpoint returns 503 (fail loud in logs,
// generic message to the client).

const SEC = {
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Cache-Control": "no-store",
};

const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,253}\.[^\s@]{2,}$/;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...SEC },
  });
}

export async function onRequestPost({ request, env }) {
  if (!env.WAITLIST) {
    console.error("waitlist: WAITLIST KV binding missing");
    return json({ ok: false, error: "temporarily unavailable" }, 503);
  }

  let data;
  try {
    data = await request.json();
  } catch {
    return json({ ok: false, error: "bad request" }, 400);
  }

  // Honeypot: real users never fill the hidden "company" field.
  // Pretend success so bots learn nothing.
  if (data && typeof data.company === "string" && data.company !== "") {
    return json({ ok: true });
  }

  const email = String((data && data.email) || "").trim().toLowerCase();
  if (!EMAIL_RE.test(email)) {
    return json({ ok: false, error: "invalid email" }, 400);
  }

  try {
    await env.WAITLIST.put(
      email,
      JSON.stringify({ ts: new Date().toISOString(), src: "landing" })
    );
  } catch (e) {
    console.error("waitlist: KV put failed", e);
    return json({ ok: false, error: "temporarily unavailable" }, 503);
  }

  return json({ ok: true });
}

export async function onRequest() {
  return json({ ok: false, error: "method not allowed" }, 405);
}
