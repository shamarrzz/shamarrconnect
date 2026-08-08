// Shared access control for gated areas (/admin/*, /preview/*).
//
// Two layers, fail closed:
//   1) Cloudflare Access JWT (email OTP) — proves the visitor owns the mailbox.
//      Verified against the team's public keys here, so the area stays locked
//      even if the Zero Trust app is misconfigured or deleted.
//   2) Authorization allowlist — decides what the authenticated email may do:
//        owners  = env.ALLOWED_EMAILS (comma-separated, bootstrap; manage members)
//        members = KV entries "allow:<email>" in the WAITLIST namespace
//                  (added by owners from the admin page; download/preview access)
//      If the KV binding is missing or unreadable, members fail closed and
//      owners keep working.
//
// Env: ACCESS_TEAM (https://<team>.cloudflareaccess.com), ALLOWED_EMAILS,
//      WAITLIST (KV binding).

export function b64urlToBytes(s) {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
}

export async function verifyAccessJWT(token, team) {
  try {
    const [h, p, sig] = token.split(".");
    if (!h || !p || !sig) return null;
    const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(h)));
    const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(p)));
    const now = Math.floor(Date.now() / 1000);
    if (payload.iss !== team) return null;
    if (!payload.exp || payload.exp < now) return null;
    const res = await fetch(`${team}/cdn-cgi/access/certs`, {
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
    return valid ? (payload.email || "").toLowerCase() : null;
  } catch {
    return null;
  }
}

export function ownerEmails(env) {
  return (env.ALLOWED_EMAILS || "")
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
}

export async function memberEmails(env) {
  if (!env.WAITLIST) return [];
  try {
    const out = [];
    let cursor;
    do {
      const page = await env.WAITLIST.list({ prefix: "allow:", cursor });
      for (const k of page.keys) out.push(k.name.slice(6));
      cursor = page.list_complete ? null : page.cursor;
    } while (cursor);
    return out;
  } catch (e) {
    console.error("access: member list failed, failing closed", e);
    return [];
  }
}

// Returns { email, role } — role is "owner" | "member" | null (no access).
export async function resolveAccess(request, env) {
  const cookie = (request.headers.get("Cookie") || "").match(/CF_Authorization=([^;\s]+)/);
  const token = request.headers.get("Cf-Access-Jwt-Assertion") || (cookie && cookie[1]);
  const email = env.ACCESS_TEAM && token
    ? await verifyAccessJWT(token, env.ACCESS_TEAM)
    : null;
  if (!email) return { email: null, role: null };
  if (ownerEmails(env).includes(email)) return { email, role: "owner" };
  if ((await memberEmails(env)).includes(email)) return { email, role: "member" };
  return { email, role: null };
}
