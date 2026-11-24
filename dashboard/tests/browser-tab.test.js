const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync('dashboard/branding-v154.js','utf8');
const last=source.lastIndexOf('})();');
assert.ok(last>0);
const doc={title:'Dashboard LT-WBH',visibilityState:'visible',readyState:'loading',addEventListener(){}};
let saved=null, timer=0;
const ctx=vm.createContext({
  document:doc,
  localStorage:{getItem(){return saved},setItem(k,v){saved=v}},
  window:{setTimeout(){return ++timer},clearTimeout(){},addEventListener(){}},
  setTimeout(){},console
});
const expose=String.raw`
globalThis.tabTest={
  normalizeTabSettings,buildTabFrames,refreshTabTitle,setTabUpdateStatus,
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
assert.deepEqual(list(t.buildTabFrames('inactive')),['Dashboard LT-WBH','CPU 10 % | RAM 42 %','15,21 W']);
doc.visibilityState='hidden';t.refreshTabTitle(true);t.next();
assert.equal(doc.title,'CPU 10 % | RAM 42 %');
doc.visibilityState='visible';t.refreshTabTitle();
assert.equal(doc.title,'Dashboard LT-WBH');
t.setSettings({active:['ram'],inactive:['power'],interval:10});
assert.deepEqual(list(t.buildTabFrames('active')),['RAM 42 %']);
t.setMetrics({cpu_power_w:0});
assert.deepEqual(list(t.buildTabFrames('inactive')),['CPU 0,00 W']);
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
console.log('Browser tab title regression tests passed');
