const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const source = fs.readFileSync("dashboard/views/runtime.js", "utf8");
function render(configured, fallback, updated) {
  const listeners = new Map();
  function node() { return { textContent: "", classList: {add(){},toggle(){}}, style: {}, children: [], setAttribute(){}, append(...items){this.children.push(...items)}, addEventListener(){}, remove(){} }; }
  const body = node();
  const document = { readyState: "complete", body, documentElement: node(),
    getElementById(id){ return id==="websiteTitle" ? {textContent:fallback} : null; },
    querySelectorAll(){return []},querySelector(){return null},createElement(){return node();} };
  const window = {PROXMOX_DASHBOARD_VIEW:"boot",__proxmoxUiSettings:configured===undefined?{}:{website_name:configured},
    matchMedia(){return {matches:false}},setTimeout(){},addEventListener(k,fn){listeners.set(k,fn)},removeEventListener(k){listeners.delete(k)}};
  vm.runInNewContext(source,{document,window});
  const title=body.children[0].children[0].children[1];
  if(updated!==undefined)listeners.get("dashboard-branding-ready")({detail:{website_name:updated}});
  return title.textContent;
}
assert.equal(render("Dashboard LT-WBH",""),"LT-WBH");
assert.equal(render("dashboard: LT-WBH",""),"LT-WBH");
assert.equal(render("Dashboard – LT-WBH",""),"LT-WBH");
assert.equal(render("LT-WBH",""),"LT-WBH");
assert.equal(render("My Dashboard",""),"My Dashboard");
assert.equal(render("Dashboarding",""),"Dashboarding");
assert.equal(render(undefined,"Dashboard LT-WBH"),"LT-WBH");
assert.equal(render(undefined,"PVE Hardware Monitor","Dashboard LT-WBH"),"LT-WBH");
assert.equal(render("Dashboard",""),"");
console.log("Boot title regression tests passed");
