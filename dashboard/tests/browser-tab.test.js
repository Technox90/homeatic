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
  window:{setTimeout(){return ++timer},clearTimeout(){},addEventListener(){}},
  bytes:originalBytes,rate:v=>'legacy',draw:(id,series,opt)=>opt.y(1000000),
  setTimeout(){},console
});
const expose=String.raw`
globalThis.tabTest={
  normalizeTabSettings,buildTabFrames,refreshTabTitle,setTabUpdateStatus,localHostPower,decimalTransferRate,
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
