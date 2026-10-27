const {test}=require('node:test');
const assert=require('node:assert/strict');
const F=require('../functions_tusede/respaldo_formato');
const {crearServicioRespaldos}=require('../functions_tusede/respaldos_club');
const id='a'.repeat(32), base=`${F.ROOT}/clubes/demo`;
function manifest(){return {version:1,proyecto:F.PROJECT,clubId:'demo',readTime:'2026-10-27T12:00:00.000000Z',files:[],documents:[
 {name:base,fields:{nombre:{stringValue:'Demo'},activo:{booleanValue:true},estado:{stringValue:'activo'},origenDatos:{stringValue:'central'}}},
 {name:base+'/socios/uno',fields:{nombre:{stringValue:'Ana'},numero:{integerValue:'9223372036854775807'},fecha:{timestampValue:'2026-10-01T12:00:00.123456Z'}}},
 {name:base+'/configuracion/permisos_roles',fields:{admin:{booleanValue:true}}},
 {name:base+'/configuracion/seguridad',fields:{clave:{stringValue:'secreto'}}},
]};}
function entorno(){
 const data=new Map([['usuarios/super',{rol:'superadmin',activo:true}],['usuarios/admin',{rol:'admin',activo:true,clubIds:['demo']}],['clubes/demo',{nombre:'Demo',estado:'activo',activo:true,origenDatos:'central'}]]);
 const manifests=new Map(); const copied=[]; let fallo=false; let antes;
 const snapshot=p=>({id:p.split('/').at(-1),exists:data.has(p),data:()=>structuredClone(data.get(p))});
 const db={doc:p=>({path:p,get:async()=>snapshot(p)}),runTransaction:async fn=>{const pending=[];const tx={get:async r=>snapshot(r.path),create:(r,v)=>{assert.ok(!data.has(r.path));pending.push([r.path,v]);},update:(r,v)=>pending.push([r.path,{...data.get(r.path),...v}])};const result=await fn(tx);pending.forEach(([k,v])=>data.set(k,structuredClone(v)));return result;}};
 const archivos={
 comprobarBucket:async()=>{},capturaExistente:async job=>manifests.has(job.id)?{manifest:manifests.get(job.id),generation:'1',hash:'hash'}:null,
 capturar:async()=>{if(antes)antes();return manifest();},guardarUnico:async(p,bytes)=>{manifests.set(p.split('/')[1],JSON.parse(bytes));return {generation:'1',hash:'hash'};},
 leerManifiesto:async job=>structuredClone(manifests.get(job.id)),
 copiarRespaldo:async()=>{},copiarRestauracion:async()=>{},destinoVacio:async()=>{},
 escribirDocumentos:async docs=>{if(fallo){fallo=false;throw Error('red');}copied.push(...docs);docs.forEach(d=>data.set(d.name.slice(F.ROOT.length+1),d.fields));},
 finalizar:async(job,root,uid,lease)=>{assert.equal(data.get('respaldos_club/'+job.id).lease,lease);F.validarActor(data.get('usuarios/'+uid));data.set('clubes/'+job.destino,root.fields);data.delete('restauraciones_club/'+job.destino);data.set('respaldos_club/'+job.id,{...data.get('respaldos_club/'+job.id),estado:'completado'});},
 };
 const servicio=crearServicioRespaldos({db,archivos,now:()=>1000000});
 return {servicio,data,manifests,copied,archivos,fallar:()=>fallo=true,antes:fn=>antes=fn};
}
async function respaldar(e){await e.servicio.crear('super','demo',id);let j;do{j=await e.servicio.continuar('super',id);}while(j.estado!=='completado');return j;}
test('respalda y recupera aislado en borrador sin usuarios, matriz ni secretos',async()=>{
 const e=entorno();const original=structuredClone(e.data.get('clubes/demo'));
 await respaldar(e);e.data.delete('clubes/demo'); // El respaldo sobrevive a la eliminación.
 const r=await e.servicio.restaurar('super',id,'recuperado','recuperado');
 assert.equal(e.data.get('clubes/recuperado').estado,'restaurando');
 await e.servicio.continuar('super',r.id);await e.servicio.continuar('super',r.id);
 const root=e.data.get('clubes/recuperado');assert.equal(root.estado.stringValue,'borrador');assert.equal(root.activo.booleanValue,false);
 assert.equal(e.copied.length,1);assert.equal(e.copied[0].fields.numero.integerValue,'9223372036854775807');
 assert.ok(!e.data.has('clubes/recuperado/configuracion/seguridad'));assert.ok(!e.data.has('clubes/recuperado/configuracion/permisos_roles'));
 assert.equal([...e.data.keys()].filter(k=>k.startsWith('usuarios/')).length,2);assert.equal(original.activo,true);
 assert.equal((await e.servicio.continuar('super',r.id)).estado,'completado');
});
test('rechaza actores, clubes Legacy, confirmación errónea y sobrescritura',async()=>{
 const e=entorno();await assert.rejects(e.servicio.crear('admin','demo',id));await assert.rejects(e.servicio.crear('super','guemes',id));
 e.data.get('clubes/demo').origenDatos='legacy';await assert.rejects(e.servicio.crear('super','demo',id));e.data.get('clubes/demo').origenDatos='central';
 await respaldar(e);await assert.rejects(e.servicio.restaurar('super',id,'nuevo','otro'));await assert.rejects(e.servicio.restaurar('super',id,'demo','demo'));
 assert.equal(e.data.get('clubes/demo').estado,'activo');
});
test('retoma después de error sin publicar parcialmente y bloquea operaciones simultáneas',async()=>{
 const e=entorno();await respaldar(e);const r=await e.servicio.restaurar('super',id,'nuevo','nuevo');
 assert.equal((await e.servicio.restaurar('super',id,'nuevo','nuevo')).id,r.id);
 await e.servicio.continuar('super',r.id);e.fallar();await assert.rejects(e.servicio.continuar('super',r.id));
 assert.ok(e.data.has('restauraciones_club/nuevo'));assert.equal(e.data.get('clubes/nuevo').activo,false);
 e.data.get('respaldos_club/'+r.id).leaseHasta=99999999;await assert.rejects(e.servicio.continuar('super',r.id));
 e.data.get('respaldos_club/'+r.id).leaseHasta=0;await e.servicio.continuar('super',r.id);assert.ok(!e.data.has('restauraciones_club/nuevo'));
});
test('revocación del superadmin impide completar la copia',async()=>{
 const e=entorno();await e.servicio.crear('super','demo',id);e.antes(()=>e.data.get('usuarios/super').activo=false);
 await assert.rejects(e.servicio.continuar('super',id));assert.notEqual(e.data.get('respaldos_club/'+id).estado,'completado');
 e.data.get('usuarios/super').activo=true;await e.servicio.continuar('super',id);assert.equal(e.data.get('respaldos_club/'+id).estado,'imagenes');
});
test('manifiesto rechaza alcance ajeno, duplicados y límites',()=>{
 const m=manifest();F.validarManifiesto(m,'demo');m.documents.push({name:`${F.ROOT}/usuarios/admin`,fields:{}});assert.throws(()=>F.validarManifiesto(m,'demo'));
 const n=manifest();n.documents.push(n.documents[0]);assert.throws(()=>F.validarManifiesto(n,'demo'));
 assert.throws(()=>F.validarManifiesto({...manifest(),proyecto:'club-guemes-2'},'demo'));
 assert.throws(()=>F.validarManifiesto({...manifest(),files:[{name:'clubes/demo/a',size:F.LIMITS.fileBytes+1,generation:'1',md5:'x'}]},'demo'));
});
test('remapea imágenes, referencias y clubId, conserva tipos y enlaces externos',()=>{
 const m=manifest();m.files=[{name:'clubes/demo/foto con espacio.png',generation:'10',size:2,md5:'x'}];
 const url=`https://firebasestorage.googleapis.com/v0/b/${F.SOURCE_BUCKET}/o/${encodeURIComponent(m.files[0].name)}?alt=media&token=viejo`;
 const d={name:base+'/socios/a',fields:{foto:{stringValue:url},ref:{referenceValue:base+'/socios/b'},clubId:{stringValue:'demo'},n:{integerValue:'9223372036854775807'},lista:{arrayValue:{values:[{mapValue:{fields:{foto:{stringValue:url}}}}]}},externo:{stringValue:'https://example.com/logo.png'}}};
 const t=F.transformarDocumento(d,m,'nuevo',id);
 assert.ok(t.fields.foto.stringValue.includes('clubes%2Fnuevo%2F'));assert.ok(!t.fields.foto.stringValue.includes('token=viejo'));
 assert.equal(t.fields.ref.referenceValue,`${F.ROOT}/clubes/nuevo/socios/b`);assert.equal(t.fields.clubId.stringValue,'nuevo');assert.equal(t.fields.n.integerValue,d.fields.n.integerValue);assert.equal(t.fields.externo.stringValue,d.fields.externo.stringValue);
 m.documents.push(d);assert.equal(F.revisarEnlaces(m),1);m.files=[];assert.throws(()=>F.revisarEnlaces(m));
});
test('fallo al copiar imágenes no marca respaldo completo',async()=>{
 const e=entorno();e.archivos.capturar=async()=>({...manifest(),files:[{name:'clubes/demo/a',generation:'1',size:1,md5:'x'}]});
 e.archivos.copiarRespaldo=async()=>{throw Error('checksum');};
 await e.servicio.crear('super','demo',id);await e.servicio.continuar('super',id);await assert.rejects(e.servicio.continuar('super',id));
 assert.equal(e.data.get('respaldos_club/'+id).estado,'imagenes');await assert.rejects(e.servicio.restaurar('super',id,'nuevo','nuevo'));
});
