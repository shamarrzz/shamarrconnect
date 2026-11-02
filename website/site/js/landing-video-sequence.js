/* Two-clip sequence in one figure (block 2: permissions, then view mode).
   Load AFTER landing-video.js. The hidden clip is display:none, so
   landing-video.js's IntersectionObserver ignores it until it is shown. */
(function(){
  document.querySelectorAll('figure.loop-seq').forEach(function(fig){
    var vids=[].slice.call(fig.querySelectorAll('video.sc-loop'));
    if(vids.length<2) return;
    vids.forEach(function(v,i){
      v.loop=false; v.removeAttribute('loop');       // each clip plays once, then hands over
      v.addEventListener('ended', function(){
        var next=vids[(i+1)%vids.length];
        v.hidden=true;
        try{ v.currentTime=0; }catch(e){}
        next.hidden=false;                           // IO sees it -> loads/plays it
        fig.setAttribute('data-step', String((i+1)%vids.length));
      });
    });
  });
})();
