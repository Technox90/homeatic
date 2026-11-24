/* NodeZero Dashboard Views v1 — frontend only, never mutates server state */
(() => {
  "use strict";
  const id = window.NODEZERO_DASHBOARD_VIEW || "boot";
  const reduce = window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  document.documentElement.classList.add("nz-has-view","nz-view-"+id);

  function onReady() {
    const state = document.getElementById("state");
    // Theme selection belongs in the installer, not in the dashboard header.
    document.querySelectorAll(".nz-view-badge").forEach(badge => badge.remove());

    const cards = [...document.querySelectorAll(
      ".card,.chart,.serviceCard,.linkCard,.statCard"
    )];
    if (!reduce) {
      cards.forEach((card,i)=>{
        card.classList.add("nz-enter");
        card.style.animationDelay = Math.min(i*32,320)+"ms";
      });
    }

    const monitored = ["cpu","ram","disk","board","power","piholeBlockedPct"];
    for (const key of monitored) {
      const el=document.getElementById(key);
      if (!el || !window.MutationObserver) continue;
      let previous=el.textContent.trim();
      const card=el.closest(".card,.statCard");
      function applyThreshold(value) {
        if (!card) return;
        const match=value.match(/(\d+(?:[.,]\d+)?)\s*%/);
        const number=match?Number(match[1].replace(",",".")):NaN;
        if (!["cpu","ram","disk"].includes(key) || !Number.isFinite(number)) return;
        card.classList.toggle("nz-alert",number>=80 && number<92);
        card.classList.toggle("nz-critical",number>=92);
      }
      applyThreshold(previous);
      new MutationObserver(()=>{
        const next=el.textContent.trim();
        if (next===previous) return;
        previous=next;
        applyThreshold(next);
        if (!reduce) {
          el.classList.remove("nz-value-updated");
          void el.offsetWidth;
          el.classList.add("nz-value-updated");
        }
      }).observe(el,{characterData:true,childList:true,subtree:true});
    }

    if (id==="boot" && !reduce) {
      const overlay=document.createElement("div");
      overlay.className="nz-boot-overlay";
      overlay.setAttribute("role","status");
      overlay.setAttribute("aria-label","NodeZero Dashboard wird geladen");
      const inner=document.createElement("div");
      inner.className="nz-boot-inner";
      const ring=document.createElement("span");
      ring.className="nz-boot-ring";
      ring.setAttribute("aria-hidden","true");
      const title=document.createElement("strong");
      title.className="nz-boot-title";
      title.textContent="NODEZERO";
      const sub=document.createElement("span");
      sub.className="nz-boot-sub";
      sub.textContent="SYSTEMDATEN WERDEN GELADEN";
      inner.append(ring,title,sub); overlay.append(inner);
      document.body.append(overlay);
      let finished=false;
      function finish() {
        if(finished)return;
        finished=true;
        overlay.classList.add("nz-finished");
        window.setTimeout(()=>overlay.remove(),650);
      }
      if(state && window.MutationObserver) {
        const observe=new MutationObserver(()=>{
          const v=(state.textContent||"").trim().toUpperCase();
          if(v==="LIVE" || v==="OFFLINE") {observe.disconnect();finish();}
        });
        observe.observe(state,{subtree:true,characterData:true,childList:true});
        if(["LIVE","OFFLINE"].includes((state.textContent||"").trim().toUpperCase()))finish();
      }
      window.setTimeout(finish,6500);
      overlay.addEventListener("click",finish);
    }
  }
  if(document.readyState==="loading"){
    document.addEventListener("DOMContentLoaded",onReady,{once:true});
  } else onReady();
})();
