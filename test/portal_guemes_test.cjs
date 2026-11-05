const {test}=require('node:test');
const assert=require('node:assert/strict'), fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
function entorno(archivo,proyecto='club-guemes-2') {
 const datos=new Map();
 class Timestamp { constructor(ms){this.ms=ms;} toMillis(){return this.ms;} toDate(){return new Date(this.ms);} static fromMillis(ms){return new Timestamp(ms);} }
 const snap=(ruta)=>({id:ruta.split('/').at(-1),exists:datos.has(ruta),data:()=>datos.get(ruta)});
 function ref(ruta,filtros=[],limite=Infinity,documento=false){return {
  path:ruta,collection:n=>ref(ruta+'/'+n),doc:n=>ref(ruta+'/'+n,[],Infinity,true),
  where:(k,op,v)=>ref(ruta,[...filtros,[k,v]],limite),limit:n=>ref(ruta,filtros,n),
  async get(){if(documento)return snap(ruta);return {docs:[...datos.keys()].filter(k=>k.startsWith(ruta+'/') && !k.slice(ruta.length+1).includes('/') && filtros.every(([campo,valor])=>datos.get(k)[campo]===valor)).slice(0,limite).map(snap)};},
 } }
 const db={collection:n=>ref(n),async runTransaction(fn){const cambios=[];await fn({get:r=>r.get(),set:(r,d,opts)=>cambios.push(()=>datos.set(r.path,opts?.merge?{...datos.get(r.path),...d}:d)),update:(r,d)=>cambios.push(()=>datos.set(r.path,{...datos.get(r.path),...d})),create:(r,d)=>cambios.push(()=>datos.set(r.path,d))});cambios.forEach(f=>f());}};
 const builder={region(){return this;},runWith(){return this;},https:{onRequest:f=>f}};
 const context=vm.createContext({exports:{},process:{env:{GCLOUD_PROJECT:proyecto}},console,setTimeout:f=>{f();},require(n){
  if(n==='firebase-functions/v1')return builder;
  if(n==='firebase-admin/app')return {getApps:()=>[{}]};
  if(n==='firebase-admin/firestore')return {getFirestore:()=>db,Timestamp,FieldValue:{serverTimestamp:()=>new Timestamp(Date.now())}};
  if(n==='crypto'||n==='node:crypto')return require('node:crypto');
  throw Error(n);
 }});
 vm.runInContext(fs.readFileSync(path.join(__dirname,'../functions',archivo),'utf8'),context);
 async function llamar(nombre,body,method='POST'){
  let status=200,payload;
  const res={set(){},status(s){status=s;return this;},json(d){payload=JSON.parse(JSON.stringify(d));return this;},send(d){payload=d;return this;}};
  await context.exports[nombre]({method,body,headers:{},ip:'127.0.0.10'},res);
  return {status,payload};
 }
 return {datos,llamar,context,Timestamp};
}
test('carnet Güemes devuelve datos mínimos y omite notas, domicilio, teléfono y descuentos privados',async()=>{
 const e=entorno('carnet_publico_guemes.js');
 e.datos.set('socios/uno',{dni:'11222333',nombre:'Ana',familia_id:'familia',email:'privado',telefono:'privado',direccion:'privado',notas_internas:'privado',reglas_convivencia_firmadas:true,descuentos_por_actividad:{Futbol:50}});
 e.datos.set('socios/dos',{dni:'22333444',nombre:'Familiar',familia_id:'familia',email:'privado'});
 e.datos.set('configuracion/precios',{precios_cuotas:{Futbol:100}});
 e.datos.set('configuracion/pagos',{alias_cbu:'club',clave:'privado',token:'privado'});
 const r=await e.llamar('buscarCarnetGuemes',{clubId:'guemes',dni:'11222333'});
 assert.equal(r.status,200);assert.equal(r.payload.socio.nombre,'Ana');assert.equal(r.payload.precios.Futbol,100);
 assert.ok(!JSON.stringify(r.payload).includes('privado'));
 assert.equal(r.payload.familia.find(s=>s.nombre==='Familiar').dni,'****3444');
 assert.equal(e.datos.has('clubes/guemes'),false);
});
test('carnet rechaza otro proyecto, club y limita enumeración por DNI',async()=>{
 const e=entorno('carnet_publico_guemes.js');
 assert.equal((await e.llamar('buscarCarnetGuemes',{clubId:'otro',dni:'11222333'})).status,404);
 const otro=entorno('carnet_publico_guemes.js','tu-sede-app');
 assert.equal((await otro.llamar('buscarCarnetGuemes',{clubId:'guemes',dni:'11222333'})).status,404);
 for(let i=0;i<6;i++) assert.equal((await e.llamar('buscarCarnetGuemes',{clubId:'guemes',dni:'11222333'})).status,404);
 assert.equal((await e.llamar('buscarCarnetGuemes',{clubId:'guemes',dni:'11222333'})).status,429);
});
test('reservas expone solo ocupación, rechaza rutas y reserva sin aceptar datos administrativos del cliente',async()=>{
 const e=entorno('reservas_publicas_guemes.js');
 e.datos.set('espacios/cancha',{titulo:'Cancha',activo:true});
 const fecha=new Date().toISOString().slice(0,10);
 e.datos.set('reservas/privada',{espacio_id:'cancha',fecha,hora:'10:00',estado:'confirmada',nombre:'privado',telefono:'privado'});
 const r=await e.llamar('reservasGuemes',{clubId:'guemes',accion:'disponibilidad',espacioId:'cancha',fecha});
 assert.equal(r.status,200);assert.equal(r.payload.horarios['10:00'],'confirmada');assert.ok(!JSON.stringify(r.payload).includes('privado'));
 assert.equal((await e.llamar('reservasGuemes',{clubId:'guemes',accion:'disponibilidad',espacioId:'otro/ruta',fecha})).status,400);
 const body={clubId:'guemes',accion:'reservar',espacioId:'cancha',fecha,hora:'11:00',estado:'confirmada',pagado:true};
 assert.equal((await e.llamar('reservasGuemes',body)).status,200);
 const nueva=[...e.datos.entries()].find(([k])=>k.startsWith('reservas/pub_'))[1];
 assert.equal(nueva.estado,'pendiente');assert.equal(nueva.pagado,undefined);
 assert.equal((await e.llamar('reservasGuemes',body)).status,409);
});
test('voto público suma uno, no reemplaza candidatos y rechaza duplicados y votaciones cerradas',async()=>{
 const e=entorno('voto_publico_guemes.js');
 e.datos.set('votaciones/partido',{estado:'ABIERTA',total_votos:0,candidatos:[{id_jugador:'uno',nombre:'Jugador',votos:0}]});
 const body={votacionId:'partido',candidatoId:'uno',dispositivo:'abcdefghijklmnop',total_votos:9999};
 assert.equal((await e.llamar('votarFiguraGuemes',body)).status,200);
 assert.equal(e.datos.get('votaciones/partido').total_votos,1);
 assert.equal(e.datos.get('votaciones/partido').candidatos[0].nombre,'Jugador');
 assert.equal((await e.llamar('votarFiguraGuemes',body)).status,409);
 e.datos.get('votaciones/partido').estado='CERRADA';
 assert.equal((await e.llamar('votarFiguraGuemes',{...body,dispositivo:'otroabcdefghijklmnop'})).status,409);
});
