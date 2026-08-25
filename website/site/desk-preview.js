/* Interactive desk playground for /preview/desk — no ShamarrConnect account. */
(function () {
  var stage = document.getElementById("desk-app");
  if (!stage) return;

  var grid = document.getElementById("desk-grid");
  var chromeWho = document.getElementById("desk-who");
  var sheet = document.getElementById("desk-sheet");
  var panel = document.getElementById("desk-panel");
  var status = document.getElementById("desk-status");
  var sceneBtns = document.querySelectorAll("[data-scene]");
  var current = "ready";

  var OS = {
    win:
      '<svg class="os" viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3" y="5" width="8" height="8" rx="1" stroke="#5A6B85" stroke-width="1.6"/><rect x="13" y="5" width="8" height="8" rx="1" stroke="#5A6B85" stroke-width="1.6"/><rect x="3" y="15" width="8" height="5" rx="1" stroke="#5A6B85" stroke-width="1.6"/><rect x="13" y="15" width="8" height="5" rx="1" stroke="#5A6B85" stroke-width="1.6"/></svg>',
    linux:
      '<svg class="os" viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3" y="6" width="18" height="12" rx="2" stroke="#5A6B85" stroke-width="1.6"/><path d="M7 10l3 2-3 2M12 14h5" stroke="#5A6B85" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    phone:
      '<svg class="os" viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="7" y="2" width="10" height="20" rx="2" stroke="#5A6B85" stroke-width="1.6"/><path d="M11 18h2" stroke="#5A6B85" stroke-width="1.6" stroke-linecap="round"/></svg>',
  };

  function card(opts) {
    var light = opts.light || "awake";
    var badge = opts.badge
      ? ' <span class="badge">' + opts.badge + "</span>"
      : "";
    var actClass = opts.actClass || "act";
    return (
      '<div class="dcard' +
      (opts.cls ? " " + opts.cls : "") +
      '">' +
      '<div class="top"><span class="light ' +
      light +
      '" aria-hidden="true"></span><div class="names"><div class="place">' +
      opts.place +
      badge +
      "</div></div>" +
      (opts.os || "") +
      "</div>" +
      '<p class="sentence">' +
      opts.sentence +
      "</p>" +
      '<button class="' +
      actClass +
      '" type="button" data-desk="' +
      opts.action +
      '">' +
      opts.label +
      "</button></div>"
    );
  }

  function slot() {
    return (
      '<button class="dcard is-slot" type="button" data-desk="add" aria-label="Add a new computer">' +
      "+ Add a new computer</button>"
    );
  }

  var scenes = {
    out: {
      who: "Not signed in",
      one: true,
      html:
        card({
          cls: "is-this",
          place: "This computer",
          badge: "Here",
          os: OS.phone,
          light: "awake",
          sentence: "Share this screen, or sign in to see your other computers.",
          action: "share",
          label: "Share",
          actClass: "act share",
        }) +
        '<div class="dcard" style="justify-content:center;align-items:stretch">' +
        '<p class="sentence" style="margin:0 0 8px">Your other computers appear here after you sign in.</p>' +
        '<button class="act" type="button" data-desk="signin">Sign in</button></div>',
    },
    ready: {
      who: "you",
      html:
        card({
          cls: "is-this",
          place: "This computer",
          badge: "Here",
          os: OS.win,
          sentence: "This is the computer you're on.",
          action: "share",
          label: "Share",
          actClass: "act share",
        }) +
        card({
          place: "Shop POS",
          os: OS.win,
          sentence: "Online. You can open it.",
          action: "sit-shop",
          label: "Open",
        }) +
        card({
          place: "Office PC",
          os: OS.linux,
          light: "asleep",
          sentence: "Last seen this morning.",
          action: "sit-office",
          label: "Open",
          actClass: "act ghost",
        }) +
        slot(),
    },
    battery: {
      who: "you",
      html:
        card({
          cls: "is-this",
          place: "This computer",
          badge: "Here",
          os: OS.win,
          sentence: "This is the computer you're on.",
          action: "share",
          label: "Share",
          actClass: "act share",
        }) +
        card({
          place: "Shop POS",
          os: OS.phone,
          light: "warn",
          sentence: "Can't reach it. The phone closed the app.",
          action: "sit-battery",
          label: "Open",
          actClass: "act ghost",
        }) +
        card({
          place: "Home laptop",
          os: OS.linux,
          sentence: "Online. You can open it.",
          action: "sit-home",
          label: "Open",
        }) +
        slot(),
    },
    setup: {
      who: "you",
      one: true,
      html:
        card({
          cls: "is-this",
          place: "This computer",
          badge: "Here",
          os: OS.phone,
          light: "warn",
          sentence: "Almost ready. This computer still needs a permission.",
          action: "setup",
          label: "Continue setup",
        }) +
        card({
          place: "Office PC",
          os: OS.win,
          sentence: "Online. You can open it.",
          action: "sit-office-ready",
          label: "Open",
        }),
    },
  };

  function setStatus(text) {
    if (status) status.textContent = text;
  }

  function closeSheet() {
    if (sheet) sheet.hidden = true;
  }

  function openSheet(html) {
    panel.innerHTML = html;
    sheet.hidden = false;
    var focus = panel.querySelector("button, input");
    if (focus) focus.focus();
  }

  function render(name) {
    current = name;
    var s = scenes[name] || scenes.ready;
    chromeWho.textContent = s.who;
    grid.className = "desk-grid" + (s.one ? " one" : "");
    grid.innerHTML = s.html;
    sceneBtns.forEach(function (b) {
      var on = b.getAttribute("data-scene") === name;
      b.setAttribute("aria-pressed", on ? "true" : "false");
      b.classList.toggle("on", on);
    });
    closeSheet();
    setStatus("Status updates as each computer checks in.");
  }

  function explain(title, body, tryAct) {
    openSheet(
      "<h3>" +
        title +
        "</h3><p>" +
        body +
        "</p>" +
        '<div class="actions">' +
        (tryAct
          ? '<button class="act" type="button" data-desk="' +
            tryAct +
            '">Try anyway</button>'
          : "") +
        '<button class="act ghost" type="button" data-desk="close">Close</button></div>'
    );
  }

  stage.addEventListener("click", function (e) {
    var btn = e.target.closest("[data-desk]");
    if (!btn) return;
    var act = btn.getAttribute("data-desk");
    if (act === "sit-shop" || act === "sit-home" || act === "sit-office-ready") {
      closeSheet();
      var place =
        act === "sit-shop"
          ? "Shop POS"
          : act === "sit-home"
            ? "Home laptop"
            : "Office PC";
      setStatus("You're on " + place + ".");
    } else if (act === "sit-office") {
      explain(
        "Office PC",
        "Last seen this morning. Open ShamarrConnect on that computer, or turn it on. Then you can open it from here.",
        "try-office"
      );
    } else if (act === "sit-battery") {
      explain(
        "Shop POS",
        "The phone closed the app. Open ShamarrConnect there. On Samsung, set battery to Unrestricted so it stays reachable.",
        "try-shop"
      );
    } else if (act === "try-office") {
      closeSheet();
      setStatus("Trying Office PC. Last seen this morning.");
    } else if (act === "try-shop") {
      closeSheet();
      setStatus("Trying Shop POS. The phone may still have closed the app.");
    } else if (act === "share") {
      openSheet(
        "<h3>Share this computer</h3>" +
          "<p>Only share these with someone you trust. A session starts after you accept it.</p>" +
          '<div class="desk-secret"><div class="lbl">Your ID</div><div class="val">812 345 678</div></div>' +
          '<div class="desk-secret"><div class="lbl">One-time password</div><div class="val">k7p2n9</div></div>' +
          '<div class="actions"><button class="act ghost" type="button" data-desk="close">Close</button></div>'
      );
    } else if (act === "connect-id") {
      openSheet(
        "<h3>Connect by ID</h3>" +
          "<p>For a computer that is not on your desk yet.</p>" +
          '<div class="desk-idrow"><input type="text" inputmode="numeric" autocomplete="off" placeholder="Nine-digit ID" aria-label="Nine-digit ID"></div>' +
          '<div class="actions"><button class="act" type="button" data-desk="id-go">Connect</button>' +
          '<button class="act ghost" type="button" data-desk="close">Close</button></div>'
      );
    } else if (act === "id-go") {
      closeSheet();
      setStatus("That's for a computer that isn't on your list yet.");
    } else if (act === "add") {
      openSheet(
        "<h3>Add a new computer</h3>" +
          "<p>On that computer, open ShamarrConnect and enter this code.</p>" +
          '<div class="desk-secret"><div class="lbl">Code</div><div class="val">K7P2N9</div></div>' +
          "<p>Name it when it shows up: Office, Shop, Home.</p>" +
          '<div class="actions">' +
          '<button class="act ghost" type="button" data-desk="close">Close</button></div>'
      );
    } else if (act === "named") {
      closeSheet();
      setStatus("This computer is now \"" + btn.textContent.trim() + "\".");
    } else if (act === "setup") {
      explain(
        "A quick setup",
        "Still needed: stay reachable in the background. We walk you through one step at a time. You do not need Settings for this.",
        null
      );
    } else if (act === "signin") {
      setStatus("Sign in to see your other computers.");
    } else if (act === "close") {
      closeSheet();
    }
  });

  sheet.addEventListener("click", function (e) {
    if (e.target === sheet) closeSheet();
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") closeSheet();
  });

  sceneBtns.forEach(function (b) {
    b.addEventListener("click", function () {
      render(b.getAttribute("data-scene"));
    });
  });

  render("ready");
})();
