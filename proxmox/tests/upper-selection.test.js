const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const master=fs.readFileSync('proxmox/proxmox.sh','utf8');
const html=master.split("<<'KUMA_STATUS_HTML'\n")[1].split("\nKUMA_STATUS_HTML\n")[0];
assert.match(html,/<form id="form" method="get" action="\/upper\/">/);
assert.match(html,/<input id="slug" name="slug"/);
assert.match(html,/#form\[hidden\]\{display:none!important\}/);
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
function page(search,ok=true,timezoneOk=true){
 const nodes=new Map();
 function node(){return {textContent:'',value:'',hidden:false,children:[],append(...c){this.children.push(...c)},replaceChildren(...c){this.children=c}}}
 const document={getElementById(id){if(!nodes.has(id))nodes.set(id,node());return nodes.get(id)},createDocumentFragment:node};
 let healthy=ok,tick,zone="Europe/Berlin",zoneHealthy=timezoneOk;
 const requests=[];
 const serverDate="Thu, 26 Nov 2026 18:05:35 GMT";
 const ctx=vm.createContext({document,location:{search},URLSearchParams,AbortSignal,
  fetch:async url=>{
   requests.push(url);
   const timezone=url==='/upper/timezone.json';
   return {ok:timezone?zoneHealthy:healthy,status:404,
    headers:{get:name=>name.toLowerCase()==='date'?serverDate:null},
    json:async()=>timezone?{timezone:zone}:url.includes('/heartbeat/')?{heartbeatList:{}}:{publicGroupList:[],config:{title:'Server'}}};
  },
  setInterval(fn){tick=fn}});
 vm.runInContext(script,ctx);
 return {nodes,document,ctx,requests,get calls(){return requests.length},fail(){healthy=false},failZone(){zoneHealthy=false},setZone(value){zone=value},tick:()=>tick()};
}
const settle=()=>new Promise(resolve=>setImmediate(resolve));
(async()=>{
 let p=page('');await settle();
 assert.equal(p.calls,0);assert.equal(p.document.getElementById('form').hidden,false);
 p=page('?slug=Server');await settle();
 assert.deepEqual(p.requests,['/api/status-page/Server','/api/status-page/heartbeat/Server','/upper/timezone.json']);
 assert.equal(p.document.getElementById('form').hidden,true);
 assert.equal(p.document.getElementById('title').textContent,'Server · Antwortzeiten');
 assert.match(p.document.getElementById('message').textContent,/19:05:35/);
 p.setZone('UTC');await p.tick();
 assert.equal(p.calls,6);
 assert.match(p.document.getElementById('message').textContent,/18:05:35/);
 p.failZone();await p.tick();
 assert.equal(p.document.getElementById('form').hidden,true);
 assert.match(p.document.getElementById('message').textContent,/Host-Zeit HTTP 404/);
 p=page('?slug=Server');await settle();
 p.fail();await p.tick();
 assert.equal(p.document.getElementById('form').hidden,true);
 assert.match(p.document.getElementById('message').textContent,/HTTP 404/);
 p=page('?slug=unknown',false);await settle();
 assert.equal(p.document.getElementById('form').hidden,false);
 assert.match(p.document.getElementById('message').textContent,/HTTP 404/);
 p=page('?slug=Server',true,false);await settle();
 assert.equal(p.document.getElementById('form').hidden,false);
 assert.match(p.document.getElementById('message').textContent,/Host-Zeit HTTP 404/);
 p=page('?slug=invalid%2Fname');await settle();
 assert.equal(p.calls,0);assert.equal(p.document.getElementById('form').hidden,false);
 console.log('UPPER selection regression tests passed');
})().catch(e=>{console.error(e);process.exitCode=1});
