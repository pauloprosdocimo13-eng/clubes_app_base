const {test}=require('node:test');
const assert=require('node:assert/strict');
const {crearManejador,sorteoPublico,validarPronostico}=require('../functions/entretenimiento_guemes_core');
const {crearAutorizador,permitido}=require('../functions/autorizar_imagen_guemes_core');
function entorno(proyecto='club-guemes-2') {
 const datos=new Map();
 const snap=p=>({id:p.split('/').at(-1),exists:datos.has(p),data:()=>datos.get(p)});
 function ref(p,filtros=[],n=100,documento=false){return {path:p,doc:id=>ref(p+'/'+id,[],100,true),where:(k,op,v)=>ref(p,[...filtros,[k,v]],n),limit:v=>ref(p,filtros,v),async get(){return documento?snap(p):{docs:[...datos.keys()].filter(k=>k.startsWith(p+'/')&&filtros.every(([f,v])=>datos.get(k)[f]===v)).slice(0,n).map(snap)};}};}
 const db={collection:p=>ref(p),async runTransaction(fn){const cambios=[];await fn({get:r=>r.get(),set:(r,d)=>cambios.push(()=>datos.set(r.path,d)),create:(r,d)=>cambios.push(()=>{assert.ok(!datos.has(r.path));datos.set(r.path,d);})});cambios.forEach(f=>f());}};
 const handler=crearManejador({db,FieldValue:{serverTimestamp:()=>123},Timestamp:{fromMillis:m=>m},proyecto:()=>proyecto});
 return {datos,db,llamar:body=>invocar(handler,body)};
}
async function invocar(handler,body,authorization='Bearer valido') {
 let status=200,payload;
 const res={set(){},status(n){status=n;return this;},json(d){payload=d;return this;},send(d){payload=d;return this;}};
 await handler({method:'POST',body,ip:'127.0.0.1',get:()=>authorization},res);
 return {status,payload};
}
const fecha={estado:'ABIERTA',partidos:[{id:'uno'}]};
const body={accion:'enviar_prode',fechaId:'fecha',token:'a'.repeat(64),nombre:'Persona',predicciones:{uno:{gl:2,gv:1}}};
test('rifas solo entrega campos públicos y números válidos',async()=>{
 const e=entorno();e.datos.set('sorteos/uno',{activo:true,titulo:'Rifa',compradores:{0:{dni:'privado'}},cantidad_numeros:100,numeros_vendidos:[0,0,99,100,-1],premio:'Pelota'});
 e.datos.set('sorteos/oculto',{activo:false,titulo:'Oculto'});
 const r=await e.llamar({accion:'rifas'});assert.equal(r.status,200);assert.equal(r.payload.rifas.length,1);assert.deepEqual(r.payload.rifas[0].numeros_vendidos,[0,99]);assert.ok(!JSON.stringify(r.payload).includes('privado'));
 assert.equal((await e.llamar({accion:'rifas',sorteoId:'oculto'})).payload.rifas.length,0);
});
test('Prode valida partidos, enteros, cierre y ausencia de campos extra',()=>{
 assert.deepEqual(validarPronostico(fecha,body.predicciones),body.predicciones);
 for(const pred of [{},{uno:{gl:-1,gv:0}},{uno:{gl:1.5,gv:0}},{uno:{gl:1,gv:1,puntos:999}},{otro:{gl:1,gv:1}}]) assert.throws(()=>validarPronostico(fecha,pred));
 assert.throws(()=>validarPronostico({...fecha,bloqueado:true},body.predicciones));
 assert.throws(()=>validarPronostico({...fecha,estado:'CERRADA'},body.predicciones));
});
test('Prode guarda una vez, oculta token y permite consultar solo el voto propio',async()=>{
 const e=entorno();e.datos.set('prode_fechas/fecha',fecha);
 assert.equal((await e.llamar(body)).status,200);
 assert.equal((await e.llamar(body)).status,409);
 const voto=[...e.datos.entries()].find(([k])=>k.startsWith('prode_votos/'))[1];assert.equal(voto.puntos,0);assert.notEqual(voto.user_id,body.token);
 const r=await e.llamar({accion:'mi_prode',fechaId:'fecha',token:body.token});assert.deepEqual(r.payload.voto,{predicciones:body.predicciones,puntos:0});
 assert.equal((await e.llamar({accion:'mi_prode',fechaId:'fecha',token:'b'.repeat(64)})).payload.voto,null);
 assert.equal((await e.llamar({...body,puntos:999})).status,400);
});
test('portal rechaza otro proyecto, rutas y limita solicitudes',async()=>{
 assert.equal((await entorno('tu-sede-app').llamar(body)).status,403);
 const e=entorno();assert.equal((await e.llamar({...body,fechaId:'otra/ruta'})).status,400);
 for(let i=0;i<299;i++) await e.llamar({accion:'rifas'});
 assert.equal((await e.llamar({accion:'rifas'})).status,429);
});
test('imágenes requieren permiso específico; matriz e inactividad se respetan',()=>{
 assert.equal(permitido({rol:'admin'},{},'socios'),true);
 assert.equal(permitido({rol:'admin',activo:false},{},'socios'),false);
 assert.equal(permitido({rol:'admin'},{},'../../x'),false);
 assert.equal(permitido({rol:'tesoreria'},{},'socios'),true);
 assert.equal(permitido({rol:'tesoreria'},{tesoreria:[]},'socios'),false);
 assert.equal(permitido({rol:'deportes'},{},'socios'),false);
 assert.equal(permitido({rol:'deportes'},{deportes:['Gestionar Plantel']},'jugadores'),true);
});
test('autorizador valida revocación, rechaza tokens falsos y perfil inactivo',async()=>{
 const e=entorno();e.datos.set('permisos_admin/admin@test.com',{rol:'admin'});
 let revoked=false;const auth={async verifyIdToken(t,r){revoked=r;if(t!=='valido')throw Error();return {email:'admin@test.com'};}};
 const h=crearAutorizador({auth,db:e.db,proyecto:()=> 'club-guemes-2'});
 assert.equal((await invocar(h,{carpeta:'socios'})).status,200);assert.equal(revoked,true);
 assert.equal((await invocar(h,{carpeta:'socios'},'Bearer falso')).status,401);
 assert.equal((await invocar(h,{carpeta:'socios'},'')).status,401);
 e.datos.set('permisos_admin/admin@test.com',{rol:'admin',activo:false});assert.equal((await invocar(h,{carpeta:'socios'})).status,403);
});
