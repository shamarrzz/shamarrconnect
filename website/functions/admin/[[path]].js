// Origin-level lock for /admin/*.
// 1) *.pages.dev never serves admin content (Access doesn't cover those hosts).
// 2) Every other host requires a VALID Cloudflare Access JWT (signature verified
//    against the team's public keys) — defense-in-depth so /admin stays locked
//    even if the Zero Trust app is misconfigured or deleted.
const TEAM = "https://your-team.cloudflareaccess.com";
const ALLOWED_EMAILS = ["hello@shamarrconnect.com"];

const SEC = {
  "X-Frame-Options": "DENY",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
  // connect-src allows the admin users panel to call the sc-cloud API.
  "Content-Security-Policy":
    "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src https://api.shamarrconnect.com; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; upgrade-insecure-requests",
};

function b64urlToBytes(s) {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
}

async function verifyAccessJWT(token) {
  try {
    const [h, p, sig] = token.split(".");
    if (!h || !p || !sig) return null;
    const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(h)));
    const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(p)));
    const now = Math.floor(Date.now() / 1000);
    if (payload.iss !== TEAM) return null;
    if (!payload.exp || payload.exp < now) return null;
    const res = await fetch(`${TEAM}/cdn-cgi/access/certs`, {
      cf: { cacheTtl: 3600, cacheEverything: true },
    });
    if (!res.ok) return null;
    const { keys } = await res.json();
    const jwk = (keys || []).find((k) => k.kid === header.kid);
    if (!jwk) return null;
    const key = await crypto.subtle.importKey(
      "jwk", jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false, ["verify"]
    );
    const valid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5", key,
      b64urlToBytes(sig),
      new TextEncoder().encode(`${h}.${p}`)
    );
    return valid ? payload.email : null;
  } catch {
    return null;
  }
}

export async function onRequest({ request, env }) {
  const url = new URL(request.url);
  if (url.hostname.endsWith(".pages.dev")) {
    return new Response("Not found", { status: 404, headers: SEC });
  }

  const cookie = (request.headers.get("Cookie") || "").match(/CF_Authorization=([^;\s]+)/);
  const token = request.headers.get("Cf-Access-Jwt-Assertion") || (cookie && cookie[1]);
  const email = token ? await verifyAccessJWT(token) : null;
  if (!email) {
    return new Response(
      "<!DOCTYPE html><title>Locked</title><h1>403 — admin is locked</h1>" +
      "<p>Sign in via Cloudflare Access first, then reload this page.</p>",
      { status: 403, headers: { "Content-Type": "text/html; charset=utf-8", ...SEC } }
    );
  }
  if (!ALLOWED_EMAILS.includes(email)) {
    return new Response(
      "<!DOCTYPE html><title>Forbidden</title><h1>403 — not authorised</h1>" +
      `<p>${email} does not have access to this area.</p>`,
      { status: 403, headers: { "Content-Type": "text/html; charset=utf-8", ...SEC } }
    );
  }

  const res = await env.ASSETS.fetch(request);
  const out = new Response(res.body, res);
  for (const [k, v] of Object.entries(SEC)) out.headers.set(k, v);
  // _headers does not apply to function-served responses; re-apply download headers.
  const name = url.pathname.split("/").pop();
  if (url.pathname.startsWith("/admin/get/") && name && name.includes(".")) {
    out.headers.set("Content-Type", "application/octet-stream");
    out.headers.set("Content-Disposition", `attachment; filename="${name}"`);
    out.headers.set("Cache-Control", "no-store");
  }
  return out;
}
