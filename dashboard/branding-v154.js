/* Legacy updater compatibility signature: Dashboard Toolbar V154; brandMenuToggleV154 */
(()=>{
/* Dashboard Toolbar */

// Browser-tab preferences are local to this browser and origin, independent of server branding.
const tabStorageKey='dashboard.browserTabSettings';
const tabFields=[['name','Dashboard-Name'],['cpu','CPU-Auslastung'],['ram','RAM-Auslastung'],['power','Leistungsaufnahme (Watt)']];
const tabDefaults={active:['name'],inactive:['name','cpu','ram','power'],interval:5,updateInterval:3,update:true};
function normalizeTabSettings(raw){
  raw=raw&&typeof raw==='object'?raw:{};
  const result={};
  for(const mode of ['active','inactive']){
    const selected=Array.isArray(raw[mode])?tabFields.map(([key])=>key).filter(key=>raw[mode].includes(key)):tabDefaults[mode].slice();
    result[mode]=selected.length?selected:['name'];
  }
  result.interval=[3,5,10,15,30].includes(raw.interval)?raw.interval:5;
  result.updateInterval=[2,3,5,10].includes(raw.updateInterval)?raw.updateInterval:3;
  result.update=raw.update!==false;
  return result;
}
function readTabSettings(){
  try{return normalizeTabSettings(JSON.parse((localStorage.getItem(tabStorageKey)||localStorage.getItem('node'+'zero.browserTabSettings'))))}catch(e){return normalizeTabSettings(null)}
}
let tabSettings=readTabSettings();
let tabName=document.title||'PVE Hardware Monitor';
let tabMetrics=null,tabMetricsTime=0,tabUpdate=null,tabUpdateTime=0;
let tabIndex=0,tabMode='',tabTimer=null;
function tabNumber(value,digits=0){
  if(typeof value!=='number'||!Number.isFinite(value)||value<0)return null;
  return value.toLocaleString('de-DE',{minimumFractionDigits:digits,maximumFractionDigits:digits});
}
function decimalTransferRate(v){
  if(typeof v!=='number'||!Number.isFinite(v)||v<0)return '–';
  const units=['B/s','kB/s','MB/s','GB/s','TB/s'];
  let i=0;
  while(v>=1000&&i<units.length-1){v/=1000;i++}
  // Promote values which would otherwise round to 1000 of the smaller unit.
  if(i<units.length-1&&Number(v.toFixed(i?2:0))>=1000){v/=1000;i++}
  return v.toLocaleString('de-DE',{useGrouping:false,minimumFractionDigits:0,maximumFractionDigits:i?2:0})+' '+units[i];
}
 // Existing installations receive this through the managed branding update.
 if(typeof rate==='function')rate=decimalTransferRate;
 if(typeof draw==='function'){
   const originalDraw=draw;
   draw=function(id,series,opt={}){
     if(id==='cNet'||id==='cIO')opt={...opt,y:decimalTransferRate};
     return originalDraw.call(this,id,series,opt);
   };
 }
function localHostPower(d){
  const valid=v=>typeof v==='number'&&Number.isFinite(v)&&v>=0;
  if(valid(d.system_power_w))return {value:d.system_power_w,total:true,label:'Gesamtserver via IPMI/DCMI'};
  const parts=[];
  if(valid(d.cpu_power_w))parts.push(['CPU-Package',d.cpu_power_w]);
  else if(valid(d.cpu_core_power_w))parts.push(['CPU-Kerne',d.cpu_core_power_w]);
  else if(valid(d.uncore_power_w))parts.push(['Uncore',d.uncore_power_w]);
  // This collector exposes the separate Intel RAPL DRAM domain.
  if(valid(d.dram_power_w))parts.push(['DRAM',d.dram_power_w]);
  // gpu_power_w may represent an integrated GPU. Never add an ambiguous
  // GPU reading to CPU/RAPL measurements without independent provenance.
  if(!parts.length&&valid(d.gpu_power_w))parts.push(['GPU',d.gpu_power_w]);
  if(!parts.length)return {value:null,total:false,label:'Keine lokale Watt-Messquelle verfügbar'};
  return {value:parts.reduce((sum,p)=>sum+p[1],0),total:false,label:'Teilmessung: '+parts.map(p=>p[0]).join(' + ')+' · Gesamtverbrauch nicht messbar'};
}
if(typeof bestPower==='function'){
  bestPower=function(d){
    const p=localHostPower(d);
    const value=p.value===null?'n/v':tabNumber(p.value,1)+' W';
    return [value,p.label];
  };
}
function buildTabFrames(mode,now=Date.now()){
  if(tabSettings.update&&tabUpdate&&now-tabUpdateTime<3600000){
    return ['Update verfügbar','Update V'+tabUpdate,tabName];
  }
  const selected=tabSettings[mode];
  const frames=[];
  if(selected.includes('name'))frames.push(tabName);
  const d=tabMetrics&&now-tabMetricsTime<120000?tabMetrics:{};
  const usage=[];
  for(const [key,field,label] of [['cpu','cpu_percent','CPU'],['ram','ram_percent','RAM']]){
    if(!selected.includes(key))continue;
    const value=tabNumber(d[field]);
    if(value!==null)usage.push(label+' '+value+' %');
  }
  if(usage.length)frames.push(usage.join(' | '));
  if(selected.includes('power')){
    const p=localHostPower(d);
    const value=tabNumber(p.value,2);
    if(value!==null)frames.push((p.total?'':'Teil ')+value+' W');
  }
  return frames.length?frames:[tabName];
}
function refreshTabTitle(reset=false){
  const visible=document.visibilityState==='visible';
  const mode=tabSettings.update&&tabUpdate&&Date.now()-tabUpdateTime<3600000?'update':visible?'active':'inactive';
  if(reset||mode!==tabMode){tabMode=mode;tabIndex=0}
  const frames=buildTabFrames(visible?'active':'inactive');
  document.title=frames[tabIndex%frames.length];
}
function restartTabRotation(){
  if(tabTimer!==null)window.clearTimeout(tabTimer);
  refreshTabTitle(true);
  function tick(){
    tabIndex++;
    refreshTabTitle();
    tabTimer=window.setTimeout(tick,(tabMode==='update'?tabSettings.updateInterval:tabSettings.interval)*1000);
  }
  tabTimer=window.setTimeout(tick,(tabMode==='update'?tabSettings.updateInterval:tabSettings.interval)*1000);
}
function setTabUpdateStatus(data){
  const valid=Number.isSafeInteger(data?.remote)&&Number.isSafeInteger(data?.local)&&data.remote>data.local&&data.status==='available';
  const next=valid?data.remote:null;
  const checked=Date.parse(data?.checked||'');
  const timestamp=Number.isFinite(checked)?Math.min(checked,Date.now()):0;
  const changed=next!==tabUpdate;
  tabUpdate=next;tabUpdateTime=timestamp;
  if(changed)restartTabRotation();else refreshTabTitle();
}
if(typeof getJSON==='function'){
  const originalGetJSON=getJSON;
  getJSON=async function(url,...args){
    const data=await originalGetJSON.call(this,url,...args);
    if(typeof url==='string'&&url.split('?')[0]==='/api/current'&&data&&typeof data==='object'){
      tabMetrics=data;tabMetricsTime=Date.now();refreshTabTitle();
    }
    return data;
  };
}
function installTabSettings(){
  if(document.getElementById('browserTabSettings'))return;
  const anchor=document.getElementById('settingsSave')?.closest('.modalButtons');
  if(!anchor)return;
  const panel=document.createElement('section');
  panel.id='browserTabSettings';
  panel.className='browserTabSettings';
  const checks=(mode,title)=>'<fieldset><legend>'+title+'</legend>'+tabFields.map(([key,label])=>'<label><input type="checkbox" data-tab-mode="'+mode+'" value="'+key+'"> '+label+'</label>').join('')+'</fieldset>';
  const options=values=>values.map(v=>'<option value="'+v+'">'+v+' Sekunden</option>').join('');
  panel.innerHTML='<h3>Browser-Tab-Anzeige</h3><p>Individuell für diesen Browser. CPU und RAM erscheinen gemeinsam, wenn beide ausgewählt sind.</p><div class="browserTabChoices">'+checks('active','Aktiver Tab')+checks('inactive','Inaktiver Tab')+'</div><label>Wechselintervall <select data-tab-setting="interval">'+options([3,5,10,15,30])+'</select></label><label><input type="checkbox" data-tab-setting="update"> Update-Hinweise priorisieren (auch im aktiven Tab)</label><label>Update-Wechselintervall <select data-tab-setting="updateInterval">'+options([2,3,5,10])+'</select></label><div class="browserTabActions"><button type="button" data-tab-reset>Standard wiederherstellen</button><span role="status" data-tab-message></span></div>';
  anchor.before(panel);
  function sync(){
    panel.querySelectorAll('[data-tab-mode]').forEach(el=>{el.checked=tabSettings[el.dataset.tabMode].includes(el.value)});
    panel.querySelectorAll('[data-tab-setting]').forEach(el=>{const v=tabSettings[el.dataset.tabSetting];if(el.type==='checkbox')el.checked=v;else el.value=String(v)});
  }
  function save(){
    const msg=panel.querySelector('[data-tab-message]');
    try{localStorage.setItem(tabStorageKey,JSON.stringify(tabSettings));msg.textContent='Gespeichert.'}
    catch(e){msg.textContent='Nur für diese Sitzung gespeichert.'}
    sync();restartTabRotation();
  }
  panel.addEventListener('change',()=>{
    const next={...tabSettings};
    for(const mode of ['active','inactive'])next[mode]=Array.from(panel.querySelectorAll('[data-tab-mode="'+mode+'"]:checked'),el=>el.value);
    for(const key of ['interval','updateInterval'])next[key]=Number(panel.querySelector('[data-tab-setting="'+key+'"]').value);
    next.update=panel.querySelector('[data-tab-setting="update"]').checked;
    tabSettings=normalizeTabSettings(next);save();
  });
  panel.querySelector('[data-tab-reset]').addEventListener('click',()=>{tabSettings=normalizeTabSettings(null);save()});
  window.addEventListener('storage',e=>{if(e.key===tabStorageKey||e.key===null){tabSettings=readTabSettings();sync();restartTabRotation()}});
  sync();
}
document.addEventListener('visibilitychange',restartTabRotation);
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',installTabSettings,{once:true});
else installTabSettings();
restartTabRotation();

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

const brandMenuConfigured=new WeakMap();
function configureBrandMenu(button,settings,force=false){
  if(!button)return;
  const text=String(settings?.logo_text||'DASHBOARD').trim()||'DASHBOARD';
  if(!force&&brandMenuConfigured.get(button)===text&&button.querySelector('#randMenuLogo'))return;
  brandMenuConfigured.set(button,text);

  button.id='brandMenuToggle';
  button.classList.add('brandMenuToggle');
  button.removeAttribute('onclick');
  button.onclick=toggleBrandMenu;
  button.setAttribute('aria-label','Menü öffnen oder schließen');
  button.innerHTML=
    '<span class="brandMenuHamburger" aria-hidden="true">☰</span>'
    +'<img class="randMenuLogo" id="randMenuLogo" alt="">'
    +'<span class="brandMenuText" id="brandMenuText"></span>';

  const label=document.getElementById('brandMenuText');
  if(label)label.textContent=text;

  const img=document.getElementById('randMenuLogo');
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
  if(button.querySelector('.brandPowerIcon svg'))return;
  const icon=document.createElement('span');
  icon.className='brandPowerIcon';
  icon.setAttribute('aria-hidden','true');
  const ns='http://www.w3.org/2000/svg';
  const svg=document.createElementNS(ns,'svg');
  for(const [k,v] of Object.entries({viewBox:'0 0 24 24',fill:'none',stroke:'currentColor','stroke-width':'2','stroke-linecap':'round','stroke-linejoin':'round',focusable:'false'}))svg.setAttribute(k,v);
  const paths=symbol==='power'?['M12 2v10','M6 5a9 9 0 1 0 12 0']:['M20 4v6h-6','M20 10a8 8 0 1 0 .1 5'];
  for(const d of paths){const path=document.createElementNS(ns,'path');path.setAttribute('d',d);svg.appendChild(path)}
  icon.appendChild(svg);
  const text=document.createElement('span');
  text.className='brandPowerLabel';
  text.textContent=label;
  button.setAttribute('aria-label',label);
  button.title=label;
  button.replaceChildren(icon,text);
}

function ensureBrandToolbarLayout(settings={},refreshLogo=false){
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

  if(menu){configureBrandMenu(menu,settings,refreshLogo);left.appendChild(menu)}
  if(live)center.appendChild(live);
  if(ups)center.appendChild(ups);
  if(reboot){preparePowerButton(reboot,'Neustart','restart');right.appendChild(reboot);}
  if(shutdown){preparePowerButton(shutdown,'Herunterfahren','power');right.appendChild(shutdown);}

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
  tabName=website;
  window.dispatchEvent(new CustomEvent('dashboard-branding-ready',{detail:{website_name:website}}));
  refreshTabTitle();

  const h1=
    document.getElementById('websiteTitle')
    ||document.querySelector('.top .brand h1')
    ||document.querySelector('.brand h1');

  if(h1){
    h1.id='websiteTitle';
    h1.textContent=website;
  }

  applyBrandFavicon(settings);
  ensureBrandToolbarLayout(settings,true);
}

if(typeof applyUiSettings==='function'){
  const previousApplyUiSettings=applyUiSettings;
  applyUiSettings=function(settings){
    const result=previousApplyUiSettings(settings);
    window.__proxmoxUiSettings=settings||{};
    applyDashboardBranding(window.__proxmoxUiSettings);
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
    ensureBrandToolbarLayout(window.__proxmoxUiSettings||{});
    return result;
  };
}

setTimeout(async()=>{
  let settings={};
  try{
    settings=await getJSON('/api/ui-settings');
  }catch(e){}
  window.__proxmoxUiSettings=settings||{};
  applyDashboardBranding(settings||{});
},0);


// System details belong at the bottom, not under the dashboard title.
function installSystemFooter(){
  const source=document.getElementById('hostinfo');
  if(!source || document.getElementById('proxmoxSystemFooter'))return;
  const footer=document.createElement('footer');
  footer.id='proxmoxSystemFooter';
  const details=document.createElement('div');
  details.className='proxmoxFooterDetails';
  const credit=document.createElement('div');
  credit.className='proxmoxFooterCredit';
  credit.append(document.createTextNode('Copyright © Technox1990 · '));
  const link=document.createElement('a');
  link.href='https://github.com/Technox90/homeatic';
  link.target='_blank';
  link.rel='noopener noreferrer';
  link.textContent='GitHub';
  credit.append(link);
  footer.append(details,credit);
  document.body.append(footer);
  source.classList.add('proxmoxHostInfoHidden');
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
      setTabUpdateStatus(data);
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
