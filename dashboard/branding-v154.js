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
    if(value!==null)frames.push('Leistung '+value+' W');
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

/* V174: live metric presentation and browser-local alarm state. */
const v174Palette={white:'#FFFFFF',green:'#22C55E',yellow:'#EAB308',amber:'#FFB020',red:'#EF4444',blue:'#3B82F6',muted:'#94A3B8'};
const v174Valid=v=>typeof v==='number'&&Number.isFinite(v);
function v174Color(v,stops){
 if(!v174Valid(v))return v174Palette.muted;
 if(v<=stops[0][0])return stops[0][1];
 for(let i=1;i<stops.length;i++){const [b,bc]=stops[i], [a,ac]=stops[i-1];if(v<=b){const t=(v-a)/(b-a);const rgb=h=>[1,3,5].map(j=>parseInt(h.slice(j,j+2),16));return 'rgb('+rgb(ac).map((x,j)=>Math.round(x+(rgb(bc)[j]-x)*t)).join(',')+')'}}
 return stops[stops.length-1][1];
}
const vp=v174Palette;
const usageStops=(a=55,b=80)=>[[a-10,vp.white],[a,vp.amber],[b-10,vp.amber],[b,vp.red]];
const tempStops=(a=50,b=76)=>[[a-10,vp.green],[a,vp.amber],[b-10,vp.amber],[b,vp.red]];
const pingStops=[[25,vp.green],[50,'#84CC16'],[100,vp.yellow],[150,vp.amber],[200,vp.red]];
const warnKey='dashboard.warningSettingsV174',snoozeKey='dashboard.warningSnoozeV174';
const warnDefaults={sound:true,volume:75,frames:true,icons:true,glow:true,ping:true,pingInterval:15,providers:['Google','Quad9','Cloudflare'],pingColors:true,bars:true,netDown:0,netUp:0,netUnit:'mb'};
function readLocal(key,fallback){try{return JSON.parse(localStorage.getItem(key))??fallback}catch{return fallback}}
function saveLocal(key,value){try{localStorage.setItem(key,JSON.stringify(value))}catch{}}
let warnPrefs={...warnDefaults,...readLocal(warnKey,{})},snooze=readLocal(snoozeKey,null);
let lastMetrics=null,lastMetricsAt=0,lastPing=null,pingIndex=0,pingRotated=0,activeWarnings=new Map(),warningHistory=readLocal('dashboard.warningHistoryV174',[]);
let alarmContext=null,alarmNodes=[],alarmBusy=0;
const svgPaths={cpu:'<rect x="5" y="5" width="14" height="14" rx="2"/><rect x="9" y="9" width="6" height="6"/><path d="M9 1v4m6-4v4M9 19v4m6-4v4M1 9h4m-4 6h4m14-6h4m-4 6h4"/>',disk:'<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 13h18m-5 3h2"/>',ram:'<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M7 9v6m5-6v6m5-6v6M6 18v3m6-3v3m6-3v3"/>',net:'<rect x="9" y="2" width="6" height="6" rx="1"/><rect x="2" y="16" width="6" height="6" rx="1"/><rect x="16" y="16" width="6" height="6" rx="1"/><path d="M12 8v4M5 16v-4h14v4"/>',server:'<rect x="3" y="3" width="18" height="8" rx="2"/><rect x="3" y="13" width="18" height="8" rx="2"/><path d="M7 7h1m-1 10h1"/>',shield:'<path d="M12 2 3 6v6c0 5 5 8 9 10 4-2 9-5 9-10V6z"/><path d="m8 12 3 3 5-6"/>',alert:'<path d="M12 3 2 21h20zM12 9v5m0 3v1"/>',bell:'<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',off:'<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4M3 3l18 18"/>'};
function v174Icon(name){const el=document.createElementNS('http://www.w3.org/2000/svg','svg');el.setAttribute('viewBox','0 0 24 24');el.setAttribute('fill','none');el.setAttribute('stroke','currentColor');el.setAttribute('stroke-width','1.6');el.setAttribute('aria-hidden','true');el.classList.add('v174Icon');el.innerHTML=svgPaths[name]||svgPaths.shield;return el}
function v174Span(text,color){const e=document.createElement('span');e.textContent=text;if(color){e.className='v174Color';e.style.color=color}return e}
function v174Card(id,title,icon,right=''){
 const val=document.getElementById(id),card=val?.closest('.card');if(!card)return null;
 const label=card.querySelector('.label');if(label){label.classList.add('v174Label');label.replaceChildren();if(warnPrefs.icons)label.append(v174Icon(icon));label.append(v174Span(title));if(right){const r=v174Span(right);r.className='v174Right';label.append(r)}}
 return card;
}
function v174Value(id,v,stops){const e=document.getElementById(id);if(e){e.classList.add('v174Color');e.style.color=v174Color(v,stops)}}
function v174Sub(id,...parts){const e=document.getElementById(id);if(e)e.replaceChildren(...parts)}
function v174Line(text,color){const e=v174Span(text,color);e.classList.add('v174Line');return e}
function v174Temp(v){return v174Valid(v)?v.toLocaleString('de-DE',{maximumFractionDigits:1})+' °C':'n/v'}
function v174Bytes(v){if(!v174Valid(v)||v<0)return 'n/v';const units=['B','kB','MB','GB','TB'];let i=0;while(v>=1000&&i<4){v/=1000;i++}return v.toLocaleString('de-DE',{maximumFractionDigits:1})+' '+units[i]}
function v176MB(v){return v174Valid(v)&&v>=0?(v/1000000).toLocaleString('de-DE',{maximumFractionDigits:0})+' MB':'n/v'}
function v176SecuritySummary(sample,now=Date.now()){
 const age=now-Date.parse(sample?.checked||'');const s=sample?.security;
 if(!Number.isFinite(age)||age<0||age>35000||!s)return {state:'unknown',label:'n/v',rows:[]};
 if(s.active===false)return {state:'inactive',label:'Inaktiv',rows:[]};
 if(s.active!==true)return {state:'unknown',label:'n/v',rows:[]};
 const rows=['sshd','proxmox-nginx'].map(name=>{const j=s.jails?.[name];return {name,ok:j?.ok===true,banned:Number.isSafeInteger(j?.banned)&&j.banned>=0?j.banned:null,failed:Number.isSafeInteger(j?.failed)&&j.failed>=0?j.failed:null,nftables:j?.nftables===true,pushover:j?.pushover===true,actionsKnown:j?.actions_known===true}});
 const known=rows.every(j=>j.ok&&j.banned!==null&&j.failed!==null&&j.actionsKnown),protectedBoth=known&&rows.every(j=>j.nftables);
 const banned=known?rows.reduce((n,j)=>n+j.banned,0):null,failed=known?rows.reduce((n,j)=>n+j.failed,0):null;
 return {state:!known?'unknown':protectedBoth?'active':'partial',label:!known?'n/v':protectedBoth?'Aktiv':'Teilaktiv',rows,banned,failed,pushover:known&&rows.every(j=>j.pushover)};
}
function v176RenderSecurity(){
 const s=v176SecuritySummary(lastPing),card=v174Card('disk','Schutz · Fail2Ban','shield');if(!card)return;
 const color=s.state==='active'?vp.green:s.state==='inactive'?vp.red:s.state==='partial'?vp.amber:vp.muted;
 v175Set('disk',s.label,color);
 const rows=s.rows.map(j=>v175Row(j.name==='sshd'?'SSH':'Proxmox HTTPS',!j.ok||!j.actionsKnown?'n/v':j.nftables?'Aktiv':'Nicht geschützt',!j.ok||!j.actionsKnown?vp.muted:j.nftables?vp.green:vp.red));
 if(s.rows.length)rows.push(v175Row('IP-Sperren (aktiv)',s.banned===null?'n/v':String(s.banned),s.banned>0?vp.amber:s.banned===0?vp.green:vp.muted),v175Row('Fehlversuche (seit Start)',s.failed===null?'n/v':String(s.failed)),v175Row('Pushover-Aktion',s.state==='unknown'?'n/v':s.pushover?'Konfiguriert':'Nicht vollständig',s.state==='unknown'?vp.muted:s.pushover?vp.green:vp.amber));
 else rows.push(v174Line(s.state==='inactive'?'Fail2Ban-Dienst nicht aktiv':'Keine aktuellen Schutzdaten'));
 v174Sub('diskSub',...rows);v174Frame(card,s.state==='inactive'?2:s.state==='partial'||s.state==='active'&&s.banned>0?1:0);
}
function v175Percent(v){return v174Valid(v)?v.toLocaleString('de-DE',{minimumFractionDigits:1,maximumFractionDigits:1})+' %':'n/v'}
function v175Ratio(v,max){return v174Valid(v)&&v174Valid(max)&&max>0?Math.max(0,Math.min(100,v/max*100)):null}
function v175Row(label,value,color){const e=document.createElement('div');e.className='v175Row';e.append(v174Span(label),v174Span(value,color));return e}
function v175Bar(value,color,track){const e=document.createElement('div');e.className='v175Bar';e.hidden=!warnPrefs.bars||!v174Valid(value);e.setAttribute('aria-hidden','true');if(track)e.style.background=track;const b=document.createElement('span');b.style.width=Math.max(0,Math.min(100,value||0))+'%';b.style.background=color;e.append(b);return e}
function v175Set(id,text,color){const e=document.getElementById(id);if(e){e.textContent=text;e.classList.add('v174Color');if(color)e.style.color=color}}
function v175NetRate(v){return v174Valid(v)?warnPrefs.netUnit==='mbit'?(v*8/1000000).toLocaleString('de-DE',{maximumFractionDigits:2})+' Mbit/s':decimalTransferRate(v):'n/v'}
let v175PowerHistory=[],v175LastPower=0,v175Ups=null;
function v175PowerGraph(d){const p=localHostPower(d);if(lastMetricsAt!==v175LastPower){v175LastPower=lastMetricsAt;if(v174Valid(p.value))v175PowerHistory.push({v:p.value,t:lastMetricsAt,total:p.total});v175PowerHistory=v175PowerHistory.filter(x=>Date.now()-x.t<=900000).slice(-120)}const rows=v175PowerHistory.filter(x=>x.total===p.total);const c=v174Card('power','Leistung','cpu');if(!c)return;v175Set('power',v174Valid(p.value)?p.value.toLocaleString('de-DE',{minimumFractionDigits:2,maximumFractionDigits:2})+' W':'n/v',vp.white);const detail=v174Line(p.label);if(rows.length<2){v174Sub('powerSub',detail);return}const min=Math.min(...rows.map(x=>x.v)),max=Math.max(...rows.map(x=>x.v));const graph=document.createElementNS('http://www.w3.org/2000/svg','svg');graph.setAttribute('viewBox','0 0 240 24');graph.setAttribute('preserveAspectRatio','none');graph.classList.add('v175Graph');const path=document.createElementNS(graph.namespaceURI,'polyline');path.setAttribute('points',rows.map((x,i)=>(i/(rows.length-1)*240)+','+(22-(x.v-min)/(max-min||1)*20)).join(' '));path.setAttribute('fill','none');path.setAttribute('stroke','#60A5FA');path.setAttribute('stroke-width','1.5');graph.append(path);v174Sub('powerSub',detail,graph,v175Row('Min. / Max. (15 Min.)',min.toFixed(1).replace('.',',')+' / '+max.toFixed(1).replace('.',',')+' W'))}
function v175RenderUps(){const u=v175Ups;if(!u?.ok)return;const card=document.getElementById('upsCard'),sub=document.getElementById('upsSub'),meter=document.getElementById('upsMeter');if(!card||!sub)return;const charge=u.battery_charge_pct==null?null:Number(u.battery_charge_pct),load=u.load_pct==null?null:Number(u.load_pct),runtime=u.runtime_remaining_min==null?null:Number(u.runtime_remaining_min);const color=v174Valid(charge)?v174Color(charge,[[15,vp.red],[30,vp.amber],[40,vp.green]]):vp.muted;if(meter){meter.style.background=color;meter.parentElement.hidden=!warnPrefs.bars}v175Set('upsValue',v175Percent(charge),color);const source=typeof upsSourceText==='function'?upsSourceText(u.power_source):String(u.power_source||'n/v');sub.replaceChildren(v175Row('Quelle',source),v175Row('Auslastung',v175Percent(load)),v175Bar(load,vp.white),v175Row('Restlaufzeit',v174Valid(runtime)?Math.round(runtime)+' Min.':'n/v'));v174Frame(card,v174Valid(charge)&&charge<15?2:v174Valid(charge)&&charge<30?1:0)}

