const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync('dashboard/index.html', 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
function setup(failSignIn = false) {
  const elements = new Map();
  function element() { return {disabled:false, value:'', elements:{email:{value:'demo@example.com'},password:{value:'password'},username:{value:''}},addEventListener(event, handler){this[event]=handler},reset(){},close(){},append(){},replaceChildren(){},focus(){}}; }
  const storage = new Map([['masdan-open-webui-token','admin-token']]);
  const requests=[];
  const context={document:{querySelector(selector){if(!elements.has(selector))elements.set(selector,element());return elements.get(selector)},createElement:element}, sessionStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v),removeItem:k=>storage.delete(k)},window:{setTimeout(){},clearTimeout(){}},fetch:async(url,options={})=>{
    requests.push({url,...options});
    const body=url.endsWith('/auths/add')?{id:'demo-id'}:url.endsWith('/auths/signin')?(failSignIn?{}:{token:'demo-token',email:'demo@example.com',role:'user'}):{items:[]};
    return {ok:!(failSignIn&&url.endsWith('/signin')),json:async()=>body};
  }};
  vm.createContext(context); vm.runInContext(source,context);
  return {context,elements,storage,requests};
}
test('creating demo credentials replaces admin session before listing/importing',async()=>{
 const s=setup();
 await s.elements.get('#create-credentials-form').submit({preventDefault(){}});
 assert.equal(s.requests[0].headers.Authorization,'Bearer admin-token');
 assert.equal(s.storage.get('masdan-open-webui-token'),'demo-token');
 assert.equal(s.requests.find(r=>r.url.endsWith('/automations/list')).headers.Authorization,'Bearer demo-token');
 assert.equal(s.elements.get('#open-create-credentials-button').disabled,true);
 assert.equal(vm.runInContext('token',s.context),'demo-token');
 vm.runInContext('template = {name: "Demo-owned pack", data: {prompt: "Report"}}', s.context);
 await s.elements.get('#import-button').click();
 assert.equal(s.requests.find(r=>r.url.endsWith('/automations/create')).headers.Authorization,'Bearer demo-token');
});
test('switching accounts discards the previous account library',async()=>{
 const s=setup();
 vm.runInContext('automations = [{id: "admin-pack", name: "Admin-only pack"}]',s.context);
 await s.elements.get('#sign-in-form').submit({preventDefault(){}});
 assert.equal(vm.runInContext('automations.length',s.context),0);
 assert.equal(s.storage.get('masdan-open-webui-token'),'demo-token');
});
test('a delayed administrator list response cannot replace the demo library',async()=>{
 const s=setup();
 let respond;
 s.context.fetch=()=>new Promise(resolve=>{respond=resolve});
 const pending=vm.runInContext('loadAutomations()',s.context);
 vm.runInContext('clearAccount(); useAccount({token:"demo-token",email:"demo@example.com",role:"user"})',s.context);
 respond({ok:true,json:async()=>({items:[{id:'admin-pack'}]})});
 await pending;
 assert.equal(vm.runInContext('automations.length',s.context),0);
});
test('failed demo sign-in never falls back to administrator credentials',async()=>{
 const s=setup(true);
 await s.elements.get('#create-credentials-form').submit({preventDefault(){}});
 assert.equal(s.storage.has('masdan-open-webui-token'),false);
 assert.equal(vm.runInContext('token',s.context),null);
 assert.equal(s.elements.get('#import-button').disabled,true);
 assert.equal(s.requests.some(r=>r.url.endsWith('/automations/list')),false);
});
