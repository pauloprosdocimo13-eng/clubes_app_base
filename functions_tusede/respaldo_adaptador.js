"use strict";
const {getApp} = require('firebase-admin/app');
const {PROJECT, ROOT, LIMITS, exigir, sha, md5, validarManifiesto, revisarEnlaces} = require('./respaldo_formato');
function crearAdaptador({db, origen, destino, fetchImpl = fetch, request}) {
  async function rest(path, {method = 'GET', body} = {}) {
    if (request) return request(path, {method, body});
    const token = await getApp().options.credential.getAccessToken();
    const response = await fetchImpl(`https://firestore.googleapis.com/v1/${path}`, {
      method, headers: {Authorization: `Bearer ${token.access_token}`, 'Content-Type':'application/json'},
      ...(body ? {body: JSON.stringify(body)} : {}), signal: AbortSignal.timeout(25000),
    });
    exigir(response.ok, `Firestore no pudo completar el paso (${response.status}). Reintentá.`, 503);
    return response.json();
  }
  const escapePath = p => p.split('/').map(encodeURIComponent).join('/');
  async function comprobarBucket() {
    const [m] = await destino.getMetadata();
    exigir(m.iamConfiguration?.uniformBucketLevelAccess?.enabled === true && m.iamConfiguration?.publicAccessPrevention === 'enforced',
      'Prepará el bucket privado de respaldos según la guía de instalación.');
  }
  async function guardarUnico(path, bytes, metadata = {}) {
    const f = destino.file(path);
    try {
      const [existing] = await f.getMetadata();
      exigir(Number(existing.size) === bytes.length, 'El archivo existente no coincide. No se sobrescribió.');
      const [content] = await f.download();
      exigir(sha(content) === sha(bytes), 'El archivo existente no coincide. No se sobrescribió.');
      return {generation:existing.generation,hash:sha(bytes)};
    } catch (e) { if (Number(e.code) !== 404) throw e; }
    try { await f.save(bytes, {resumable:false, validation:'crc32c', preconditionOpts:{ifGenerationMatch:0}, metadata:{contentType:'application/octet-stream', metadata:{sha256:sha(bytes), ...metadata}}}); }
    catch (e) {
      if (Number(e.code) !== 412) throw e;
      const [existente] = await f.download();
      exigir(sha(existente) === sha(bytes), 'El archivo de respaldo existente no coincide. No se sobrescribió.');
    }
    const [m] = await f.getMetadata();
    return {generation:m.generation, hash:sha(bytes)};
  }
  async function capturar(clubId) {
    const until = Date.now() + 180000;
    const check = () => exigir(Date.now() < until, 'La lectura excedió el tiempo disponible. Este club requiere un respaldo asistido.');
    const snap = await db.doc(`clubes/${clubId}`).get();
    exigir(snap.exists, 'El club ya no existe.');
    const rt = snap.readTime;
    const readTime = new Date(rt.seconds * 1000).toISOString().replace('.000Z', `.${String(rt.nanoseconds).padStart(9,'0').slice(0,6)}Z`);
    const base = `${ROOT}/clubes/${clubId}`;
    const documents = []; let visited = 0;
    async function visit(name, doc) {
      check(); exigir(++visited <= LIMITS.documents, 'Máximo 500 documentos, incluyendo padres vacíos, por respaldo en esta versión.');
      if (doc.fields || doc.createTime) documents.push({name:doc.name, fields:doc.fields || {}});
      let pageToken;
      do {
        check();
        const collections = await rest(`${escapePath(name)}:listCollectionIds`, {method:'POST', body:{readTime,pageSize:100,...(pageToken ? {pageToken} : {})}});
        for (const collection of collections.collectionIds || []) {
          let next;
          do {
            check();
            const q = new URLSearchParams({readTime,showMissing:'true',pageSize:'100',...(next ? {pageToken:next} : {})});
            const list = await rest(`${escapePath(name)}/${encodeURIComponent(collection)}?${q}`);
            for (const child of list.documents || []) await visit(child.name, child);
            next = list.nextPageToken;
          } while (next);
        }
        pageToken = collections.nextPageToken;
      } while (pageToken);
    }
    const root = await rest(`${escapePath(base)}?${new URLSearchParams({readTime})}`);
    await visit(base, root);
    const [files, next] = await origen.getFiles({prefix:`clubes/${clubId}/`,autoPaginate:false,maxResults:LIMITS.files + 1});
    exigir(!next && files.length <= LIMITS.files, 'Máximo 100 archivos por respaldo en esta versión.');
    const entries = [];
    for (const f of files) {
      check(); const metadata = f.metadata?.generation ? f.metadata : (await f.getMetadata())[0];
      entries.push({name:f.name,generation:String(metadata.generation),size:Number(metadata.size),md5:metadata.md5Hash,contentType:metadata.contentType || 'application/octet-stream'});
    }
    const m = validarManifiesto({version:1,proyecto:PROJECT,clubId,readTime,documents,files:entries}, clubId);
    m.enlacesExternos = revisarEnlaces(m);
    exigir(Buffer.byteLength(JSON.stringify(m)) <= LIMITS.manifestBytes, 'Los documentos superan 10 MB. Se necesita respaldo asistido.');
    return m;
  }
  async function capturaExistente(job) {
    const file = destino.file(`respaldos/${job.id}/manifest.json`);
    let metadata;
    try { [metadata] = await file.getMetadata(); } catch (e) { if (Number(e.code) === 404) return null; throw e; }
    const descriptor = {generation:metadata.generation,hash:metadata.metadata?.sha256};
    exigir(typeof descriptor.hash === 'string', 'Respaldo incompleto o incompatible.');
    const manifest = await leerManifiesto({...job,manifestGeneration:descriptor.generation,manifestHash:descriptor.hash});
    return {...descriptor,manifest};
  }
  async function leerManifiesto(job) {
    const f = destino.file(`respaldos/${job.id}/manifest.json`, {generation:job.manifestGeneration});
    const [meta] = await f.getMetadata();
    exigir(Number(meta.size) <= LIMITS.manifestBytes, 'Manifiesto demasiado grande.');
    const [bytes] = await f.download();
    exigir(sha(bytes) === job.manifestHash, 'El respaldo no supera la verificación de integridad.');
    return validarManifiesto(JSON.parse(bytes.toString('utf8')), job.clubId);
  }
  async function copiarRespaldo(id, f, i) {
    const [bytes] = await origen.file(f.name,{generation:f.generation}).download();
    exigir(bytes.length === f.size && md5(bytes) === f.md5, 'El archivo original cambió o no supera la verificación. No se completó el respaldo.');
    await guardarUnico(`respaldos/${id}/archivos/${i}`,bytes);
  }
  async function copiarRestauracion(job, m, f, i) {
    const source = destino.file(`respaldos/${job.respaldoId}/archivos/${i}`);
    const [sourceMeta] = await source.getMetadata();
    exigir(Number(sourceMeta.size) === f.size, 'Una imagen del respaldo cambió de tamaño.');
    const [bytes] = await source.download();
    exigir(bytes.length === f.size && md5(bytes) === f.md5, 'Una imagen del respaldo no supera la verificación.');
    const path = `clubes/${job.destino}/${f.name.slice(`clubes/${m.clubId}/`.length)}`;
    const target = origen.file(path);
    try {
      const [existing] = await target.getMetadata();
      exigir(existing.metadata?.restauracion === job.id && existing.md5Hash === f.md5 && Number(existing.size) === f.size, 'Existe un archivo diferente en el destino. No se sobrescribió.');
      return;
    } catch (e) { if (Number(e.code) !== 404) throw e; }
    try {
      await target.save(bytes,{resumable:false,validation:'crc32c',preconditionOpts:{ifGenerationMatch:0},metadata:{contentType:f.contentType,
        metadata:{firebaseStorageDownloadTokens:sha(`${job.tokenSeed}\n${path}`),restauracion:job.id}}});
    } catch(e) {
      if (Number(e.code) !== 412) throw e;
      const [meta] = await target.getMetadata();
      exigir(meta.metadata?.restauracion === job.id && meta.md5Hash === f.md5, 'Existe un archivo diferente en el destino. No se sobrescribió.');
    }
  }
  async function escribirDocumentos(documents) {
    if (!documents.length) return;
    await rest(`projects/${PROJECT}/databases/(default)/documents:commit`, {method:'POST',body:{writes:documents.map(update => ({update}))}});
  }
  async function destinoVacio(id) {
    const collections = await db.doc(`clubes/${id}`).listCollections();
    const [files] = await origen.getFiles({prefix:`clubes/${id}/`,maxResults:1,autoPaginate:false});
    exigir(!collections.length && !files.length, 'El destino contiene datos o archivos. Elegí otro identificador.');
  }
  async function finalizar(job, root, uid, lease) {
    const [a,c,l,j] = await Promise.all([
      db.doc(`usuarios/${uid}`).get(),db.doc(`clubes/${job.destino}`).get(),
      db.doc(`restauraciones_club/${job.destino}`).get(),db.doc(`respaldos_club/${job.id}`).get(),
    ]);
    exigir(a.data()?.activo === true && a.data()?.rol === 'superadmin','Se requiere un superadmin activo.',403);
    exigir(c.data()?.estado === 'restaurando' && l.data()?.operacion === job.id && j.data()?.lease === lease,'La recuperación cambió. No se publicó.');
    const time = t => new Date(t.seconds*1000).toISOString().replace('.000Z',`.${String(t.nanoseconds).padStart(9,'0')}Z`);
    await rest(`projects/${PROJECT}/databases/(default)/documents:commit`,{method:'POST',body:{writes:[
      {verify:`${ROOT}/usuarios/${uid}`,currentDocument:{updateTime:time(a.updateTime)}},
      {update:root,currentDocument:{updateTime:time(c.updateTime)}},
      {delete:`${ROOT}/restauraciones_club/${job.destino}`,currentDocument:{updateTime:time(l.updateTime)}},
      {update:{name:`${ROOT}/respaldos_club/${job.id}`,fields:{estado:{stringValue:'completado'},leaseHasta:{integerValue:'0'},procesados:{integerValue:String(job.documentos)}}},updateMask:{fieldPaths:['estado','leaseHasta','procesados']},currentDocument:{updateTime:time(j.updateTime)}},
    ]}});
  }
  return {comprobarBucket,capturar,guardarUnico,leerManifiesto,capturaExistente,copiarRespaldo,copiarRestauracion,escribirDocumentos,destinoVacio,finalizar};
}
module.exports = {crearAdaptador};