function v174Frame(card,level){if(!card)return;card.classList.toggle('v174Warning',warnPrefs.frames&&level===1);card.classList.toggle('v174Critical',warnPrefs.frames&&level===2);card.classList.toggle('v174Glow',warnPrefs.glow&&warnPrefs.frames&&level>0)}
const level=(v,a,b)=>!v174Valid(v)?0:v>=b?2:v>=a?1:0;
function renderMetrics(d){
 v175Observer?.disconnect();try{
 const cpu=v174Card('cpu','CPU','cpu',v174Valid(d.cpu_freq)?(d.cpu_freq/1000).toLocaleString('de-DE',{minimumFractionDigits:1,maximumFractionDigits:1})+' GHz':'');
 v175Set('cpu',v175Percent(d.cpu_percent),v174Color(d.cpu_percent,usageStops()));v174Sub('cpuSub',v175Bar(d.cpu_percent,v174Color(d.cpu_percent,usageStops())),v175Row('CPU',v174Temp(d.cpu_temp),v174Color(d.cpu_temp,tempStops())),v175Row('Board',v174Temp(d.board_temp),v174Color(d.board_temp,tempStops())),v175Row('SSD',v174Temp(d.drive_temp),v174Color(d.drive_temp,tempStops(50,70))));
 v174Frame(cpu,Math.max(level(d.cpu_percent,55,80),level(d.cpu_temp,50,76),level(d.board_temp,50,76),level(d.drive_temp,50,70)));
 v176RenderSecurity();
 const ram=v174Card('ram','RAM / SSD / Swap','ram',v174Bytes(d.ram_total));
 v175Set('ram',v175Percent(d.ram_percent),v174Color(d.ram_percent,usageStops(70,90)));
 const diskColor=v174Color(d.root_percent,usageStops());
 v174Sub('ramSub',v175Bar(d.ram_percent,v174Color(d.ram_percent,usageStops(70,90))),v175Row('RAM belegt',v174Bytes(d.ram_used)),v175Row('SSD (System)',v175Percent(d.root_percent),diskColor),v175Bar(d.root_percent,diskColor),v175Row('SSD belegt',v176MB(d.root_used)),v175Row('Swap',v175Percent(d.swap_percent),v174Color(d.swap_percent,usageStops(30,60))),v175Bar(d.swap_percent,v174Color(d.swap_percent,usageStops(30,60))));
 v174Frame(ram,Math.max(level(d.ram_percent,70,90),level(d.root_percent,55,80),level(d.swap_percent,30,60)));
 const guests=v174Card('guests','VM / LXC','server');
 const valid=[d.vm_running,d.vm_total,d.ct_running,d.ct_total].every(v174Valid);
 if(valid){const a=d.vm_running+d.ct_running,total=d.vm_total+d.ct_total,vm=d.vm_running===d.vm_total,ct=d.ct_running===d.ct_total;const e=document.getElementById('guests');e.classList.remove('v174Guests');v175Set('guests',a+' Aktiv',a===total?vp.green:a===0?vp.red:vp.yellow);v174Sub('guestSub',v175Row('Virtuelle Maschinen',d.vm_running+'/'+d.vm_total,vm?vp.green:vp.red),v175Bar(v175Ratio(d.vm_running,d.vm_total),vp.green,vp.red),v175Row('LXC-Container',d.ct_running+'/'+d.ct_total,ct?vp.green:vp.red),v175Bar(v175Ratio(d.ct_running,d.ct_total),vp.green,vp.red));v174Frame(guests,a===total?0:a===0?2:1)}
 const pi=v174Card('piholeBlockedPct','Pi-hole','shield',v174Valid(d.pihole_queries_total)?'Daten verfügbar':'n/v'),pct=d.pihole_blocked_percent,pc=v174Color(pct,[[50,vp.white],[60,vp.red]]),number=v=>v174Valid(v)?v.toLocaleString('de-DE'):'n/v';v175Set('piholeBlockedPct',v175Percent(pct),pc);v174Sub('piholeBlockedSub',v175Bar(pct,pc),v175Row('Anfragen',number(d.pihole_queries_total)),v175Row('Blockiert',number(d.pihole_queries_blocked),pc),v175Row('Zugelassen',v174Valid(d.pihole_queries_total)&&v174Valid(d.pihole_queries_blocked)?number(Math.max(0,d.pihole_queries_total-d.pihole_queries_blocked)):'n/v',vp.green));v174Frame(pi,level(pct,60,60));
 v174Card('net','Netzwerk','net');v175Set('net','↓ '+v175NetRate(d.net_rx_bps),vp.white);v174Sub('netSub',v175Bar(v175Ratio(d.net_rx_bps,Number(warnPrefs.netDown)*125000),vp.green),v175Row('↑ Upload',v175NetRate(d.net_tx_bps),'#60A5FA'),v175Bar(v175Ratio(d.net_tx_bps,Number(warnPrefs.netUp)*125000),'#60A5FA'));renderPing();
 v175PowerGraph(d);v175RenderUps();evaluateWarnings(d);
 }finally{v175Watch()}
}
function renderPing(){
 const e=document.getElementById('netSub');if(!e)return;
 let line=document.getElementById('v174Ping');if(!line){line=v174Line('');line.id='v174Ping';e.append(line)}
 if(!warnPrefs.ping){line.hidden=true;return}line.hidden=false;
 const providers=Array.isArray(warnPrefs.providers)?warnPrefs.providers.filter(x=>['Google','Quad9','Cloudflare'].includes(x)):warnDefaults.providers;
 if(!providers.length){line.textContent='Ping: keine Ziele';return}
 const now=Date.now();if(now-pingRotated>=(Number(warnPrefs.pingInterval)||15)*1000){pingIndex=(pingIndex+1)%providers.length;pingRotated=now}
 const name=providers[pingIndex%providers.length],fresh=lastPing&&now-Date.parse(lastPing.checked)<35000,v=fresh?lastPing.targets?.[name]:undefined;
 line.textContent='Ping: '+name+' · '+(v174Valid(v)?Math.round(v)+' ms':v===null?'Timeout':'n/v');line.style.color=!warnPrefs.pingColors?vp.white:v===null?vp.red:v174Color(v,pingStops);
}
async function fetchPing(){try{const r=await fetch('/dashboard-ping-v174.json',{cache:'no-store'});if(!r.ok)throw Error();lastPing=await r.json()}catch{lastPing=null}v175Observer?.disconnect();try{renderPing();v176RenderSecurity()}finally{v175Watch()}if(lastMetrics)evaluateWarnings(lastMetrics)}
function evaluateWarnings(d){
 const now=Date.now(),checks=[['CPU-Auslastung',d.cpu_percent,80,60],['RAM-Auslastung',d.ram_percent,90,60],['Swap-Auslastung',d.swap_percent,60,60],['CPU-Temperatur',d.cpu_temp,76,10],['Board-Temperatur',d.board_temp,76,10],['SSD-Temperatur',d.drive_temp,70,10],['Speicherbelegung',d.root_percent,80,30],['Pi-hole-Blockrate',d.pihole_blocked_percent,60,30]];
 if([d.vm_running,d.vm_total,d.ct_running,d.ct_total].every(v174Valid))checks.push(['VM / LXC offline',d.vm_total+d.ct_total-d.vm_running-d.ct_running,1,30]);
 if(lastPing&&now-Date.parse(lastPing.checked)<35000&&lastPing.targets)checks.push(['Internet-Ping',Object.values(lastPing.targets).length===3&&Object.values(lastPing.targets).every(v=>v===null)?1:0,1,30]);
 if(now-lastMetricsAt>45000){checks.length=0;checks.push(['Messdaten veraltet',1,1,0])}
 for(const [name,v,limit,delay] of checks){const bad=v174Valid(v)&&v>=limit;let w=activeWarnings.get(name);if(!bad){if(w?.confirmed){warningHistory.unshift({name,at:new Date().toISOString(),event:'Behoben'});saveLocal('dashboard.warningHistoryV174',warningHistory=warningHistory.slice(0,50))}activeWarnings.delete(name);continue}if(!w){w={since:now,confirmed:false,heard:false};activeWarnings.set(name,w)}if(!w.confirmed&&now-w.since>=delay*1000){w.confirmed=true;warningHistory.unshift({name,at:new Date().toISOString(),event:'Aktiv'});saveLocal('dashboard.warningHistoryV174',warningHistory=warningHistory.slice(0,50))}}
 const confirmed=[...activeWarnings].filter(([n,w])=>w.confirmed);renderSystemStatus(confirmed);if(confirmed.some(([n,w])=>!w.heard)&&!isSnoozed()&&warnPrefs.sound&&playAlarm())confirmed.forEach(([n,w])=>w.heard=true);
}
function stopAlarm(){for(const n of alarmNodes){try{n.stop()}catch{}}alarmNodes=[];alarmBusy=0}
function unlockAlarm(){try{const A=window.AudioContext||window.webkitAudioContext;if(!A)return;if(!alarmContext)alarmContext=new A();if(alarmContext.state!=='running')alarmContext.resume().catch(()=>{})}catch{}}
function playAlarm(){
 if(!alarmContext||alarmContext.state!=='running'||alarmContext.currentTime<alarmBusy||window.__dashboardUpdateAudioBusy?.())return false;
 const c=alarmContext,t=c.currentTime+.02;alarmBusy=t+2.5;
 for(const [offset,hz] of [[0,440],[.55,554.37],[1.1,659.25]]){const o=c.createOscillator(),g=c.createGain();o.frequency.value=hz;o.type='sine';g.gain.setValueAtTime(.0001,t+offset);g.gain.exponentialRampToValueAtTime(Math.max(.0002,.12*Math.max(0,Math.min(100,Number(warnPrefs.volume)||0))/100),t+offset+.05);g.gain.exponentialRampToValueAtTime(.0001,t+offset+1.2);o.connect(g);g.connect(c.destination);o.start(t+offset);o.stop(t+offset+1.25);alarmNodes.push(o);o.onended=()=>{o.disconnect();g.disconnect();alarmNodes=alarmNodes.filter(n=>n!==o)}}return true;
}
window.__dashboardWarningAudioBusy=()=>!!alarmContext&&alarmContext.currentTime<alarmBusy;
document.addEventListener('pointerdown',unlockAlarm);document.addEventListener('keydown',unlockAlarm);
function isSnoozed(){return snooze?.permanent===true||Number(snooze?.until)>Date.now()}
function setSnooze(minutes){snooze=minutes===0?null:minutes===-1?{permanent:true}:{until:Date.now()+minutes*60000,duration:minutes*60000};saveLocal(snoozeKey,snooze);if(isSnoozed())stopAlarm();else activeWarnings.forEach(w=>w.heard=false);renderSnooze()}
function installSnooze(){
 if(document.getElementById('v174Snooze'))return;
 const wrap=document.createElement('div');wrap.id='v174Snooze';wrap.innerHTML='<div class="v174SnoozeMenu" hidden><strong>Systemwarntöne</strong><div data-snooze-options></div></div><button type="button" class="v174SnoozeButton" aria-label="Systemwarntöne schlummern" aria-expanded="false"><span data-snooze-time></span><span class="v174Z" hidden><i>z</i><i>Z</i><i>Z</i></span><span class="v174Bell"></span></button>';
 const menu=wrap.querySelector('.v174SnoozeMenu'),button=wrap.querySelector('button');
 for(const [n,label] of [[5,'5 Minuten'],[10,'10 Minuten'],[30,'30 Minuten'],[60,'60 Minuten'],[-1,'Dauerhaft deaktivieren'],[0,'Warntöne aktivieren']]){const b=document.createElement('button');b.type='button';b.textContent=label;b.addEventListener('click',()=>{setSnooze(n);menu.hidden=true;button.setAttribute('aria-expanded','false')});wrap.querySelector('[data-snooze-options]').append(b)}
 button.addEventListener('click',()=>{menu.hidden=!menu.hidden;button.setAttribute('aria-expanded',String(!menu.hidden))});document.body.append(wrap);
}
function renderSnooze(){
 installSnooze();const wrap=document.getElementById('v174Snooze'),now=Date.now();if(snooze&&!snooze.permanent&&snooze.until<=now){snooze=null;saveLocal(snoozeKey,null);activeWarnings.forEach(w=>w.heard=false)}
 const timed=isSnoozed()&&!snooze.permanent,permanent=snooze?.permanent===true,remaining=timed?Math.max(0,snooze.until-now):0,ratio=timed?remaining/snooze.duration:0;
 const color=timed?v174Color(100-ratio*100,[[0,vp.amber],[25,vp.yellow],[50,vp.green],[75,'#22D3EE'],[85,vp.blue],[100,vp.blue]]):permanent||!warnPrefs.sound?vp.red:vp.green;
 wrap.style.setProperty('--snooze-color',color);wrap.style.setProperty('--snooze-progress',Math.max(0,Math.min(1,ratio))*360+'deg');
 const seconds=Math.ceil(remaining/1000);wrap.querySelector('[data-snooze-time]').textContent=timed?String(Math.floor(seconds/60)).padStart(2,'0')+':'+String(seconds%60).padStart(2,'0'):permanent?'Stumm':'';
 wrap.querySelector('.v174Z').hidden=!timed;const bell=wrap.querySelector('.v174Bell');bell.classList.toggle('timed',timed);const state=timed||permanent||!warnPrefs.sound?'off':'bell';if(bell.dataset.state!==state){bell.dataset.state=state;bell.replaceChildren(v174Icon(state))}
}
function renderSystemStatus(confirmed){
 const host=document.querySelector('.toolbarCenter');if(!host)return;
 let b=document.getElementById('v174SystemStatus');if(!b){b=document.createElement('button');b.type='button';b.id='v174SystemStatus';b.addEventListener('click',()=>{const p=document.getElementById('v174WarningList');if(p)p.hidden=!p.hidden});host.append(b)}
 b.replaceChildren(v174Icon(confirmed.length?'alert':'shield'),v174Span(confirmed.length?confirmed.length+' Kritisch':'System OK'));b.style.color=confirmed.length?vp.red:vp.green;
 let list=document.getElementById('v174WarningList');if(!list){list=document.createElement('aside');list.id='v174WarningList';list.hidden=true;document.body.append(list)}list.replaceChildren(v174Line('Systemwarnungen'));for(const [name,w] of confirmed)list.append(v174Line(name+' · seit '+new Date(w.since).toLocaleTimeString('de-DE'),vp.red));if(!confirmed.length)list.append(v174Line('Keine bestätigten kritischen Warnungen',vp.green));
}
function installWarningSettings(){
 if(document.getElementById('v174WarningSettings'))return;
 const anchor=document.getElementById('settingsSave')?.closest('.modalButtons');if(!anchor)return;
 const panel=document.createElement('section');panel.id='v174WarningSettings';panel.className='browserTabSettings';
 panel.innerHTML='<h3>Systemwarnungen und Ping</h3><div data-v174-options></div><label>Lautstärke System Alert <input type="range" min="0" max="100" step="1" data-v174-volume><span data-v174-volume-label></span></label><label>Ping-Wechsel <select data-v174-interval><option>5</option><option>10</option><option>15</option><option>20</option><option>30</option><option>60</option></select> Sekunden</label><div data-v174-providers></div><button type="button" data-v174-test>Systemwarnton testen</button><details><summary>Warnungshistorie (Browser)</summary><div data-v174-history></div></details>';
 const opts=panel.querySelector('[data-v174-options]');for(const [key,label] of [['sound','Systemwarnton'],['frames','Dynamische Rahmen'],['icons','Kachel-Symbole'],['glow','Leuchteffekt'],['ping','Ping-Anzeige'],['pingColors','Ping-Farbverlauf'],['bars','Fortschrittsbalken']]){const l=document.createElement('label'),i=document.createElement('input');i.type='checkbox';i.checked=!!warnPrefs[key];i.addEventListener('change',()=>{warnPrefs[key]=i.checked;if(!warnPrefs.sound)stopAlarm();saveLocal(warnKey,warnPrefs);if(lastMetrics)renderMetrics(lastMetrics)});l.append(i,document.createTextNode(label));opts.append(l)}
 const vol=panel.querySelector('[data-v174-volume]'),vl=panel.querySelector('[data-v174-volume-label]');vol.value=warnPrefs.volume;vl.textContent=vol.value+' %';vol.addEventListener('input',()=>{warnPrefs.volume=Number(vol.value);vl.textContent=vol.value+' %';saveLocal(warnKey,warnPrefs)});
 const interval=panel.querySelector('[data-v174-interval]');interval.value=warnPrefs.pingInterval;interval.addEventListener('change',()=>{warnPrefs.pingInterval=Number(interval.value);saveLocal(warnKey,warnPrefs)});
 for(const name of warnDefaults.providers){const l=document.createElement('label'),i=document.createElement('input');i.type='checkbox';i.checked=warnPrefs.providers.includes(name);i.addEventListener('change',()=>{warnPrefs.providers=i.checked?[...new Set([...warnPrefs.providers,name])]:warnPrefs.providers.filter(n=>n!==name);saveLocal(warnKey,warnPrefs);renderPing()});l.append(i,document.createTextNode(name));panel.querySelector('[data-v174-providers]').append(l)}
 panel.querySelector('[data-v174-test]').addEventListener('click',()=>{unlockAlarm();if(!isSnoozed())playAlarm()});
 const h=panel.querySelector('[data-v174-history]');for(const w of warningHistory.slice(0,20))h.append(v174Line(w.event+' · '+w.name+' · '+new Date(w.at).toLocaleString('de-DE')));
 const net=document.createElement('div');net.innerHTML='<label>Download-Maximum (Mbit/s, 0 = kein Balken) <input type="number" min="0" max="1000000" data-down></label><label>Upload-Maximum (Mbit/s, 0 = kein Balken) <input type="number" min="0" max="1000000" data-up></label><label>Netzwerkeinheit <select data-unit><option value="mb">MB/s</option><option value="mbit">Mbit/s</option></select></label>';for(const [sel,key] of [['[data-down]','netDown'],['[data-up]','netUp'],['[data-unit]','netUnit']]){const e=net.querySelector(sel);e.value=warnPrefs[key];e.addEventListener('change',()=>{warnPrefs[key]=key==='netUnit'?e.value:Math.max(0,Math.min(1000000,Number(e.value)||0));saveLocal(warnKey,warnPrefs);if(lastMetrics)renderMetrics(lastMetrics)})}panel.append(net);
 anchor.before(panel);
}
let v175Observer=null,v175Pending=false;
function v175Observe(){if(v175Observer||typeof MutationObserver!=='function')return;v175Observer=new MutationObserver(()=>{if(v175Pending)return;v175Pending=true;window.setTimeout(()=>{v175Pending=false;if(lastMetrics&&Date.now()-lastMetricsAt<45000)renderMetrics(lastMetrics)},0)});v175Watch()}
function v175Watch(){if(!v175Observer)return;for(const id of ['cpu','cpuSub','disk','diskSub','ram','ramSub','guests','guestSub','piholeBlockedPct','piholeBlockedSub','net','netSub','power','powerSub','upsValue','upsSub']){const e=document.getElementById(id);if(e)v175Observer.observe(e,{childList:true,characterData:true,subtree:true})}}
function v174Tick(){renderSnooze();installWarningSettings();v175Observe();if(lastMetrics){v175Observer?.disconnect();try{renderPing();v176RenderSecurity()}finally{v175Watch()}evaluateWarnings(lastMetrics)}}
window.addEventListener('storage',e=>{if(e.key===snoozeKey){snooze=readLocal(snoozeKey,null);if(isSnoozed())stopAlarm();renderSnooze()}if(e.key===warnKey){warnPrefs={...warnDefaults,...readLocal(warnKey,{})};if(!warnPrefs.sound)stopAlarm()}});
window.setInterval(v174Tick,1000);window.setInterval(fetchPing,10000);
window.setTimeout(()=>{v174Tick();fetchPing()},0);

if(typeof getJSON==='function'){
  const originalGetJSON=getJSON;
  getJSON=async function(url,...args){
    const data=await originalGetJSON.call(this,url,...args);
    if(typeof url==='string'&&url.split('?')[0]==='/api/current'&&data&&typeof data==='object'){
      tabMetrics=data;tabMetricsTime=Date.now();refreshTabTitle();
      lastMetrics=data;lastMetricsAt=Date.now();
    }
    if(typeof url==='string'&&url.split('?')[0]==='/api/ups')v175Ups=data;
    return data;
  };
}
if(typeof current==='function'){
 const originalCurrent=current;
 current=async function(...args){try{return await originalCurrent.apply(this,args)}finally{if(lastMetrics&&Date.now()-lastMetricsAt<45000)renderMetrics(lastMetrics)}};
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
