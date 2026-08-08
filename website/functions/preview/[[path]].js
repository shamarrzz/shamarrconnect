// Gate /preview/* at the origin.
// 1) *.pages.dev is blocked outright.
// 2) Requires a valid Cloudflare Access JWT from an allowlisted email —
//    owners (env.ALLOWED_EMAILS) or members (KV "allow:<email>", managed
//    from the admin page). Defense-in-depth so /preview stays locked even
//    if the Zero Trust app is misconfigured.
// If ACCESS_TEAM or ALLOWED_EMAILS is unset the area locks for EVERYONE
// (fail closed).

import { resolveAccess } from "../_lib/access.js";

const SEC = {
  "X-Frame-Options": "DENY",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
  "Content-Security-Policy":
    "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; upgrade-insecure-requests",
};

export async function onRequest({ request, env }) {
  const url = new URL(request.url);
  if (url.hostname.endsWith(".pages.dev")) {
    return new Response("Not found", { status: 404, headers: SEC });
  }

  const { email, role } = await resolveAccess(request, env);
  if (!email) {
    return new Response(
      "<!DOCTYPE html><title>Locked</title><h1>403: preview is locked</h1>" +
      "<p>Sign in via Cloudflare Access first, then reload this page.</p>",
      { status: 403, headers: { "Content-Type": "text/html; charset=utf-8", ...SEC } }
    );
  }
  if (!role) {
    return new Response(
      "<!DOCTYPE html><title>Forbidden</title><h1>403: not authorised</h1>" +
      `<p>${email} does not have access to this area. Ask an owner to add you from the admin page.</p>`,
      { status: 403, headers: { "Content-Type": "text/html; charset=utf-8", ...SEC } }
    );
  }

  const res = await env.ASSETS.fetch(request);
  const out = new Response(res.body, res);
  for (const [k, v] of Object.entries(SEC)) out.headers.set(k, v);
  return out;
}
