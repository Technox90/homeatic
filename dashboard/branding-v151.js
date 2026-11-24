/* NodeZero Dashboard Branding V151 */
function fixedToolbarV151(){
  const bar=document.querySelector('.toolbar');
  if(!bar)return;
  let shell=document.getElementById('dashboardFixedToolbarV151');
  if(!shell){
    shell=document.createElement('div');
    shell.id='dashboardFixedToolbarV151';
    document.body.prepend(shell);
  }
  if(bar.parentElement!==shell)shell.appendChild(bar);
  document.body.classList.add('dashboardToolbarFixedV151');

  const items=[
    bar.querySelector('.menuBtn'),
    document.getElementById('state')?.closest('.live'),
    document.getElementById('upsTopState'),
    bar.querySelector('.reboot'),
    bar.querySelector('.danger')
  ];
  items.filter(Boolean).forEach(el=>bar.appendChild(el));
}

function imageHasVisiblePixelsV151(img){
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

function menuLogoV151(settings){
  const head=document.querySelector('#sideNav .navHead');
  if(!head)return;

  let logo=document.getElementById('dashboardBrandLogoV151');
  if(!logo){
    logo=document.createElement('div');
    logo.id='dashboardBrandLogoV151';
    logo.className='brandLogoV151';
    logo.innerHTML=
      '<img id="dashboardBrandImageV151" class="brandLogoImageV151" alt="">'
      +'<span id="dashboardBrandTextV151" class="brandLogoTextV151">NODEZERO</span>';
    head.prepend(logo);
  }

  const text=String(settings.logo_text||'NODEZERO').trim()||'NODEZERO';
  const label=document.getElementById('dashboardBrandTextV151');
  if(label)label.textContent=text;

  const img=document.getElementById('dashboardBrandImageV151');
  if(!img)return;

  logo.classList.remove('hasImageV151');

  img.onload=()=>{
    const visible=imageHasVisiblePixelsV151(img);
    logo.classList.toggle('hasImageV151',visible);
    img.alt=visible?text+' Logo':'';
  };
  img.onerror=()=>{
    logo.classList.remove('hasImageV151');
    img.alt='';
  };

  img.src='/assets/logo.png?ts='+Date.now();
}

function faviconV151(settings){
  const link=ensureFaviconLink();

  if(settings?.favicon_url){
    link.type='';
    link.href=settings.favicon_url;
    return;
  }

  link.type='image/png';
  link.href='/assets/favicon.png?ts='+Date.now();
}

function applyBrandingV151(settings){
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

  menuLogoV151(settings);
  faviconV151(settings);
  fixedToolbarV151();
}

if(typeof applyUiSettings==='function'){
  const previousApplyUiSettingsV151=applyUiSettings;
  applyUiSettings=function(settings){
    const result=previousApplyUiSettingsV151(settings);
    applyBrandingV151(settings||{});
    return result;
  };
}

if(typeof setUpsTopState==='function'){
  const previousSetUpsTopStateV151=setUpsTopState;
  setUpsTopState=function(data){
    const result=previousSetUpsTopStateV151(data);
    const text=document.getElementById('upsTopStateText');

    if(
      text&&data&&data.ok&&data.reachable
      &&String(data.power_source||'').toLowerCase()==='mains'
    ){
      text.textContent='USV Online';
    }

    fixedToolbarV151();
    return result;
  };
}

setTimeout(async()=>{
  fixedToolbarV151();
  try{
    applyBrandingV151(await getJSON('/api/ui-settings'));
  }catch(e){
    applyBrandingV151({
      website_name:'PVE Hardware Monitor',
      logo_text:'NODEZERO'
    });
  }
},0);
