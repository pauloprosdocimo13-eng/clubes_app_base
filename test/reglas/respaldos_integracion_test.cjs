const {test}=require('node:test');
const assert=require('node:assert/strict');
const {Firestore,Timestamp}=require('../../functions_tusede/node_modules/@google-cloud/firestore');
const {crearAdaptador}=require('../../functions_tusede/respaldo_adaptador');
const {crearServicioRespaldos}=require('../../functions_tusede/respaldos_club');
const {sha,md5}=require('../../functions_tusede/respaldo_formato');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185') throw Error('Solo emulador local.');
function bucket(){const data=new Map();let n=0;return {
 getMetadata:async()=>[{iamConfiguration:{uniformBucketLevelAccess:{enabled:true},publicAccessPrevention:'enforced'}}],
 getFiles:async()=>[[],null],
 file:name=>({getMetadata:async()=>{if(!data.has(name))throw Object.assign(Error(),{code:404});return [data.get(name).meta];},download:async()=>[data.get(name).bytes],save:async(bytes,opts)=>{if(data.has(name))throw Object.assign(Error(),{code:412});data.set(name,{bytes,meta:{...opts.metadata,generation:String(++n),size:bytes.length,md5Hash:md5(bytes)}});}}),
};}
test('recuperación real en Firestore emulado conserva tipos y finaliza atómicamente en borrador',async()=>{
 const db=new Firestore({projectId:'demo-respaldo',host:'127.0.0.1:8185',ssl:false});
 try {
  for(const name of ['clubes','usuarios','respaldos_club','restauraciones_club'])await db.recursiveDelete(db.collection(name));
  await db.doc('usuarios/super').set({rol:'superadmin',activo:true});
  await db.doc('clubes/demo').set({nombre:'Demo',origenDatos:'central',estado:'activo',activo:true});
  await db.doc('clubes/demo/padres/Con espacio/hijos/uno').set({fecha:new Timestamp(1700000000,123456000),bytes:Buffer.from('bytes'),ubicacion:new (require('../../functions_tusede/node_modules/@google-cloud/firestore').GeoPoint)(-34,-58)});
  const request=async(path,{method,body})=>{
    // El emulador REST no implementa lecturas históricas readTime. La prueba de
    // adaptador verifica ese parámetro; aquí probamos tipos y commit atómico.
    const u=new URL('http://127.0.0.1:8185/v1/'+path.replace('projects/tu-sede-app/','projects/demo-respaldo/'));
    u.searchParams.delete('readTime');
    const localPath=u.pathname.slice(4)+u.search;
    if(body) {body=structuredClone(body);delete body.readTime;}
    const r=await fetch('http://127.0.0.1:8185/v1/'+localPath,{method,headers:{Authorization:'Bearer owner','Content-Type':'application/json'},...(body?{body:JSON.stringify(body).replaceAll('projects/tu-sede-app/','projects/demo-respaldo/')}: {})});
    const text=await r.text();assert.ok(r.ok,text);return JSON.parse(text.replaceAll('projects/demo-respaldo/','projects/tu-sede-app/'));
  };
  const adapter=crearAdaptador({db,origen:bucket(),destino:bucket(),request});const service=crearServicioRespaldos({db,archivos:adapter});
  const id='c'.repeat(32);await service.crear('super','demo',id);let j;
  do{j=await service.continuar('super',id);}while(j.estado!=='completado');
  assert.equal(j.documentos,2);
  const restore=await service.restaurar('super',id,'nuevo','nuevo');
  do{j=await service.continuar('super',restore.id);}while(j.estado!=='completado');
  const root=(await db.doc('clubes/nuevo').get()).data();assert.equal(root.estado,'borrador');assert.equal(root.activo,false);
  assert.equal((await db.doc('clubes/demo').get()).data().activo,true);
  assert.equal((await db.doc('restauraciones_club/nuevo').get()).exists,false);
  const child=(await db.doc('clubes/nuevo/padres/Con espacio/hijos/uno').get()).data();assert.equal(child.fecha.nanoseconds,123456000);assert.equal(child.bytes.toString(),'bytes');assert.equal(child.ubicacion.latitude,-34);
  assert.equal((await service.continuar('super',restore.id)).estado,'completado');
 } finally {await db.terminate();}
});
