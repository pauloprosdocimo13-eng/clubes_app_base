"use strict";
const {createHash, randomBytes} = require('node:crypto');
const {validarAdministrador} = require('./administradores_club');
const ROLES = ['tesoreria', 'administracion', 'deportes', 'institucional', 'ingreso'];
class ErrorEquipo extends Error { constructor(status, message) { super(message); this.status = status; } }
function exigir(ok, message, status = 403) { if (!ok) throw new ErrorEquipo(status, message); }
function validarActor(p, clubId) {
  exigir(p?.activo === true && (p.rol === 'superadmin' ||
    (['admin', 'admin_club'].includes(p.rol) && p.clubIds?.includes(clubId))), 'Solo un administrador del club puede gestionar su equipo.');
}
function validarClub(id, c, eliminado) {
  exigir(typeof id === 'string' && /^[a-z0-9][a-z0-9_-]{1,39}$/.test(id), 'Club inválido.', 400);
  exigir(c?.origenDatos === 'central' && !['guemes','fatima','laloma'].includes(id) &&
    !eliminado && (c.estado === 'borrador' || (c.estado === 'activo' && c.activo === true)), 'El club no está disponible para gestionar usuarios.', 409);
}
function editable(p, clubId, uid, actorUid) {
  return uid !== actorUid && p?.origenAlta === 'plataforma_club' && ROLES.includes(p.rol) &&
    p.clubPrincipal === clubId && Array.isArray(p.clubIds) && p.clubIds.length === 1 && p.clubIds[0] === clubId;
}
async function contexto(db, actorUid, clubId, tx) {
  exigir(typeof clubId === 'string' && /^[a-z0-9][a-z0-9_-]{1,39}$/.test(clubId), 'Club inválido.', 400);
  const leer = path => tx ? tx.get(db.doc(path)) : db.doc(path).get();
  const [actor, club, eliminado] = await Promise.all([leer(`usuarios/${actorUid}`), leer(`clubes/${clubId}`), leer(`eliminaciones_club/${clubId}`)]);
  validarActor(actor.data(), clubId); validarClub(clubId, club.data(), eliminado.exists);
}
function publico(doc, clubId, actorUid) {
  const p = doc.data();
  return {uid: doc.id, nombre: p.nombre || '', email: p.email || '', rol: p.rol, activo: p.activo === true, editable: editable(p, clubId, doc.id, actorUid)};
}
async function gestionarEquipo({db, auth, actorUid, datos, timestamp}) {
  const {clubId, accion} = datos;
  await contexto(db, actorUid, clubId);
  if (accion === 'listarEquipo') {
    const snap = await db.collection('usuarios').where('clubIds', 'array-contains', clubId).get();
    return {usuarios: snap.docs.map(d => publico(d, clubId, actorUid)).sort((a,b) => a.nombre.localeCompare(b.nombre))};
  }
  exigir(ROLES.includes(datos.rol), 'Elegí un rol de trabajo válido.', 400);
  if (accion === 'crearEquipo') {
    let alta;
    try { alta = validarAdministrador(datos); } catch (e) { throw new ErrorEquipo(400, e.message); }
    const {nombre, email} = alta;
    const permisos = (await db.doc(`clubes/${clubId}/configuracion/permisos_roles`).get()).data();
    exigir(Array.isArray(permisos?.[datos.rol]) && permisos[datos.rol].length > 0,
      'Guardá primero los permisos de este rol en Matriz de Permisos.', 409);
    const uid = 'clubequipo_' + createHash('sha256').update(`${clubId}\n${email}`).digest('hex').slice(0,48);
    let cuenta;
    try { cuenta = await auth.getUserByEmail(email); } catch (e) { if (e.code !== 'auth/user-not-found') throw e; }
    if (!cuenta) {
      try { cuenta = await auth.createUser({uid, email, displayName: nombre, password: randomBytes(32).toString('base64url'), emailVerified: false}); }
      catch (e) { if (!['auth/email-already-exists','auth/uid-already-exists'].includes(e.code)) throw e; cuenta = await auth.getUserByEmail(email); }
    }
    exigir(cuenta.uid === uid && !cuenta.disabled && !cuenta.tenantId && !Object.keys(cuenta.customClaims || {}).length,
      'Ese correo pertenece a otra cuenta o requiere revisión. No se modificó.', 409);
    return db.runTransaction(async tx => {
      await contexto(db, actorUid, clubId, tx);
      const ref = db.doc(`usuarios/${uid}`);
      const anterior = await tx.get(ref);
      const matriz = await tx.get(db.doc(`clubes/${clubId}/configuracion/permisos_roles`));
      exigir(Array.isArray(matriz.data()?.[datos.rol]) && matriz.data()[datos.rol].length > 0,
        'Guardá primero los permisos de este rol en Matriz de Permisos. Reintentá luego con el mismo correo.', 409);
      if (anterior.exists) {
        exigir(editable(anterior.data(), clubId, uid, actorUid) && anterior.data().email === email, 'La cuenta existente requiere revisión.', 409);
        return {usuario: publico(anterior, clubId, actorUid), yaExistia: true};
      }
      const perfil = {nombre, email, rol: datos.rol, clubIds: [clubId], clubPrincipal: clubId, activo: true,
        origenAlta: 'plataforma_club', creadoPor: actorUid, creadoEl: timestamp()};
      tx.create(ref, perfil);
      tx.set(db.collection('auditoria_plataforma').doc(), {accion:'crear_equipo',clubId,usuarioUid:uid,actorUid,rol:datos.rol,fecha:timestamp()});
      return {usuario:{uid,nombre,email,rol:datos.rol,activo:true,editable:true}};
    });
  }
  exigir(accion === 'editarEquipo' && typeof datos.uid === 'string' && /^[a-zA-Z0-9_-]{1,128}$/.test(datos.uid) && typeof datos.activo === 'boolean', 'Solicitud inválida.', 400);
  return db.runTransaction(async tx => {
    await contexto(db, actorUid, clubId, tx);
    const ref = db.doc(`usuarios/${datos.uid}`);
    const anterior = await tx.get(ref);
    exigir(editable(anterior.data(), clubId, datos.uid, actorUid), 'No se puede modificar esta cuenta desde el equipo del club.');
    tx.update(ref, {rol:datos.rol,activo:datos.activo,actualizadoPor:actorUid,actualizadoEl:timestamp()});
    tx.set(db.collection('auditoria_plataforma').doc(), {accion:'editar_equipo',clubId,usuarioUid:datos.uid,actorUid,rol:datos.rol,activo:datos.activo,fecha:timestamp()});
    return {actualizado:true};
  });
}
module.exports = {gestionarEquipo, ErrorEquipo, validarActor, validarClub, editable, ROLES};
