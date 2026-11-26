const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync('dashboard/branding-v154.js','utf8');
const last=source.lastIndexOf('})();');
assert.ok(last>0);
const doc={title:'Dashboard LT-WBH',visibilityState:'visible',readyState:'loading',addEventListener(){}};
let saved=null, timer=0;
const originalBytes=v=>v+' MiB';
const ctx=vm.createContext({
  document:doc,
  localStorage:{getItem(){return saved},setItem(k,v){saved=v}},
  window:{setTimeout(){return ++timer},clearTimeout(){},setInterval(){return ++timer},clearInterval(){},addEventListener(){}},
  bytes:originalBytes,rate:v=>'legacy',draw:(id,series,opt)=>opt.y(1000000),
  setTimeout(){},console
});
const expose=String.raw`
globalThis.tabTest={
  normalizeTabSettings,buildTabFrames,refreshTabTitle,setTabUpdateStatus,localHostPower,decimalTransferRate,v174Color,v174Bytes,v175Ratio,v175Percent,v176MB,v176SecuritySummary,v176HostDate,
  setMetrics(d,when=Date.now()){tabMetrics=d;tabMetricsTime=when},
  setSettings(s){tabSettings=normalizeTabSettings(s)},
  next(){tabIndex++;refreshTabTitle()}
};
`;
vm.runInContext(source.slice(0,last)+expose+source.slice(last),ctx);
const t=ctx.tabTest, list=v=>Array.from(v);
assert.deepEqual(list(t.normalizeTabSettings(null).active),['name']);
assert.deepEqual(list(t.normalizeTabSettings(null).inactive),['name','cpu','ram','power']);
assert.deepEqual(list(t.normalizeTabSettings({active:[],inactive:['bad']}).active),['name']);
assert.deepEqual(list(t.buildTabFrames('active')),['Dashboard LT-WBH']);
t.setMetrics({cpu_percent:10,ram_percent:42,system_power_w:15.21,cpu_power_w:8});
assert.deepEqual(list(t.buildTabFrames('inactive')),['Dashboard LT-WBH','CPU 10 % | RAM 42 %','Leistung 15,21 W']);
doc.visibilityState='hidden';t.refreshTabTitle(true);t.next();
assert.equal(doc.title,'CPU 10 % | RAM 42 %');
doc.visibilityState='visible';t.refreshTabTitle();
assert.equal(doc.title,'Dashboard LT-WBH');
t.setSettings({active:['ram'],inactive:['power'],interval:10});
assert.deepEqual(list(t.buildTabFrames('active')),['RAM 42 %']);
t.setMetrics({cpu_power_w:0});
assert.deepEqual(list(t.buildTabFrames('inactive')),['Leistung 0,00 W']);
t.setMetrics({cpu_power_w:8},Date.now()-121000);
assert.deepEqual(list(t.buildTabFrames('inactive')),['Dashboard LT-WBH']);
const checked=new Date().toISOString();
t.setTabUpdateStatus({status:'available',local:161,remote:162,checked});
assert.deepEqual(list(t.buildTabFrames('active')),['Update verfügbar','Update V162','Dashboard LT-WBH']);
assert.equal(doc.title,'Update verfügbar');
t.next();assert.equal(doc.title,'Update V162');
t.setTabUpdateStatus({status:'current',local:162,remote:162,checked});
assert.equal(doc.title,'Dashboard LT-WBH');
t.setSettings({active:['name'],update:false});
t.setTabUpdateStatus({status:'available',local:162,remote:163,checked});
assert.deepEqual(list(t.buildTabFrames('active')),['Dashboard LT-WBH']);
const power=t.localHostPower;
assert.ok(Math.abs(power({cpu_power_w:17.2,cpu_core_power_w:16.4,uncore_power_w:0,dram_power_w:1.9}).value-19.1)<1e-9);
assert.equal(power({system_power_w:48,cpu_power_w:17,dram_power_w:2,gpu_power_w:20}).value,48);
assert.equal(power({system_power_w:48,cpu_power_w:17}).total,true);
assert.equal(power({cpu_power_w:17,dram_power_w:2,gpu_power_w:20}).value,19);
assert.equal(power({gpu_power_w:20}).value,20);
assert.equal(power({dram_power_w:2}).value,2);
assert.equal(power({cpu_core_power_w:4}).value,4);
assert.equal(power({cpu_power_w:null,dram_power_w:undefined,ups_power_w:100}).value,null);
assert.equal(power({cpu_power_w:0}).value,0);
assert.equal(power({cpu_power_w:-1,dram_power_w:"2"}).value,null);
t.setMetrics({cpu_power_w:17.2,dram_power_w:1.9});
t.setSettings({active:['power'],update:false});
assert.deepEqual(list(t.buildTabFrames('active')),['Leistung 19,10 W']);
console.log('Browser tab and local power regression tests passed');

const rate=t.decimalTransferRate;
assert.equal(rate(0),'0 B/s');
assert.equal(rate(999),'999 B/s');
assert.equal(rate(1000),'1 kB/s');
assert.equal(rate(1000000),'1 MB/s');
assert.equal(rate(1048576),'1,05 MB/s');
assert.equal(rate(12500000),'12,5 MB/s');
assert.equal(rate(1000000000),'1 GB/s');
assert.equal(rate(999999),'1 MB/s');
assert.equal(rate(null),'–');
assert.equal(rate(-1),'–');
assert.equal(ctx.rate(1000000),'1 MB/s');
assert.equal(ctx.draw('cNet',[],{}),'1 MB/s');
assert.equal(ctx.draw('cIO',[],{}),'1 MB/s');
assert.equal(ctx.draw('cMem',[],{y:originalBytes}),'1000000 MiB');
assert.equal(ctx.bytes,originalBytes);
console.log('Decimal transfer rates passed');

