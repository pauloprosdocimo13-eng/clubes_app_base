const {test}=require('node:test');
const assert=require('node:assert/strict');
const {crearAdaptador}=require('../functions_tusede/respaldo_adaptador');
const F=require('../functions_tusede/respaldo_formato');
function bucket(){
 const data=new Map();let seq=0;
 const b={data,getMetadata:async()=>[{iamConfiguration:{uniformBucketLevelAccess:{enabled:true},publicAccessPrevention:'enforced'}}],
 getFiles:async()=>[[...data.keys()].map(name=>({name,metadata:data.get(name).metadata})),null],
 file:(name,options={})=>({
 getMetadata:async()=>{if(!data.has(name))throw Object.assign(Error(),{code:404});return [data.get(name).metadata];},
 download:async()=>{const v=data.get(name);if(!v || (options.generation && options.generation!==v.metadata.generation))throw Object.assign(Error(),{code:404});return [v.bytes];},
 save:async(bytes,opts)=>{if(data.has(name)&&opts.preconditionOpts?.ifGenerationMatch===0)throw Object.assign(Error(),{code:412});data.set(name,{bytes:Buffer.from(bytes),metadata:{...opts.metadata,generation:String(++seq),md5Hash:F.md5(bytes),size:String(bytes.length)}});},
 })};return b;
}
test('captura paginada a un readTime común incluye descendientes de padres ausentes y escapa espacios',async()=>{
 const calls=[];const base=`${F.ROOT}/clubes/demo`;const rt='2026-10-27T12:00:00.123456Z';
 const db={doc:()=>({get:async()=>({exists:true,readTime:{seconds:1793102400,nanoseconds:123456000}})})};
 const request=async(path,opts)=>{
  calls.push({path,...opts});const u=new URL('https://x/'+path);const p=decodeURIComponent(u.pathname.slice(1));
  if(p===base && opts.method==='GET')return {name:base,fields:{nombre:{stringValue:'Demo'}}};
  if(p===base+':listCollectionIds')return opts.body.pageToken ? {collectionIds:['vacia']} : {collectionIds:['padres'],nextPageToken:'p2'};
  if(p===base+'/padres')return {documents:[{name:base+'/padres/Con espacio'}]};
  if(p===base+'/vacia')return {};
  if(p===base+'/padres/Con espacio:listCollectionIds')return {collectionIds:['hijos']};
  if(p===base+'/padres/Con espacio/hijos')return {documents:[{name:base+'/padres/Con espacio/hijos/uno',fields:{fecha:{timestampValue:rt}}}]};
  if(p.endsWith(':listCollectionIds'))return {};
  throw Error(p);
 };
 const a=crearAdaptador({db,origen:bucket(),destino:bucket(),request});const m=await a.capturar('demo');
 assert.equal(m.documents.length,2);assert.ok(m.documents[1].name.endsWith('/hijos/uno'));
 assert.ok(calls.some(c=>c.path.includes('Con%20espacio')));
 const times=calls.map(c=>c.body?.readTime || new URL('https://x/'+c.path).searchParams.get('readTime'));
 assert.equal(new Set(times).size,1);assert.equal(times[0],rt);
});
test('copias privadas no heredan tokens; generaciones y checksum protegen imágenes y reintentos',async()=>{
 const origen=bucket(),destino=bucket();const bytes=Buffer.from('foto');
 await origen.file('clubes/demo/foto.png').save(bytes,{metadata:{contentType:'image/png',metadata:{firebaseStorageDownloadTokens:'viejo'}}});
 const f={name:'clubes/demo/foto.png',generation:'1',size:bytes.length,md5:F.md5(bytes),contentType:'image/png'};
 const a=crearAdaptador({db:{},origen,destino});await a.copiarRespaldo('op',f,0);await a.copiarRespaldo('op',f,0);
 assert.equal(destino.data.get('respaldos/op/archivos/0').metadata.metadata.firebaseStorageDownloadTokens,undefined);
 const job={id:'recuperacion',tokenSeed:'secreto',respaldoId:'op',destino:'nuevo'};
 await a.copiarRestauracion(job,{clubId:'demo'},f,0);await a.copiarRestauracion(job,{clubId:'demo'},f,0);
 const token=origen.data.get('clubes/nuevo/foto.png').metadata.metadata.firebaseStorageDownloadTokens;
 assert.notEqual(token,'viejo');assert.equal(token,F.sha('secreto\nclubes/nuevo/foto.png'));
 destino.data.get('respaldos/op/archivos/0').bytes=Buffer.from('roto');await assert.rejects(a.copiarRestauracion({...job,destino:'otro'},{clubId:'demo'},f,0));
 await assert.rejects(a.copiarRespaldo('op',{...f,generation:'99'},0));
});
test('manifiesto alterado y bucket público son rechazados',async()=>{
 const b=bucket();const a=crearAdaptador({db:{},origen:bucket(),destino:b});
 const descriptor=await a.guardarUnico('respaldos/op/manifest.json',Buffer.from('{}'));
 b.data.get('respaldos/op/manifest.json').bytes=Buffer.from('{"alterado":true}');
 await assert.rejects(a.leerManifiesto({id:'op',clubId:'demo',manifestGeneration:descriptor.generation,manifestHash:descriptor.hash}));
 b.getMetadata=async()=>[{iamConfiguration:{uniformBucketLevelAccess:{enabled:true},publicAccessPrevention:'inherited'}}];await assert.rejects(a.comprobarBucket());
});
