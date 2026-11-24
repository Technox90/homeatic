/* NodeZero Dashboard Branding V150 */
function brandCompactV150(value){
  const raw=String(value||'LT-WBH').trim();
  const parts=raw.split(/[^A-Za-z0-9ÄÖÜäöü]+/).filter(Boolean);
  if(parts.length>=2)return (parts[0][0]+parts[1][0]).toUpperCase();
  return (raw.replace(/[^A-Za-z0-9ÄÖÜäöü]/g,'').slice(0,2)||'LT').toUpperCase();
}
function fixedToolbarV150(){
  const bar=document.querySelector('.toolbar'); if(!bar)return;
  let shell=document.getElementById('dashboardFixedToolbarV150');
  if(!shell){shell=document.createElement('div');shell.id='dashboardFixedToolbarV150';document.body.prepend(shell)}
  if(bar.parentElement!==shell)shell.appendChild(bar);
  document.body.classList.add('dashboardToolbarFixedV150');
  const items=[bar.querySelector('.menuBtn'),document.getElementById('state')?.closest('.live'),document.getElementById('upsTopState'),bar.querySelector('.reboot'),bar.querySelector('.danger')];
  items.filter(Boolean).forEach(function(el){bar.appendChild(el)});
}
function menuLogoV150(settings){
  const head=document.querySelector('#sideNav .navHead'); if(!head)return;
  let logo=document.getElementById('dashboardBrandLogoV150');
  if(!logo){
    logo=document.createElement('div');logo.id='dashboardBrandLogoV150';logo.className='brandLogoV150';
    logo.innerHTML='<span class="brandLogoIconV150"><span id="dashboardBrandCompactV150">LT</span></span><span id="dashboardBrandTextV150" class="brandLogoTextV150">LT-WBH</span>';
    head.prepend(logo);
  }
  const text=String(settings.logo_text||'LT-WBH').trim()||'LT-WBH';
  const style=['neon','orbit','pulse','minimal'].includes(String(settings.logo_style||'').toLowerCase())?String(settings.logo_style).toLowerCase():'neon';
  logo.dataset.style=style;
  document.getElementById('dashboardBrandTextV150').textContent=text;
  document.getElementById('dashboardBrandCompactV150').textContent=brandCompactV150(text);
}
function faviconV150(settings){
  if(settings.favicon_url)return;
  const c=document.createElement('canvas');c.width=64;c.height=64;
  const x=c.getContext('2d');if(!x)return;
  x.clearRect(0,0,64,64);
  const style=String(settings.logo_style||'neon').toLowerCase(),a=settings.theme_accent||'#64a7ff',b=settings.theme_accent2||'#9b7cff';
  x.lineWidth=3.5;x.lineJoin='round';x.lineCap='round';x.shadowBlur=8;x.shadowColor=a;x.strokeStyle=a;
  if(style==='orbit'){x.beginPath();x.ellipse(32,32,23,18,-.3,0,Math.PI*2);x.stroke();x.strokeStyle=b;x.beginPath();x.ellipse(32,32,17,25,.65,0,Math.PI*2);x.stroke()}
  else if(style==='pulse'){x.strokeRect(9,9,46,46);x.strokeStyle=b;x.beginPath();x.moveTo(12,34);x.lineTo(22,34);x.lineTo(27,24);x.lineTo(34,43);x.lineTo(40,31);x.lineTo(52,31);x.stroke()}
  else if(style==='minimal'){x.beginPath();x.roundRect(9,9,46,46,12);x.stroke()}
  else{x.beginPath();[[20,7],[44,7],[57,32],[44,57],[20,57],[7,32]].forEach(function(p,i){i?x.lineTo(p[0],p[1]):x.moveTo(p[0],p[1])});x.closePath();x.stroke();x.strokeStyle=b;x.beginPath();[[25,14],[39,14],[48,32],[39,50],[25,50],[16,32]].forEach(function(p,i){i?x.lineTo(p[0],p[1]):x.moveTo(p[0],p[1])});x.closePath();x.stroke()}
  x.shadowBlur=7;x.fillStyle='#eef5ff';x.font='900 18px system-ui';x.textAlign='center';x.textBaseline='middle';x.fillText(brandCompactV150(settings.logo_text),32,33);
  const link=ensureFaviconLink();link.type='image/png';link.href=c.toDataURL('image/png');
}
function applyBrandingV150(settings){settings=settings||{};menuLogoV150(settings);faviconV150(settings);fixedToolbarV150()}
if(typeof applyUiSettings==='function'){const oldApplyUiV150=applyUiSettings;applyUiSettings=function(s){const r=oldApplyUiV150(s);applyBrandingV150(s);return r}}
if(typeof setUpsTopState==='function'){const oldUpsV150=setUpsTopState;setUpsTopState=function(d){const r=oldUpsV150(d),t=document.getElementById('upsTopStateText');if(t&&d&&d.ok&&d.reachable&&String(d.power_source||'').toLowerCase()==='mains')t.textContent='USV Online';fixedToolbarV150();return r}}
setTimeout(async function(){fixedToolbarV150();try{applyBrandingV150(await getJSON('/api/ui-settings'))}catch(e){applyBrandingV150({logo_text:'LT-WBH',logo_style:'neon'})}},0);