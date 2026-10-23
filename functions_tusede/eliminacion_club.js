"use strict";
const {createHash, randomUUID} = require('node:crypto');
class ErrorEliminacion extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
const exigir = (condition, message, status = 409) => {
  if (!condition) throw new ErrorEliminacion(status, message);
};
function validarId(id) {
  exigir(typeof id === 'string' && /^[a-z0-9][a-z0-9_-]{1,39}$/.test(id) &&
    !['guemes', 'fatima', 'laloma', 'generico', 'tusede'].includes(id),
  'Club protegido o identificador inválido.', 400);
}
function validarClub(club) {
  exigir(club?.origenDatos === 'central' &&
    ['borrador', 'activo'].includes(club.estado), 'Solo se eliminan clubes Central propios.');
}
function validarActor(perfil) {
  exigir(perfil?.activo === true && perfil.rol === 'superadmin', 'Se requiere un superadmin activo.', 403);
}
function clasificar(uid, perfil, clubId, actorUid) {
  exigir(Array.isArray(perfil.clubIds) && perfil.clubIds.every(x => typeof x === 'string'),
    'Un perfil tiene asociaciones inválidas. Requiere revisión.');
  const restantes = [...new Set(perfil.clubIds.filter(x => x !== clubId))];
  exigir(!perfil.clubPrincipal || perfil.clubPrincipal === clubId || restantes.includes(perfil.clubPrincipal),
    'Un perfil tiene un club principal inconsistente.');
  if (uid === actorUid || perfil.rol === 'superadmin') return {tipo: 'protegida', restantes};
  if (restantes.length) return {tipo: 'compartida', restantes};
  exigir(perfil.origenAlta === 'plataforma_club',
    'Una cuenta exclusiva no fue creada por la plataforma. Requiere revisión antes de eliminar el club.');
  return {tipo: 'exclusiva', restantes};
}
const sello = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const version = snap => snap.updateTime ? `${snap.updateTime.seconds}:${snap.updateTime.nanoseconds}` : null;
async function perfiles(db, clubId, tx) {
  const leer = q => tx ? tx.get(q) : q.get();
  const [a, b] = await Promise.all([
    leer(db.collection('usuarios').where('clubIds', 'array-contains', clubId)),
    leer(db.collection('usuarios').where('clubPrincipal', '==', clubId)),
  ]);
  return [...new Map([...a.docs, ...b.docs].map(d => [d.id, d])).values()].sort((a, b) => a.id.localeCompare(b.id));
}
async function cuenta(auth, uid) {
  try { return await auth.getUser(uid); }
  catch (e) { if (e.code === 'auth/user-not-found') return null; throw e; }
}
function validarCuenta(user) {
  exigir(!user || (!user.tenantId && Object.keys(user.customClaims || {}).length === 0),
    'Una cuenta tiene permisos especiales de Authentication. Requiere revisión.');
}
function crearServicioEliminacion({db, auth, bucket, now = Date.now}) {
  const clubRef = id => db.doc(`clubes/${id}`);
  const jobRef = id => db.doc(`eliminaciones_club/${id}`);
  async function actor(uid) { validarActor((await db.doc(`usuarios/${uid}`).get()).data()); }
  async function preparar(id, uid) {
    validarId(id); await actor(uid);
    const previous = await jobRef(id).get();
    if (previous.exists) return {enCurso: true, estado: previous.data().estado};
    const club = await clubRef(id).get(); validarClub(club.data());
    const users = await perfiles(db, id);
    exigir(users.length <= 200, 'Este club requiere una eliminación asistida por su cantidad de usuarios.');
    const accounts = [];
    for (const d of users) {
      const p = d.data(); const decision = clasificar(d.id, p, id, uid);
      if (decision.tipo === 'exclusiva') validarCuenta(await cuenta(auth, d.id));
      accounts.push({uid: d.id, tipo: decision.tipo, nombre: p.nombre || '', email: p.email || '', version: version(d)});
    }
    const collections = await clubRef(id).listCollections();
    const [files, next] = await bucket.getFiles({prefix: `clubes/${id}/`, versions: true, maxResults: 501, autoPaginate: false});
    const token = sello({club: version(club), cuentas: accounts});
    return {enCurso: false, token, nombre: club.data().nombre, colecciones: collections.map(c => c.id),
      archivos: files.length, masArchivos: !!next, cuentas: accounts};
  }
  async function iniciar(id, uid, confirmacion, token) {
    validarId(id); exigir(confirmacion === id, 'Escribí el identificador exacto para confirmar.', 400);
    await actor(uid);
    const existing = await jobRef(id).get();
    if (existing.exists) return {estado: existing.data().estado};
    const preview = await preparar(id, uid);
    exigir(!preview.enCurso && preview.token === token, 'El club cambió. Actualizá la vista previa antes de confirmar.');
    await db.runTransaction(async tx => {
      const [a, c, j, users] = await Promise.all([
        tx.get(db.doc(`usuarios/${uid}`)), tx.get(clubRef(id)), tx.get(jobRef(id)),
        perfiles(db, id, tx),
      ]);
      validarActor(a.data());
      if (j.exists) return;
      validarClub(c.data());
      const accounts = users.map(d => ({uid: d.id, tipo: clasificar(d.id, d.data(), id, uid).tipo,
        nombre: d.data().nombre || '', email: d.data().email || '', version: version(d)}));
      exigir(sello({club: version(c), cuentas: accounts}) === token, 'Los datos cambiaron. Actualizá la vista previa.');
      const started = now();
      tx.create(jobRef(id), {clubId: id, nombre: c.data().nombre, estado: 'usuarios', iniciadoPor: uid,
        iniciadoMs: started, actualizadoMs: started, exclusivos: accounts.filter(p => p.tipo === 'exclusiva').map(p => p.uid),
        procesados: 0, leaseHasta: 0});
      tx.update(clubRef(id), {activo: false, estado: 'eliminando'});
      for (const d of users) {
        const decision = clasificar(d.id, d.data(), id, uid);
        if (decision.tipo === 'exclusiva') {
          tx.update(d.ref, {activo: false, eliminacionClub: id});
        } else {
          tx.update(d.ref, {clubIds: decision.restantes,
            clubPrincipal: d.data().clubPrincipal === id ? (decision.restantes[0] || null) : (d.data().clubPrincipal || null)});
        }
      }
      tx.create(db.doc(`auditoria_plataforma/eliminacion_${id}`), {
        accion: 'eliminar_club', clubId: id, actorUid: uid, estado: 'iniciada', fechaMs: started,
        exclusivas: accounts.filter(p => p.tipo === 'exclusiva').length,
        compartidas: accounts.filter(p => p.tipo === 'compartida').length,
        protegidas: accounts.filter(p => p.tipo === 'protegida').length,
      });
    });
    return {estado: 'usuarios'};
  }
  async function continuar(id, uid) {
    validarId(id); await actor(uid);
    const lease = randomUUID();
    const job = await db.runTransaction(async tx => {
      const [a, j] = await Promise.all([tx.get(db.doc(`usuarios/${uid}`)), tx.get(jobRef(id))]);
      validarActor(a.data()); exigir(j.exists, 'No hay una eliminación iniciada.');
      const data = j.data();
      if (data.estado === 'completada') return data;
      exigir(!(data.leaseHasta > now()), 'Hay un paso en curso. Esperá hasta 90 segundos y reintentá.');
      tx.update(jobRef(id), {lease, leaseHasta: now() + 90000, actualizadoMs: now()});
      return data;
    });
    if (job.estado === 'completada') return {estado: 'completada'};
    async function guardar(cambios) {
      await db.runTransaction(async tx => {
        const j = await tx.get(jobRef(id));
        exigir(j.data()?.lease === lease, 'Otra ejecución tomó la operación.');
        tx.update(jobRef(id), {...cambios, leaseHasta: 0, actualizadoMs: now()});
      });
      return {estado: cambios.estado || job.estado};
    }
    try {
      // Dar tiempo a solicitudes públicas/archivos que ya estaban en vuelo.
      if (now() - job.iniciadoMs < 65000) return await guardar({espera: true});
      if (job.estado === 'usuarios') {
        const target = job.exclusivos[job.procesados];
        if (!target) return await guardar({estado: 'documentos'});
        const ref = db.doc(`usuarios/${target}`); const p = (await ref.get()).data();
        if (p) {
          exigir(p.eliminacionClub === id && p.activo === false && clasificar(target, p, id, uid).tipo === 'exclusiva',
            'La cuenta cambió durante la eliminación. Requiere revisión.');
        }
        const user = await cuenta(auth, target);
        exigir(p || !user, 'Cuenta sin perfil de eliminación; requiere revisión.');
        validarCuenta(user);
        if (user) await auth.deleteUser(target);
        // El UID queda en el trabajo hasta completar ambos sistemas.
        await db.recursiveDelete(ref);
        return await guardar({procesados: job.procesados + 1});
      }
      if (job.estado === 'documentos') {
        const collections = await clubRef(id).listCollections();
        if (collections.length) {
          await db.recursiveDelete(collections[0]);
          return await guardar({});
        }
        return await guardar({estado: 'archivos'});
      }
      if (job.estado === 'archivos') {
        const [files] = await bucket.getFiles({prefix: `clubes/${id}/`, versions: true, maxResults: 25, autoPaginate: false});
        for (const file of files) {
          exigir(file.name.startsWith(`clubes/${id}/`), 'Ruta de archivo fuera del club.');
          await file.delete({ignoreNotFound: true});
        }
        return await guardar(files.length ? {} : {estado: 'verificando'});
      }
      exigir(job.estado === 'verificando', 'Estado de eliminación desconocido.');
      const remaining = await perfiles(db, id);
      exigir(remaining.length === 0, 'Aparecieron usuarios asociados; requiere revisión.');
      for (const target of job.exclusivos) exigir(!(await cuenta(auth, target)), 'Queda una cuenta por eliminar.');
      if ((await clubRef(id).listCollections()).length) return await guardar({estado: 'documentos'});
      const [files] = await bucket.getFiles({prefix: `clubes/${id}/`, versions: true, maxResults: 1, autoPaginate: false});
      if (files.length) return await guardar({estado: 'archivos'});
      await db.runTransaction(async tx => {
        const [a, j, c] = await Promise.all([tx.get(db.doc(`usuarios/${uid}`)), tx.get(jobRef(id)), tx.get(clubRef(id))]);
        validarActor(a.data()); exigir(j.data()?.lease === lease, 'Operación ocupada.');
        exigir(!c.exists || c.data().estado === 'eliminando', 'El club cambió; no se puede completar.');
        tx.delete(clubRef(id));
        tx.update(jobRef(id), {estado: 'completada', leaseHasta: 0, actualizadoMs: now()});
        tx.update(db.doc(`auditoria_plataforma/eliminacion_${id}`), {estado: 'completada', completadoMs: now()});
      });
      return {estado: 'completada'};
    } catch (error) {
      // Si el proceso es terminado por timeout, el lease vence sin perder progreso.
      await guardar({}).catch(() => {});
      throw error;
    }
  }
  return {preparar, iniciar, continuar};
}
module.exports = {crearServicioEliminacion, ErrorEliminacion, validarId, clasificar, validarCuenta};
