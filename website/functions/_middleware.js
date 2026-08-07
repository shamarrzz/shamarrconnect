// Two jobs:
//
// 1) Launch gate for /download/*.
//    Until LAUNCH_OPEN=1 is set in the Pages project env (Production + Preview),
//    /download is closed: visitors get a styled 403 pointing at the waitlist and
//    the /beta invite page. Beta testers keep using the CF Access-gated
//    /admin/get/ path, which this middleware does not touch.
//    Fail closed: if LAUNCH_OPEN is unset or anything else, the gate stays shut.
//
// 2) Region split for every HTML page (pricing, landing, ...).
//    Cloudflare adds the visitor country to every request (request.cf.country,
//    free, no third-party GeoIP). NG visitors get the "ng" region (Naira pricing
//    via Paystack), everyone else gets "intl" (USD via the international rail).
//    There is deliberately no manual currency switcher: NGN prices are
//    PPP-discounted and foreign cards can pay NGN on Paystack, so a picker
//    would invite arbitrage. Wrong-region edge cases go through support.
//
//    Mechanism:
//    - injects <script>window.SC_REGION="ng|intl"</script> at the top of <head>
//      (page JS reads it before first paint, no currency flash)
//    - removes every element whose data-region attribute does not match
//      (copy blocks carry data-region="ng" / data-region="intl" variants)
//    - for ng, rewrites the pricing page's default (annual) price text from
//      the data-y-ngn attributes so even the pre-JS HTML is Naira
//    - sets X-SC-Region on the response so the split is curl-verifiable
//
//    Default is "intl" when cf.country is missing (bots, local dev, Tor).

const SEC = {
  "X-Frame-Options": "DENY",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
  "Content-Security-Policy":
    "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; upgrade-insecure-requests",
};

const CLOSED_PAGE = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Downloads are invite-only - ShamarrConnect</title>
<meta name="robots" content="noindex">
<link rel="icon" type="image/svg+xml" href="/favicon.svg">
<style>
  :root{--brand:#2B5CE6;--ink:#0F1B33;--muted:#5A6B85;--line:#E6ECF5}
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:Arial,Helvetica,sans-serif;color:var(--ink);
    min-height:100vh;display:grid;place-items:center;text-align:center;
    background:radial-gradient(1000px 500px at 50% -10%, #F1F0FF 0%, transparent 60%),linear-gradient(180deg,#F6F9FF,#FFFFFF)}
  .box{padding:40px 28px;max-width:560px}
  .eyebrow{display:inline-flex;align-items:center;gap:8px;background:#EAF0FF;color:#1E3FA8;
    font-weight:600;font-size:13px;padding:7px 15px;border-radius:100px;margin-bottom:24px}
  h1{font-size:32px;line-height:1.2;letter-spacing:-.02em;font-weight:800;margin-bottom:16px}
  p{font-size:16px;color:var(--muted);max-width:440px;margin:0 auto 24px}
  .btn{display:inline-flex;align-items:center;background:var(--brand);color:#fff!important;
    font-weight:700;font-size:14px;padding:12px 20px;border-radius:11px;text-decoration:none}
  .btn:hover{background:#1E3FA8}
  .alt{margin-top:18px;font-size:14px;color:var(--muted)}
  .alt a{color:var(--brand);font-weight:600}
</style>
</head>
<body>
  <div class="box">
    <span class="eyebrow">Private beta</span>
    <h1>Downloads are invite-only<br>for now.</h1>
    <p>ShamarrConnect is in private beta. Public downloads open at launch.
       Leave your email and we'll tell you the moment they're live.</p>
    <a class="btn" href="/#waitlist">Notify me at launch</a>
    <p class="alt">Invited to the beta? Your onboarding guide is at
       <a href="/beta">/beta</a>.</p>
  </div>
</body>
</html>`;

function regionOf(request) {
  try {
    return request.cf && request.cf.country === "NG" ? "ng" : "intl";
  } catch (e) {
    return "intl";
  }
}

class InjectRegion {
  constructor(region) {
    this.region = region;
  }
  element(el) {
    el.prepend(`<script>window.SC_REGION=${JSON.stringify(this.region)};</script>`, {
      html: true,
    });
  }
}

class StripRegion {
  constructor(region) {
    this.region = region;
  }
  element(el) {
    if (el.getAttribute("data-region") !== this.region) el.remove();
    else el.removeAttribute("data-region");
  }
}

class NgPriceText {
  element(el) {
    const v = el.getAttribute("data-y-ngn");
    if (v) el.setInnerContent(v);
  }
}

class NgSymbol {
  element(el) {
    el.setInnerContent("₦");
  }
}

function regionalize(request, res) {
  const ct = res.headers.get("content-type") || "";
  if (!ct.includes("text/html")) return res;
  const region = regionOf(request);
  let rw = new HTMLRewriter()
    .on("head", new InjectRegion(region))
    .on("[data-region]", new StripRegion(region));
  if (region === "ng") {
    rw = rw
      .on(".amt[data-y-ngn]", new NgPriceText())
      .on(".billed[data-y-ngn]", new NgPriceText())
      .on(".cur.sym", new NgSymbol());
  }
  const out = rw.transform(res);
  out.headers.set("X-SC-Region", region);
  return out;
}

export async function onRequest({ request, env, next }) {
  const url = new URL(request.url);
  if (url.pathname === "/download" || url.pathname.startsWith("/download/")) {
    if (env.LAUNCH_OPEN !== "1") {
      return new Response(CLOSED_PAGE, {
        status: 403,
        headers: { "Content-Type": "text/html; charset=utf-8", ...SEC },
      });
    }
  }
  const res = await next();
  return regionalize(request, res);
}
