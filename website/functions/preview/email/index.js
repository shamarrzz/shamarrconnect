// GET /preview/email — gallery of transactional templates.
// Same Access gate as the rest of /preview/*. HTML is rendered from
// functions/_lib/email.js so the preview cannot drift from senders.

import { resolveAccess } from "../../_lib/access.js";
import { previewGalleryHtml } from "../../_lib/email.js";

const SEC = {
  "X-Frame-Options": "DENY",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
  "Cache-Control": "no-store",
  "Content-Security-Policy":
    "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://shamarrconnect.com; font-src 'self'; child-src 'self' blob:; frame-src 'self' blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'none';",
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

  return new Response(previewGalleryHtml(), {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8", ...SEC },
  });
}
