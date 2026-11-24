/* NodeZero Dashboard Toolbar V154 */
function imageHasVisiblePixelsV154(img){
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

function toggleNavV154(){
  const nav=document.getElementById('sideNav');
  if(!nav)return;
  if(nav.classList.contains('show')){
    if(typeof closeNav==='function')closeNav();
  }else{
    if(typeof openNav==='function')openNav();
  }
}

function configureBrandMenuV154(button,settings){
  if(!button)return;
  const text=String(settings?.logo_text||'NODEZERO').trim()||'NODEZERO';

  button.id='brandMenuToggleV154';
  button.classList.add('brandMenuToggleV154');
  button.removeAttribute('onclick');
  button.onclick=toggleNavV154;
  button.setAttribute('aria-label','Menü öffnen oder schließen');
  button.innerHTML=
    '<span class="brandMenuHamburgerV154" aria-hidden="true">☰</span>'
    +'<img class="brandMenuLogoV154" id="brandMenuLogoV154" alt="">'
    +'<span class="brandMenuTextV154" id="brandMenuTextV154"></span>';

  const label=document.getElementById('brandMenuTextV154');
  if(label)label.textContent=text;

  const img=document.getElementById('brandMenuLogoV154');
  if(!img)return;

  button.classList.remove('hasImageV154');
  img.onload=()=>{
    const visible=imageHasVisiblePixelsV154(img);
    button.classList.toggle('hasImageV154',visible);
    img.alt=visible?text+' Logo':'';
  };
  img.onerror=()=>{
    button.classList.remove('hasImageV154');
    img.alt='';
  };
  img.src='/assets/logo.png?ts='+Date.now();
}

function ensureToolbarLayoutV154(settings={}){
  const bar=document.querySelector('.toolbar');
  if(!bar)return;

  let shell=document.getElementById('dashboardFixedToolbarV154');
  if(!shell){
    shell=document.createElement('div');
    shell.id='dashboardFixedToolbarV154';
    document.body.prepend(shell);
  }
  if(bar.parentElement!==shell)shell.appendChild(bar);

  document.body.classList.add('dashboardToolbarFixedV154');
  document.body.classList.remove('dashboardToolbarFixedV151');

  let left=document.getElementById('toolbarLeftV154');
  let center=document.getElementById('toolbarCenterV154');
  let right=document.getElementById('toolbarRightV154');

  if(!left){
    left=document.createElement('div');
    left.id='toolbarLeftV154';
    left.className='toolbarLeftV154';
  }
  if(!center){
    center=document.createElement('div');
    center.id='toolbarCenterV154';
    center.className='toolbarCenterV154';
  }
  if(!right){
    right=document.createElement('div');
    right.id='toolbarRightV154';
    right.className='toolbarRightV154';
  }

  const menu=bar.querySelector('.menuBtn')||document.getElementById('brandMenuToggleV154');
  const live=document.getElementById('state')?.closest('.live');
  const ups=document.getElementById('upsTopState');
  const reboot=bar.querySelector('.reboot');
  const shutdown=bar.querySelector('.danger');

  if(menu){configureBrandMenuV154(menu,settings);left.appendChild(menu)}
  if(live)center.appendChild(live);
  if(ups)center.appendChild(ups);
  if(reboot)right.appendChild(reboot);
  if(shutdown)right.appendChild(shutdown);

  [left,center,right].forEach(el=>bar.appendChild(el));
}

function faviconV154(settings){
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

function applyBrandingV154(settings){
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

  faviconV154(settings);
  ensureToolbarLayoutV154(settings);
}

if(typeof applyUiSettings==='function'){
  const previousApplyUiSettingsV154=applyUiSettings;
  applyUiSettings=function(settings){
    const result=previousApplyUiSettingsV154(settings);
    applyBrandingV154(settings||{});
    return result;
  };
}

if(typeof setUpsTopState==='function'){
  const previousSetUpsTopStateV154=setUpsTopState;
  setUpsTopState=function(data){
    const result=previousSetUpsTopStateV154(data);
    const text=document.getElementById('upsTopStateText');
    if(
      text&&data&&data.ok&&data.reachable
      &&String(data.power_source||'').toLowerCase()==='mains'
    ){
      text.textContent='USV Online';
    }
    ensureToolbarLayoutV154(window.__nodezeroUiSettingsV154||{});
    return result;
  };
}

setTimeout(async()=>{
  let settings={};
  try{
    settings=await getJSON('/api/ui-settings');
  }catch(e){}
  window.__nodezeroUiSettingsV154=settings||{};
  applyBrandingV154(settings||{});
},0);


// V158: System details belong at the bottom, not under the dashboard title.
function installSystemFooterV158(){
  const source=document.getElementById('hostinfo');
  if(!source || document.getElementById('nodezeroSystemFooterV158'))return;
  const footer=document.createElement('footer');
  footer.id='nodezeroSystemFooterV158';
  const details=document.createElement('div');
  details.className='nodezeroFooterDetailsV158';
  const credit=document.createElement('div');
  credit.className='nodezeroFooterCreditV158';
  credit.append(document.createTextNode('Copyright © Technox1990 · '));
  const link=document.createElement('a');
  link.href='https://github.com/Technox90/homeatic';
  link.target='_blank';
  link.rel='noopener noreferrer';
  link.textContent='GitHub';
  credit.append(link);
  footer.append(details,credit);
  document.body.append(footer);
  source.classList.add('nodezeroHostInfoHiddenV158');
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
  document.addEventListener('DOMContentLoaded',installSystemFooterV158,{once:true});
}else{
  installSystemFooterV158();
}
