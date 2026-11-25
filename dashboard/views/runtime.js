/* Dashboard Views v1 — frontend only, never mutates server state */
(() => {
  "use strict";
  const id = window.PROXMOX_DASHBOARD_VIEW || "boot";
  const reduce = window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  document.documentElement.classList.add("view-has-view","view-view-"+id);

  function onReady() {
    const state = document.getElementById("state");
    // Theme selection belongs in the installer, not in the dashboard header.
    document.querySelectorAll(".view-view-badge").forEach(badge => badge.remove());

    const cards = [...document.querySelectorAll(
      ".card,.chart,.serviceCard,.linkCard,.statCard"
    )];
    if (!reduce) {
      cards.forEach((card,i)=>{
        card.classList.add("view-enter");
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
        card.classList.toggle("view-alert",number>=80 && number<92);
        card.classList.toggle("view-critical",number>=92);
      }
      applyThreshold(previous);
      new MutationObserver(()=>{
        const next=el.textContent.trim();
        if (next===previous) return;
        previous=next;
        applyThreshold(next);
        if (!reduce) {
          el.classList.remove("view-value-updated");
          void el.offsetWidth;
          el.classList.add("view-value-updated");
        }
      }).observe(el,{characterData:true,childList:true,subtree:true});
    }

    if (id==="boot" && !reduce) {
      const overlay=document.createElement("div");
      overlay.className="view-boot-overlay";
      overlay.setAttribute("role","status");
      overlay.setAttribute("aria-label","Dashboard wird geladen");
      const inner=document.createElement("div");
      inner.className="view-boot-inner";
      const ring=document.createElement("span");
      ring.className="view-boot-ring";
      ring.setAttribute("aria-hidden","true");
      const title=document.createElement("strong");
      title.className="view-boot-title";
      const configuredName=()=>String(window.__proxmoxUiSettings?.website_name||document.getElementById("websiteTitle")?.textContent||document.querySelector(".top .brand h1")?.textContent||"").trim();
      title.textContent=configuredName();
      const nameEvent=e=>{const name=String(e.detail?.website_name||configuredName()).trim();if(name)title.textContent=name;};
      window.addEventListener("dashboard-branding-ready",nameEvent);
      const sub=document.createElement("span");
      sub.className="view-boot-sub";
      sub.textContent="SYSTEMDATEN WERDEN GELADEN";
      inner.append(ring,title,sub); overlay.append(inner);
      document.body.append(overlay);
      let finished=false;
      function finish() {
        if(finished)return;
        finished=true;
        window.removeEventListener("dashboard-branding-ready",nameEvent);
        overlay.classList.add("view-finished");
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
