// Origin-level lock + team management for /admin/*.
// 1) *.pages.dev never serves admin content (Access doesn't cover those hosts).
// 2) Every other host requires a VALID Cloudflare Access JWT (verified in
//    _lib/access.js) plus an allowlisted email:
//      owners  (env.ALLOWED_EMAILS) — full access + member management API
//      members (KV "allow:<email>") — downloads and pages, no management
// 3) Owner-only JSON API:
//      GET    /admin/api/access    → { owners, members }
//      POST   /admin/api/access    { email } → add member
//      DELETE /admin/api/access    { email } → remove member
//      GET    /admin/api/waitlist  → { entries: [{email, ts, src}] }
// 4) /admin/get/<file> serves gated downloads; large APKs are streamed from
//    the public releases repo through this gate (allowlisted filenames).
// If ACCESS_TEAM or ALLOWED_EMAILS is unset the area locks for EVERYONE
// (fail closed).

import { resolveAccess, ownerEmails, memberEmails } from "../_lib/access.js";

const SEC = {
  "X-Frame-Options": "DENY",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
  // connect-src: same-origin management API + the sc-cloud users panel.
  "Content-Security-Policy":
    "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' https://api.shamarrconnect.com; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; upgrade-insecure-requests",
};

const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,253}\.[^\s@]{2,}$/;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store", ...SEC },
  });
}

function locked() {
  return new Response(
    "<!DOCTYPE html><title>Locked</title><h1>403: admin is locked</h1>" +
    "<p>Sign in via Cloudflare Access first, then reload this page.</p>",
    { status: 403, headers: { "Content-Type": "text/html; charset=utf-8", ...SEC } }
  );
}

async function apiAccess(request, env) {
  if (request.method === "GET") {
    return json({ owners: ownerEmails(env), members: await memberEmails(env) });
  }
  if (!env.WAITLIST) return json({ ok: false, error: "storage unavailable" }, 503);

  let data;
  try { data = await request.json(); } catch { return json({ ok: false, error: "bad request" }, 400); }
  const email = String((data && data.email) || "").trim().toLowerCase();
  if (!EMAIL_RE.test(email)) return json({ ok: false, error: "invalid email" }, 400);

  if (request.method === "POST") {
    if (ownerEmails(env).includes(email)) return json({ ok: true, already: "owner" });
    await env.WAITLIST.put(`allow:${email}`,
      JSON.stringify({ ts: new Date().toISOString(), src: "admin" }));
    console.error(`access: member added ${email}`);
    return json({ ok: true });
  }
  if (request.method === "DELETE") {
    await env.WAITLIST.delete(`allow:${email}`);
    console.error(`access: member removed ${email}`);
    return json({ ok: true });
  }
  return json({ ok: false, error: "method not allowed" }, 405);
}

async function apiWaitlist(env) {
  if (!env.WAITLIST) return json({ ok: false, error: "storage unavailable" }, 503);
  const entries = [];
  let cursor;
  try {
    do {
      const page = await env.WAITLIST.list({ cursor });
      for (const k of page.keys) {
        if (k.name.startsWith("allow:")) continue;
        let meta = {};
        try { meta = JSON.parse((await env.WAITLIST.get(k.name)) || "{}"); } catch {}
        entries.push({ email: k.name, ts: meta.ts || null, src: meta.src || null });
      }
      cursor = page.list_complete ? null : page.cursor;
    } while (cursor);
  } catch (e) {
    console.error("waitlist: list failed", e);
    return json({ ok: false, error: "storage unavailable" }, 503);
  }
  entries.sort((a, b) => String(b.ts).localeCompare(String(a.ts)));
  return json({ entries });
}

export async function onRequest({ request, env }) {
  const url = new URL(request.url);
  if (url.hostname.endsWith(".pages.dev")) {
    return new Response("Not found", { status: 404, headers: SEC });
  }

  const { email, role } = await resolveAccess(request, env);
  if (!email) return locked();
  if (!role) {
    return new Response(
      "<!DOCTYPE html><title>Forbidden</title><h1>403: not authorised</h1>" +
      `<p>${email} does not have access to this area. Ask an owner to add you from the admin page.</p>`,
      { status: 403, headers: { "Content-Type": "text/html; charset=utf-8", ...SEC } }
    );
  }

  // Owner-only management API.
  if (url.pathname === "/admin/api/access") {
    if (role !== "owner") return json({ ok: false, error: "owners only" }, 403);
    return apiAccess(request, env);
  }
  if (url.pathname === "/admin/api/waitlist") {
    if (role !== "owner") return json({ ok: false, error: "owners only" }, 403);
    if (request.method !== "GET") return json({ ok: false, error: "method not allowed" }, 405);
    return apiWaitlist(env);
  }

  const name = url.pathname.split("/").pop();

  // Large binaries (APKs exceed the 25 MiB Pages asset limit) are streamed
  // from the public releases repo THROUGH this gate: the Access check above
  // has already passed, so the gate holds; the upstream URL is never
  // published. Allowlist exact filenames so this can never become an open
  // proxy.
  const RELEASE_TAG = "1.4.9-sc1";
  const PROXIED = [
    `ShamarrConnect-${RELEASE_TAG}-aarch64.apk`,
    `ShamarrConnect-${RELEASE_TAG}-armv7.apk`,
    `ShamarrConnect-${RELEASE_TAG}-x86_64.apk`,
  ];
  if (url.pathname === `/admin/get/${name}` && PROXIED.includes(name)) {
    const up = await fetch(
      `https://github.com/shamarrzz/shamarrconnect-releases/releases/download/${RELEASE_TAG}/${name}`,
      { redirect: "follow" }
    );
    if (!up.ok || !up.body) {
      return new Response("Upstream release asset unavailable", { status: 502, headers: SEC });
    }
    const out = new Response(up.body, { status: 200 });
    for (const [k, v] of Object.entries(SEC)) out.headers.set(k, v);
    out.headers.set("Content-Type", "application/vnd.android.package-archive");
    out.headers.set("Content-Disposition", `attachment; filename="${name}"`);
    out.headers.set("Cache-Control", "no-store");
    if (up.headers.get("content-length")) {
      out.headers.set("Content-Length", up.headers.get("content-length"));
    }
    return out;
  }

  const res = await env.ASSETS.fetch(request);
  const out = new Response(res.body, res);
  for (const [k, v] of Object.entries(SEC)) out.headers.set(k, v);
  // _headers does not apply to function-served responses; re-apply download headers.
  if (url.pathname.startsWith("/admin/get/") && name && name.includes(".")) {
    out.headers.set("Content-Type", "application/octet-stream");
    out.headers.set("Content-Disposition", `attachment; filename="${name}"`);
    out.headers.set("Cache-Control", "no-store");
  }
  return out;
}
