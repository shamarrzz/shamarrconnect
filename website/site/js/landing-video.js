/* ShamarrConnect landing loops: lazy, theme-aware, reduced-motion-safe.
   Plain JS, no dependencies. Works with the site CSP (script-src 'self').
   Markup it expects (one per clip):
     <video class="sc-loop" data-clip="l3-permissions" width="1600" height="1000"
            muted loop playsinline preload="none" disablepictureinpicture
            poster="/media/landing/l3-permissions.dark.poster.webp"
            aria-hidden="true" tabindex="-1"></video>
   Theme source of truth: the "dark" class on <html> (what the site's theme
   switch already sets). The OS setting is read through matchMedia with a
   change listener. */
(function () {
  'use strict';
  var BASE = window.SC_LOOP_BASE || '/media/landing/';  // change if you put the files elsewhere
  var VP9_P0 = 'video/webm; codecs="vp09.00.40.08"';
  var VP9_P1 = 'video/webm; codecs="vp09.01.40.08"';
  var MP4 = 'video/mp4; codecs="avc1.640028"';
  // WebM type per clip/theme (from manifest.json). Profile 1 files carry their
  // own codec string so Safari etc. skip them and play the MP4.
  var WEBM = {
    'l1-device-list':    { light: VP9_P1, dark: VP9_P1 },
    'l1-open-device':    { light: VP9_P0, dark: VP9_P0 },
    'l3-permissions':    { light: VP9_P1, dark: VP9_P1 },
    'l3b-file-transfer': { light: VP9_P1, dark: VP9_P1 },
    'l3b-view-mode':     { light: VP9_P1, dark: VP9_P0 },
    'l4-shield':         { light: VP9_P0, dark: VP9_P0 },
    'l5-quality':        { light: VP9_P1, dark: VP9_P0 }
  };

  var root = document.documentElement;
  var mqDark = window.matchMedia('(prefers-color-scheme: dark)');
  var mqReduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  var videos = [].slice.call(document.querySelectorAll('video.sc-loop[data-clip]'));
  if (!videos.length) return;

  function theme() { return root.classList.contains('dark') ? 'dark' : 'light'; }
  // Same filenames as the 27 Sep pack. Dark l1-open-device was replaced
  // 2026-10-02, and /media/landing is cached for a week, so this query
  // is what makes browsers fetch the new bytes.
  var REV = { 'l1-open-device': { dark: '20261002' } };
  function url(clip, th, ext) {
    var rev = REV[clip] && REV[clip][th];
    return BASE + clip + '.' + th + '.' + ext + (rev ? '?v=' + rev : '');
  }

  function setSources(v, th) {
    var clip = v.getAttribute('data-clip');
    var t = WEBM[clip] ? WEBM[clip][th] : VP9_P0;
    while (v.firstChild) v.removeChild(v.firstChild);
    [[url(clip, th, 'webm'), t], [url(clip, th, 'mp4'), MP4]].forEach(function (s) {
      var el = document.createElement('source');
      el.src = s[0]; el.type = s[1];
      v.appendChild(el);
    });
  }

  function apply(v) {
    var th = theme();
    var clip = v.getAttribute('data-clip');
    v.poster = url(clip, th, 'poster.webp');
    if (mqReduce.matches) {                 // reduced motion: poster only
      if (v.dataset.th) { v.pause(); while (v.firstChild) v.removeChild(v.firstChild); v.removeAttribute('src'); v.load(); delete v.dataset.th; }
      return;
    }
    if (v.dataset.visible !== '1' && !v.dataset.th) return;   // not loaded yet: wait
    if (v.dataset.th === th) return;
    var frac = (v.duration && v.currentTime) ? v.currentTime / v.duration : 0;
    var wasLoaded = !!v.dataset.th;
    v.dataset.th = th;
    setSources(v, th);
    v.load();
    if (wasLoaded && frac) v.addEventListener('loadedmetadata', function once() {
      v.removeEventListener('loadedmetadata', once);
      try { v.currentTime = frac * v.duration; } catch (e) {}
    });
    if (v.dataset.visible === '1') play(v);
  }

  function play(v) {
    if (mqReduce.matches || document.hidden) return;
    v.muted = true;                                   // required for autoplay
    var p = v.play();
    if (p && p.catch) p.catch(function () { /* autoplay blocked (e.g. Low Power Mode): poster stays */ });
  }

  function applyAll() { videos.forEach(apply); }

  videos.forEach(function (v) {
    v.muted = true; v.loop = true; v.playsInline = true;
    v.setAttribute('playsinline', ''); v.preload = 'none';
    v.poster = url(v.getAttribute('data-clip'), theme(), 'poster.webp');
  });

  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        var v = en.target;
        v.dataset.visible = en.isIntersecting ? '1' : '0';
        if (en.isIntersecting) { apply(v); play(v); }
        else if (!v.paused) v.pause();                // pause off-screen
      });
    }, { rootMargin: '200px 0px', threshold: 0.25 });
    videos.forEach(function (v) { io.observe(v); });
  } else {
    videos.forEach(function (v) { v.dataset.visible = '1'; apply(v); play(v); });
  }

  // Theme changes: the site's switch toggles html.dark; OS changes via matchMedia.
  new MutationObserver(applyAll).observe(root, { attributes: true, attributeFilter: ['class'] });
  function onMq(mq, fn) { mq.addEventListener ? mq.addEventListener('change', fn) : mq.addListener(fn); }
  onMq(mqDark, function () { setTimeout(applyAll, 0); }); // theme script updates the class first
  onMq(mqReduce, function () {
    videos.forEach(function (v) { apply(v); if (!mqReduce.matches && v.dataset.visible === '1') play(v); });
  });
  document.addEventListener('visibilitychange', function () {
    videos.forEach(function (v) {
      if (document.hidden) v.pause(); else if (v.dataset.visible === '1') play(v);
    });
  });
})();
