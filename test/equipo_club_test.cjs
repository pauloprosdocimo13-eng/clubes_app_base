const {test} = require('node:test');
const assert = require('node:assert/strict');
const {gestionarEquipo} = require('../functions_tusede/equipo_club');
function entorno() {
 const datos = new Map([
 ['usuarios/admin',{rol:'admin',activo:true,clubIds:['demo']}],
 ['usuarios/ajeno',{rol:'admin',activo:true,clubIds:['otro']}],
 ['usuarios/empleado',{rol:'deportes',activo:true,clubIds:['demo']}],
 ['clubes/demo',{origenDatos:'central',estado:'activo',activo:true}],
 ['clubes/demo/configuracion/permisos_roles',{deportes:['Gestionar Plantel'],institucional:['Publicar Noticia']}],
 ]);
 const cuentas=new Map(); let secuencia=0; let antes;
 const snap=path=>({id:path.split('/').at(-1),exists:datos.has(path),data:()=>datos.get(path)});
 const db = {
   doc: path => ({path, get: async () => snap(path)}),
   collection: name => ({
     doc: () => db.doc(`${name}/evento${++secuencia}`),
     where: (key, op, value) => ({get: async () => ({docs: [...datos.keys()].filter(p => p.startsWith(name + '/') && datos.get(p)[key]?.includes(value)).map(snap)})}),
   }),
   runTransaction:async fn=>{
   if(antes) antes(); const pendientes=[];
   const tx={get:async ref=>snap(ref.path),create:(ref,v)=>{assert.ok(!datos.has(ref.path));pendientes.push([ref.path,v]);},set:(ref,v)=>pendientes.push([ref.path,v]),update:(ref,v)=>pendientes.push([ref.path,{...datos.get(ref.path),...v}])};
   const resultado=await fn(tx); pendientes.forEach(([k,v])=>datos.set(k,v)); return resultado;
 }};
 const auth={getUserByEmail:async email=>{if(!cuentas.has(email))throw Object.assign(new Error(),{code:'auth/user-not-found'});return cuentas.get(email);},createUser:async d=>{assert.ok(d.password.length>=32);const u={uid:d.uid,email:d.email};cuentas.set(d.email,u);return u;}};
 return {datos,cuentas,antes:fn=>antes=fn,ejecutar:(cambios={},actorUid='admin')=>gestionarEquipo({db,auth,actorUid,timestamp:()=>1,datos:{accion:'crearEquipo',clubId:'demo',nombre:'Persona Prueba',email:'persona@club.org',rol:'deportes',...cambios}})};
}
test('alta exclusiva, idempotencia y cambios de rol/estado sin modificar Auth',async()=>{
 const e=entorno();const r=await e.ejecutar();const uid=r.usuario.uid;
 assert.equal(e.datos.get('usuarios/'+uid).rol,'deportes');assert.equal(e.cuentas.size,1);
 assert.equal((await e.ejecutar()).yaExistia,true);
 await e.ejecutar({accion:'editarEquipo',uid,rol:'institucional',activo:false});
 assert.equal(e.datos.get('usuarios/'+uid).activo,false);
 assert.equal(e.datos.get('usuarios/'+uid).rol,'institucional');assert.equal(e.cuentas.size,1);
 const listado=await e.ejecutar({accion:'listarEquipo'});assert.equal(listado.usuarios.find(u=>u.uid==='admin').editable,false);
});
test('rechaza roles elevados, usuario ajeno, empleado y club en eliminación',async()=>{
 const e=entorno();await assert.rejects(e.ejecutar({rol:'superadmin'}));await assert.rejects(e.ejecutar({},'ajeno'));await assert.rejects(e.ejecutar({},'empleado'));
 e.datos.set('eliminaciones_club/demo',{});await assert.rejects(e.ejecutar());assert.equal(e.cuentas.size,0);
});
test('no adopta cuentas existentes ni cambia administradores o cuentas compartidas',async()=>{
 const e=entorno();e.cuentas.set('persona@club.org',{uid:'externo'});await assert.rejects(e.ejecutar());
 await assert.rejects(e.ejecutar({accion:'editarEquipo',uid:'admin',activo:false}));
 e.datos.set('usuarios/compartido',{rol:'deportes',origenAlta:'plataforma_club',clubPrincipal:'demo',clubIds:['demo','otro']});
 await assert.rejects(e.ejecutar({accion:'editarEquipo',uid:'compartido',activo:false}));
});
test('revalida acceso dentro de transacción; reintento recupera cuenta sin perfil',async()=>{
 const e=entorno();e.antes(()=>e.datos.get('usuarios/admin').activo=false);
 await assert.rejects(e.ejecutar());assert.equal(e.cuentas.size,1);
 assert.equal([...e.datos.keys()].filter(k=>k.startsWith('usuarios/clubequipo_')).length,0);
 e.antes(()=>{});e.datos.get('usuarios/admin').activo=true;await e.ejecutar();assert.equal(e.cuentas.size,1);
});
test('requiere permisos configurados y protege cuentas con claims',async()=>{
 const e=entorno();e.datos.delete('clubes/demo/configuracion/permisos_roles');await assert.rejects(e.ejecutar());
 e.datos.set('clubes/demo/configuracion/permisos_roles',{deportes:['Gestionar Plantel']});
 await e.ejecutar();e.cuentas.get('persona@club.org').customClaims={admin:true};await assert.rejects(e.ejecutar());
});
