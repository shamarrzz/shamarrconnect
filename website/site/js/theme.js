/* Same choice as the landing page. An explicit sc-theme wins; otherwise follow the OS, live. */
(function () {
  var root = document.documentElement;
  var KEY = "sc-theme";
  var mq = window.matchMedia("(prefers-color-scheme: dark)");
  root.classList.add("js");
  try { localStorage.removeItem("sc-landing-theme"); } catch (e) {}
  function stored() {
    try {
      var v = localStorage.getItem(KEY);
      return v === "light" || v === "dark" ? v : null;
    } catch (e) {
      return null;
    }
  }
  function apply() {
    var s = stored();
    var dark = s ? s === "dark" : mq.matches;
    root.classList.toggle("dark", dark);
    root.setAttribute("data-theme-source", s ? "user" : "os");
    try {
      document.dispatchEvent(new CustomEvent("sc-themechange", {
        detail: { dark: dark, source: s ? "user" : "os" }
      }));
    } catch (e) {}
  }
  window.scTheme = {
    apply: apply,
    set: function (dark) {
      try { localStorage.setItem(KEY, dark ? "dark" : "light"); } catch (e) {}
      apply();
    },
    followOS: function () {
      try { localStorage.removeItem(KEY); } catch (e) {}
      apply();
    }
  };
  apply();
  if (mq.addEventListener) mq.addEventListener("change", apply);
  else if (mq.addListener) mq.addListener(apply);
  window.addEventListener("storage", function (e) { if (e.key === KEY) apply(); });

  function syncThemeBtn() {
    var themeBtn = document.getElementById("theme-switch");
    if (!themeBtn) return;
    var dark = root.classList.contains("dark");
    themeBtn.setAttribute("aria-pressed", dark ? "true" : "false");
    var lab = themeBtn.querySelector(".theme-label");
    if (lab) lab.textContent = dark ? "Dark" : "Light";
    themeBtn.title = dark ? "Switch to light" : "Switch to dark";
  }
  function bind() {
    var themeBtn = document.getElementById("theme-switch");
    syncThemeBtn();
    if (!themeBtn || themeBtn.dataset.bound === "1") return;
    themeBtn.dataset.bound = "1";
    themeBtn.addEventListener("click", function () {
      window.scTheme.set(!root.classList.contains("dark"));
    });
    document.addEventListener("sc-themechange", syncThemeBtn);
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", bind);
  else bind();
})();
