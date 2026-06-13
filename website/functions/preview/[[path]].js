// Gate /preview/* at the origin. Cloudflare Access only protects the custom domain;
// *.pages.dev would otherwise serve these paths with no login.
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
  const res = await env.ASSETS.fetch(request);
  const out = new Response(res.body, res);
  for (const [k, v] of Object.entries(SEC)) out.headers.set(k, v);
  return out;
}
