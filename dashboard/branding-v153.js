/* Dashboard Toolbar V153 */
function imageHasVisiblePixelsV153(img){
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

function toggleNavV153(){
  const nav=document.getElementById('sideNav');
  if(!nav)return;
  if(nav.classList.contains('show')){
    if(typeof closeNav==='function')closeNav();
  }else{
    if(typeof openNav==='function')openNav();
  }
}

function configureBrandMenuV153(button,settings){
  if(!button)return;
  const text=String(settings?.logo_text||'PROXMOX').trim()||'PROXMOX';

  button.id='brandMenuToggleV153';
  button.classList.add('brandMenuToggleV153');
  button.removeAttribute('onclick');
  button.onclick=toggleNavV153;
  button.setAttribute('aria-label','Menü öffnen oder schließen');
  button.innerHTML=
    '<span class="brandMenuHamburgerV153" aria-hidden="true">☰</span>'
    +'<img class="brandMenuLogoV153" id="brandMenuLogoV153" alt="">'
    +'<span class="brandMenuTextV153" id="brandMenuTextV153"></span>';

  const label=document.getElementById('brandMenuTextV153');
  if(label)label.textContent=text;

  const img=document.getElementById('brandMenuLogoV153');
  if(!img)return;

  button.classList.remove('hasImageV153');
  img.onload=()=>{
    const visible=imageHasVisiblePixelsV153(img);
    button.classList.toggle('hasImageV153',visible);
    img.alt=visible?text+' Logo':'';
  };
  img.onerror=()=>{
    button.classList.remove('hasImageV153');
    img.alt='';
  };
  img.src='/assets/logo.png?ts='+Date.now();
}

function ensureToolbarLayoutV153(settings={}){
  const bar=document.querySelector('.toolbar');
  if(!bar)return;

  let shell=document.getElementById('dashboardFixedToolbarV153');
  if(!shell){
    shell=document.createElement('div');
    shell.id='dashboardFixedToolbarV153';
    document.body.prepend(shell);
  }
  if(bar.parentElement!==shell)shell.appendChild(bar);

  document.body.classList.add('dashboardToolbarFixedV153');
  document.body.classList.remove('dashboardToolbarFixedV151');

  let left=document.getElementById('toolbarLeftV153');
  let center=document.getElementById('toolbarCenterV153');
  let right=document.getElementById('toolbarRightV153');

  if(!left){
    left=document.createElement('div');
    left.id='toolbarLeftV153';
    left.className='toolbarLeftV153';
  }
  if(!center){
    center=document.createElement('div');
    center.id='toolbarCenterV153';
    center.className='toolbarCenterV153';
  }
  if(!right){
    right=document.createElement('div');
    right.id='toolbarRightV153';
    right.className='toolbarRightV153';
  }

  const menu=bar.querySelector('.menuBtn')||document.getElementById('brandMenuToggleV153');
  const live=document.getElementById('state')?.closest('.live');
  const ups=document.getElementById('upsTopState');
  const reboot=bar.querySelector('.reboot');
  const shutdown=bar.querySelector('.danger');

  if(menu){configureBrandMenuV153(menu,settings);left.appendChild(menu)}
  if(live)center.appendChild(live);
  if(ups)center.appendChild(ups);
  if(reboot)right.appendChild(reboot);
  if(shutdown)right.appendChild(shutdown);

  [left,center,right].forEach(el=>bar.appendChild(el));
}

function faviconV153(settings){
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

function applyBrandingV153(settings){
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

  faviconV153(settings);
  ensureToolbarLayoutV153(settings);
}

if(typeof applyUiSettings==='function'){
  const previousApplyUiSettingsV153=applyUiSettings;
  applyUiSettings=function(settings){
    const result=previousApplyUiSettingsV153(settings);
    applyBrandingV153(settings||{});
    return result;
  };
}

if(typeof setUpsTopState==='function'){
  const previousSetUpsTopStateV153=setUpsTopState;
  setUpsTopState=function(data){
    const result=previousSetUpsTopStateV153(data);
    const text=document.getElementById('upsTopStateText');
    if(
      text&&data&&data.ok&&data.reachable
      &&String(data.power_source||'').toLowerCase()==='mains'
    ){
      text.textContent='USV Online';
    }
    ensureToolbarLayoutV153(window.__proxmoxUiSettingsV153||{});
    return result;
  };
}

setTimeout(async()=>{
  let settings={};
  try{
    settings=await getJSON('/api/ui-settings');
  }catch(e){}
  window.__proxmoxUiSettingsV153=settings||{};
  applyBrandingV153(settings||{});
},0);
