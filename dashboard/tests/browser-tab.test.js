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
  normalizeTabSettings,buildTabFrames,refreshTabTitle,setTabUpdateStatus,localHostPower,decimalTransferRate,v174Color,v174Bytes,v175Ratio,v175Percent,v176MB,v176SecuritySummary,v176HostDate,v177Storage,v177Capacity,
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

assert.equal(t.v176MB(38130000000),'38,13 GB');
assert.equal(t.v176MB(0),'0 MB');
assert.equal(t.v176MB(949000000),'949 MB');
assert.equal(t.v176MB(950000000),'0,95 GB');
assert.equal(t.v176MB(1500000000),'1,50 GB');
assert.equal(t.v176MB(106450000000),'106,45 GB');
assert.equal(t.v176MB(-1),'n/v');
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

const storageTime=Date.now();
const storageSample={storage_checked:new Date(storageTime).toISOString(),storage:{complete:true,kind:'SSD',total:1000204886016,used:189090630000,available:758933280000,reserved:52180976016,root_percent:39.9,pool_percent:17.71}};
const sd=t.v177Storage(storageSample,storageTime);
assert.ok(sd);
assert.equal(sd.total,1000204886016);
assert.equal(t.v177Capacity(sd.total),'1.000,20 GB');
assert.equal(t.v175Percent(sd.percent),'18,9 %');
assert.equal(t.v177Storage(storageSample,storageTime+91000),null);
assert.equal(t.v177Storage({...storageSample,storage:{...storageSample.storage,used:0}},storageTime),null);
assert.equal(t.v177Storage({...storageSample,storage:{total:1000204886016,kind:'SSD',complete:false}},storageTime).complete,false);
console.log('V177 physical storage UI validation passed');

const storagePython=require('node:child_process').spawnSync('python3',['-c',String.raw`
import runpy, json
from types import SimpleNamespace
from unittest.mock import patch
m=runpy.run_path('proxmox/tools/proxmox-dashboard-ping')
g=m['storage_sample'].__globals__
disk=1000204886016
root=103079215104
pool=852332904448
def reply(args,**kw):
    name=args[0]
    if name=='findmnt': data={'filesystems':[{'maj:min':'253:1'}]}
    elif name=='lvs': data={'report':[{'lv':[
      {'vg_name':'pve','lv_name':'root','lv_size':str(root),'segtype':'linear','lv_kernel_major':'253','lv_kernel_minor':'1'},
      {'vg_name':'pve','lv_name':'data','lv_size':str(pool),'segtype':'thin-pool','data_percent':'17.71','lv_kernel_major':'253','lv_kernel_minor':'2'},
      {'vg_name':'pve','lv_name':'vm-102-disk-0','lv_size':str(64*1024**3),'segtype':'thin','lv_kernel_major':'253','lv_kernel_minor':'3'}]}]}
    elif name=='pvs': data={'report':[{'pv':[{'pv_name':'/dev/sda3','vg_name':'pve','pv_free':str(16*1024**3)}]}]}
    elif name=='lsblk' and '--nodeps' in args: data={'blockdevices':[{'name':'/dev/sda3','type':'part','pkname':'/dev/sda'}]}
    elif name=='lsblk': data={'blockdevices':[{'name':'/dev/sda','type':'disk','size':disk,'rota':False,'children':[{'name':'/dev/sda1','type':'part','fstype':None},{'name':'/dev/sda2','type':'part','fstype':'vfat'},{'name':'/dev/sda3','type':'part','fstype':'LVM2_member'}]}]}
    else: raise AssertionError(args)
    return SimpleNamespace(stdout=json.dumps(data))
with patch.object(g['subprocess'],'run',side_effect=reply),patch.object(g['os'],'statvfs',return_value=SimpleNamespace(f_blocks=98497780,f_bfree=61249288,f_bavail=56199740,f_frsize=1024)):
    s=m['storage_sample']()
    assert s is not None, s
    assert s['total']==disk and s['kind']=='SSD' and s['complete']
    assert s['used']==37248492*1024+int(pool*0.1771), s
    assert s['used']+s['available']+s['reserved']==disk, s
    assert s['pool_percent']==17.71 and s['vg_free']==16*1024**3
    assert s['root_percent']>39 and s['root_percent']<40
with patch.object(g['subprocess'],'run',side_effect=OSError()):
    assert m['storage_sample']() is None
`],{encoding:'utf8'});
assert.equal(storagePython.status,0,storagePython.stderr);
console.log('V177 physical LVM storage collection tests passed');