assert.equal(t.v174Color(49,[[50,'#FFFFFF'],[60,'#EF4444']]),'#FFFFFF');
assert.equal(t.v174Color(55,[[50,'#FFFFFF'],[60,'#EF4444']]),'rgb(247,162,162)');
assert.equal(t.v174Color(60,[[50,'#FFFFFF'],[60,'#EF4444']]),'rgb(239,68,68)');
assert.equal(t.v174Color(85,[[0,'#FFB020'],[85,'#3B82F6'],[100,'#3B82F6']]),'rgb(59,130,246)');
console.log('V174 color interpolation tests passed');

assert.equal(t.v174Bytes(100000000000),'100 GB');
assert.equal(t.v174Bytes(1073741824),'1,1 GB');
assert.equal(t.v175Ratio(50,100),50);
assert.equal(t.v175Ratio(50,0),null);
assert.equal(t.v175Percent(39.8),'39,8 %');
console.log('V175 decimal storage and ratio tests passed');

assert.equal(t.v176MB(38130000000),'38.130 MB');
assert.equal(t.v176MB(null),'n/v');
const checkDate=Date.now(), stamp=new Date(checkDate).toISOString();
const jail={ok:true,banned:0,failed:1,nftables:true,pushover:true,actions_known:true};
const sample={checked:stamp,security:{active:true,jails:{sshd:jail,'proxmox-nginx':{...jail,banned:2}}}};
const secure=t.v176SecuritySummary(sample,checkDate);
assert.equal(secure.state,'active');
assert.equal(secure.banned,2);
assert.equal(secure.failed,2);
assert.equal(secure.pushover,true);
assert.equal(t.v176SecuritySummary(sample,checkDate+36000).state,'unknown');
assert.equal(t.v176SecuritySummary({checked:stamp,security:{active:false}},checkDate).state,'inactive');
assert.equal(t.v176SecuritySummary({checked:stamp,security:{active:true,jails:{sshd:jail}}},checkDate).state,'unknown');
assert.equal(t.v176SecuritySummary({checked:stamp,security:{active:true,jails:{sshd:jail,'proxmox-nginx':{...jail,nftables:false}}}},checkDate).state,'partial');
console.log('V176 SSD MB and protection status tests passed');

const master=fs.readFileSync('proxmox/proxmox.sh','utf8');
const upperStart=master.indexOf('let upperZone='),upperEnd=master.indexOf('async function json(url)',upperStart);
assert.ok(upperStart>0&&upperEnd>upperStart);
const upper=vm.createContext({});
vm.runInContext(master.slice(upperStart,upperEnd)+'\n globalThis.upperTest={kumaEpoch,kumaLocal,kumaSort,setUpperZone};',upper);
const u=upper.upperTest;
assert.equal(u.kumaLocal('2026-11-26 18:05:35'),'—');
u.setUpperZone('Europe/Berlin');
assert.equal(u.kumaEpoch('2026-11-26 18:05:35'),Date.parse('2026-11-26T18:05:35Z'));
assert.equal(u.kumaEpoch('2026-11-26T19:05:35+01:00'),Date.parse('2026-11-26T18:05:35Z'));
assert.equal(u.kumaEpoch('2026-07-26T18:05:35.123Z'),Date.parse('2026-07-26T18:05:35.123Z'));
assert.match(u.kumaLocal('2026-11-26 18:05:35'),/19:05:35/);
assert.match(u.kumaLocal('2026-07-26 18:05:35'),/20:05:35/);
assert.match(u.kumaLocal('2026-03-29 01:00:00'),/03:00:00/);
assert.match(u.kumaLocal('2026-10-25 01:00:00'),/02:00:00/);
assert.equal(u.kumaLocal('invalid'),'—');
assert.ok(u.kumaSort({time:'2026-11-26T19:00:00+01:00'},{time:'2026-11-26 18:01:00'})<0);
u.setUpperZone('America/New_York');
assert.match(u.kumaLocal('2026-11-26 18:05:35'),/13:05:35/);
u.setUpperZone('UTC');
assert.match(u.kumaLocal('2026-11-26 18:05:35'),/18:05:35/);
assert.throws(()=>u.setUpperZone('not-a-zone'));
console.log('V176 UPPER host timezone conversion and DST tests passed');

assert.equal(t.v176HostDate('2026-11-26T18:05:35Z','Europe/Berlin',true),'19:05:35');
assert.equal(t.v176HostDate('2026-11-26T18:05:35Z','UTC',true),'18:05:35');
assert.equal(t.v176HostDate('2026-11-26T18:05:35Z','invalid',true),'n/v');
assert.equal(t.v176HostDate('2026-11-26T18:05:35Z',null,true),'n/v');
const python = require('node:child_process').spawnSync('python3',['-c',
  "import runpy; m=runpy.run_path('proxmox/tools/proxmox-managed-updates'); compile(m['DOCKER_ZONE_SCRIPT'],'docker-zone-script','exec'); assert m['DOCKER_TIMEZONES']['uptime-kuma'][2] == ('TZ',)"
],{encoding:'utf8'});
assert.equal(python.status,0,python.stderr);
console.log('V176 dashboard host timezone and managed Docker script syntax tests passed');
