"use strict";
const {randomBytes} = require('node:crypto');
const {ROOT, exigir, validarId, validarOperacion, validarActor, validarClub, transformarDocumento, documentosRestaurables} = require('./respaldo_formato');
const nuevoId = () => randomBytes(16).toString('hex');
function crearServicioRespaldos({db, archivos, now = Date.now}) {
  const ref = id => db.doc(`respaldos_club/${id}`);
  const actor = async uid => validarActor((await db.doc(`usuarios/${uid}`).get()).data());
  const publico = j => Object.fromEntries(['id','tipo','clubId','nombre','destino','estado','creadoMs','documentos','archivos','bytes','procesados','enlacesExternos','readTime','respaldoId'].filter(k => j[k] !== undefined).map(k => [k,j[k]]));
  async function listar(uid, antes) {
    await actor(uid);
    let q = db.collection('respaldos_club').orderBy('creadoMs','desc').orderBy('__name__','desc');
    if (antes !== undefined) { exigir(Number.isSafeInteger(antes?.ms) && antes.ms > 0,'Cursor inválido.',400); validarOperacion(antes.id); q = q.startAfter(antes.ms,antes.id); }
    const s = await q.limit(50).get();
    return {operaciones:s.docs.map(d => publico({...d.data(),id:d.id})),siguiente:s.docs.length === 50 ? {ms:s.docs.at(-1).data().creadoMs,id:s.docs.at(-1).id} : null};
  }
  async function crear(uid, clubId, id) {
    validarId(clubId); validarOperacion(id); await actor(uid); await archivos.comprobarBucket();
    return db.runTransaction(async tx => {
      const [a,c,e,j] = await Promise.all([tx.get(db.doc(`usuarios/${uid}`)),tx.get(db.doc(`clubes/${clubId}`)),tx.get(db.doc(`eliminaciones_club/${clubId}`)),tx.get(ref(id))]);
      validarActor(a.data());
      if (j.exists) { exigir(j.data().clubId === clubId && j.data().tipo === 'respaldo','Operación incompatible.'); return publico({...j.data(),id}); }
      validarClub(c.data()); exigir(!e.exists,'El club se está eliminando.');
      const job = {id,tipo:'respaldo',clubId,nombre:c.data().nombre || clubId,estado:'preparando',creadoMs:now(),creadoPor:uid,procesados:0,leaseHasta:0};
      tx.create(ref(id),job); return publico(job);
    });
  }
  async function restaurar(uid, respaldoId, destino, confirmacion) {
    validarOperacion(respaldoId); validarId(destino); exigir(confirmacion === destino,'Escribí el nuevo identificador para confirmar.',400);
    await actor(uid); await archivos.comprobarBucket();
    const anterior = await db.doc(`restauraciones_club/${destino}`).get();
    if (anterior.exists) {
      const j = await ref(anterior.data().operacion).get();
      exigir(j.exists && j.data().respaldoId === respaldoId,'Hay otra recuperación en ese destino.'); return publico(j.data());
    }
    // Si la respuesta final se perdió, el mismo destino permite encontrar el resultado.
    const existente = await db.doc(`clubes/${destino}`).get();
    if (existente.exists) {
      exigir(existente.data().restauradoDe === respaldoId && existente.data().restauracionId,'Ese club ya existe. No se sobrescribe.');
      return publico((await ref(existente.data().restauracionId).get()).data());
    }
    await archivos.destinoVacio(destino);
    const backup = await ref(respaldoId).get();
    exigir(backup.exists && backup.data().tipo === 'respaldo' && backup.data().estado === 'completado','Elegí un respaldo completo.');
    const m = await archivos.leerManifiesto(backup.data());
    const id = nuevoId();
    return db.runTransaction(async tx => {
      const [a,c,e,l,b] = await Promise.all([tx.get(db.doc(`usuarios/${uid}`)),tx.get(db.doc(`clubes/${destino}`)),tx.get(db.doc(`eliminaciones_club/${destino}`)),tx.get(db.doc(`restauraciones_club/${destino}`)),tx.get(ref(respaldoId))]);
      validarActor(a.data()); exigir(!c.exists && !e.exists && !l.exists,'El destino ya existe o está reservado. Elegí uno nuevo.');
      exigir(b.data()?.estado === 'completado','El respaldo no está disponible.');
      const job = {id,tokenSeed:randomBytes(32).toString('hex'),tipo:'restauracion',clubId:m.clubId,respaldoId,destino,nombre:backup.data().nombre,estado:'imagenes',creadoMs:now(),creadoPor:uid,procesados:0,leaseHasta:0,documentos:documentosRestaurables(m).length,archivos:m.files.length};
      tx.create(ref(id),job);
      tx.create(db.doc(`restauraciones_club/${destino}`),{operacion:id});
      tx.create(db.doc(`clubes/${destino}`),{nombre:`${job.nombre} (recuperando)`,origenDatos:'central',activo:false,estado:'restaurando'});
      return publico(job);
    });
  }
  async function continuar(uid,id) {
    validarOperacion(id); const lease = nuevoId();
    const job = await db.runTransaction(async tx => {
      const [a,j] = await Promise.all([tx.get(db.doc(`usuarios/${uid}`)),tx.get(ref(id))]);
      validarActor(a.data()); exigir(j.exists,'Operación inexistente.',404);
      const data = j.data(); if (data.estado === 'completado') return data;
      exigir((data.leaseHasta || 0) < now(),'Hay un paso en curso. Esperá unos minutos y actualizá.',409);
      tx.update(ref(id),{lease,leaseHasta:now()+600000}); return {...data,lease};
    });
    if (job.estado === 'completado') return publico(job);
    async function guardar(cambios) {
      await db.runTransaction(async tx => {
        const [a,j] = await Promise.all([tx.get(db.doc(`usuarios/${uid}`)),tx.get(ref(id))]);
        validarActor(a.data()); exigir(j.data()?.lease === lease,'La operación cambió. Actualizá.');
        tx.update(ref(id),{...cambios,leaseHasta:0});
      });
      return publico({...job,...cambios});
    }
    try {
      await archivos.comprobarBucket();
      if (job.tipo === 'respaldo' && job.estado === 'preparando') {
        const existente = await archivos.capturaExistente(job);
        const m = existente?.manifest || await archivos.capturar(job.clubId);
        const descriptor = existente || await archivos.guardarUnico(`respaldos/${id}/manifest.json`,Buffer.from(JSON.stringify(m)));
        return await guardar({estado:'imagenes',manifestGeneration:descriptor.generation,manifestHash:descriptor.hash,readTime:m.readTime,documentos:m.documents.length,archivos:m.files.length,bytes:m.files.reduce((s,f)=>s+f.size,0),enlacesExternos:m.enlacesExternos || 0,procesados:0});
      }
      const backup = job.tipo === 'respaldo' ? job : (await ref(job.respaldoId).get()).data();
      exigir(backup && (job.tipo === 'respaldo' || backup.estado === 'completado'),'Respaldo no disponible.');
      const m = await archivos.leerManifiesto(backup);
      if (job.estado === 'imagenes') {
        const hasta = Math.min(job.procesados + 3,m.files.length);
        for (let i=job.procesados;i<hasta;i++) {
          await actor(uid);
          if (job.tipo === 'respaldo') await archivos.copiarRespaldo(id,m.files[i],i);
          else await archivos.copiarRestauracion(job,m,m.files[i],i);
        }
        const fin = hasta === m.files.length;
        return await guardar({procesados:fin && job.tipo === 'restauracion' ? 0 : hasta,estado:fin ? (job.tipo === 'respaldo' ? 'completado':'documentos'):'imagenes'});
      }
      exigir(job.tipo === 'restauracion' && job.estado === 'documentos','Estado incompatible.');
      const docs = documentosRestaurables(m); const hasta = Math.min(job.procesados+20,docs.length);
      await actor(uid);
      await archivos.escribirDocumentos(docs.slice(job.procesados,hasta).map(d => transformarDocumento(d,m,job.destino,job.tokenSeed)));
      if (hasta < docs.length) return await guardar({procesados:hasta});
      const root = transformarDocumento(m.documents.find(d=>d.name === `${ROOT}/clubes/${m.clubId}`),m,job.destino,job.tokenSeed);
      // No copiar estado operativo ni cuentas o secretos globales del club original.
      for (const k of ['creadoPor','creadoEl','activadoPor','activadoEl','actualizadoPor','actualizadoEl','eliminacionClub']) delete root.fields[k];
      Object.assign(root.fields,{id:{stringValue:job.destino},slug:{stringValue:job.destino},nombre:{stringValue:`${job.nombre} (recuperado)`},origenDatos:{stringValue:'central'},estado:{stringValue:'borrador'},activo:{booleanValue:false},restauradoDe:{stringValue:job.respaldoId},restauracionId:{stringValue:id},creadoPor:{stringValue:uid}});
      await archivos.finalizar(job,root,uid,lease);
      return publico({...job,estado:'completado',procesados:docs.length});
    } catch (e) {
      // Una interrupción abrupta conserva el lease hasta su vencimiento. Un fallo normal libera para reintentar.
      await db.runTransaction(async tx => { const s=await tx.get(ref(id)); if(s.data()?.lease===lease) tx.update(ref(id),{leaseHasta:0}); }).catch(()=>{});
      throw e;
    }
  }
  return {listar,crear,restaurar,continuar};
}
module.exports = {crearServicioRespaldos};
