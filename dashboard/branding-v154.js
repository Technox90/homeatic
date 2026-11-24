/* Legacy updater compatibility signature: NodeZero Dashboard Toolbar V154; brandMenuToggleV154 */
(()=>{
/* NodeZero Dashboard Toolbar */
function brandImageHasVisiblePixels(img){
  try{
    const max=64;
    const ratio=Math.min(max/img.naturalWidth,max/img.naturalHeight,1);
    const w=Math.max(1,Math.round(img.naturalWidth*ratio));
    const h=Math.max(1,Math.round(img.naturalHeight*ratio));
    const c=document.createElement('canvas');
    c.width=w;c.height=h;
    const x=c.getContext('2d',{willReadFrequently:true});
    if(!x)return false;
    x.clearRect(0,0,w,h);
    x.drawImage(img,0,0,w,h);
    const data=x.getImageData(0,0,w,h).data;
    for(let i=3;i<data.length;i+=4){
      if(data[i]>8)return true;
    }
  }catch(e){
    return false;
  }
  return false;
}

function toggleBrandMenu(){
  const nav=document.getElementById('sideNav');
  if(!nav)return;
  if(nav.classList.contains('show')){
    if(typeof closeNav==='function')closeNav();
  }else{
    if(typeof openNav==='function')openNav();
  }
}

function configureBrandMenu(button,settings){
  if(!button)return;
  const text=String(settings?.logo_text||'NODEZERO').trim()||'NODEZERO';

  button.id='brandMenuToggle';
  button.classList.add('brandMenuToggle');
  button.removeAttribute('onclick');
  button.onclick=toggleBrandMenu;
  button.setAttribute('aria-label','Menü öffnen oder schließen');
  button.innerHTML=
    '<span class="brandMenuHamburger" aria-hidden="true">☰</span>'
    +'<img class="brandMenuLogo" id="brandMenuLogo" alt="">'
    +'<span class="brandMenuText" id="brandMenuText"></span>';

  const label=document.getElementById('brandMenuText');
  if(label)label.textContent=text;

  const img=document.getElementById('brandMenuLogo');
  if(!img)return;

  button.classList.remove('hasImage');
  img.onload=()=>{
    const visible=brandImageHasVisiblePixels(img);
    button.classList.toggle('hasImage',visible);
    img.alt=visible?text+' Logo':'';
  };
  img.onerror=()=>{
    button.classList.remove('hasImage');
    img.alt='';
  };
  img.src='/assets/logo.png?ts='+Date.now();
}

function preparePowerButton(button,label,symbol){
  if(button.querySelector('.brandPowerIcon'))return;
  const icon=document.createElement('span');
  icon.className='brandPowerIcon';
  icon.setAttribute('aria-hidden','true');
  icon.textContent=symbol;
  const text=document.createElement('span');
  text.className='brandPowerLabel';
  text.textContent=label;
  button.setAttribute('aria-label',label);
  button.title=label;
  button.replaceChildren(icon,text);
}

function ensureBrandToolbarLayout(settings={}){
  const bar=document.querySelector('.toolbar');
  if(!bar)return;

  let shell=document.getElementById('dashboardFixedToolbar');
  if(!shell){
    shell=document.createElement('div');
    shell.id='dashboardFixedToolbar';
    document.body.prepend(shell);
  }
  if(bar.parentElement!==shell)shell.appendChild(bar);

  document.body.classList.add('dashboardToolbarFixed');
  document.body.classList.remove('dashboardToolbarFixed'+'V151');

  let left=document.getElementById('toolbarLeft');
  let center=document.getElementById('toolbarCenter');
  let right=document.getElementById('toolbarRight');

  if(!left){
    left=document.createElement('div');
    left.id='toolbarLeft';
    left.className='toolbarLeft';
  }
  if(!center){
    center=document.createElement('div');
    center.id='toolbarCenter';
    center.className='toolbarCenter';
  }
  if(!right){
    right=document.createElement('div');
    right.id='toolbarRight';
    right.className='toolbarRight';
  }

  const menu=bar.querySelector('.menuBtn')||document.getElementById('brandMenuToggle');
  const live=document.getElementById('state')?.closest('.live');
  const ups=document.getElementById('upsTopState');
  const reboot=bar.querySelector('.reboot');
  const shutdown=bar.querySelector('.danger');

  if(menu){configureBrandMenu(menu,settings);left.appendChild(menu)}
  if(live)center.appendChild(live);
  if(ups)center.appendChild(ups);
  if(reboot){preparePowerButton(reboot,'Neustart','↻');right.appendChild(reboot);}
  if(shutdown){preparePowerButton(shutdown,'Herunterfahren','⏻');right.appendChild(shutdown);}

  [left,center,right].forEach(el=>bar.appendChild(el));
}

function applyBrandFavicon(settings){
  if(typeof ensureFaviconLink!=='function')return;
  const link=ensureFaviconLink();
  if(settings?.favicon_url){
    link.type='';
    link.href=settings.favicon_url;
    return;
  }
  link.type='image/png';
  link.href='/assets/favicon.png?ts='+Date.now();
}

function applyDashboardBranding(settings){
  settings=settings||{};
  const website=String(settings.website_name||'PVE Hardware Monitor').trim()||'PVE Hardware Monitor';
  document.title=website;

  const h1=
    document.getElementById('websiteTitle')
    ||document.querySelector('.top .brand h1')
    ||document.querySelector('.brand h1');

  if(h1){
    h1.id='websiteTitle';
    h1.textContent=website;
  }

  applyBrandFavicon(settings);
  ensureBrandToolbarLayout(settings);
}

if(typeof applyUiSettings==='function'){
  const previousApplyUiSettings=applyUiSettings;
  applyUiSettings=function(settings){
    const result=previousApplyUiSettings(settings);
    applyDashboardBranding(settings||{});
    return result;
  };
}

if(typeof setUpsTopState==='function'){
  const previousSetUpsTopState=setUpsTopState;
  setUpsTopState=function(data){
    const result=previousSetUpsTopState(data);
    const text=document.getElementById('upsTopStateText');
    if(
      text&&data&&data.ok&&data.reachable
      &&String(data.power_source||'').toLowerCase()==='mains'
    ){
      text.textContent='USV Online';
    }
    ensureBrandToolbarLayout(window.__nodezeroUiSettings||{});
    return result;
  };
}

setTimeout(async()=>{
  let settings={};
  try{
    settings=await getJSON('/api/ui-settings');
  }catch(e){}
  window.__nodezeroUiSettings=settings||{};
  applyDashboardBranding(settings||{});
},0);


// System details belong at the bottom, not under the dashboard title.
function installSystemFooter(){
  const source=document.getElementById('hostinfo');
  if(!source || document.getElementById('nodezeroSystemFooter'))return;
  const footer=document.createElement('footer');
  footer.id='nodezeroSystemFooter';
  const details=document.createElement('div');
  details.className='nodezeroFooterDetails';
  const credit=document.createElement('div');
  credit.className='nodezeroFooterCredit';
  credit.append(document.createTextNode('Copyright © Technox1990 · '));
  const link=document.createElement('a');
  link.href='https://github.com/Technox90/homeatic';
  link.target='_blank';
  link.rel='noopener noreferrer';
  link.textContent='GitHub';
  credit.append(link);
  footer.append(details,credit);
  document.body.append(footer);
  source.classList.add('nodezeroHostInfoHidden');
  let version='Version unbekannt';
  const render=()=>{
    const parts=source.textContent.trim().split(/\s+·\s+/);
    details.textContent=[version,...(parts.length>1?parts.slice(1):[])].join(' · ');
  };
  render();
  if(window.MutationObserver){
    new MutationObserver(render).observe(source,{childList:true,characterData:true,subtree:true});
  }
  const refresh=async()=>{
    try{
      const response=await fetch('/installer-update-status.json',{cache:'no-store'});
      if(!response.ok)throw Error('status');
      const data=await response.json();
      if(Number.isSafeInteger(data.local)&&data.local>0){
        version='Version '+data.local;
        render();
      }
    }catch(e){/* keep last confirmed local version */}
  };
  refresh();
  window.setInterval(refresh,60000);
}
if(document.readyState==='loading'){
  document.addEventListener('DOMContentLoaded',installSystemFooter,{once:true});
}else{
  installSystemFooter();
}

})();
