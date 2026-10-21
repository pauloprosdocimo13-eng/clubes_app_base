"use strict";
const {createHash, randomBytes} = require("node:crypto");

class ErrorAdministradores extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
function validarClubId(id) {
  if (typeof id !== "string" || !/^[a-z0-9][a-z0-9_-]{1,39}$/.test(id)) {
    throw new ErrorAdministradores(400, "Club inválido.");
  }
  return id;
}
function validarClub(id, club) {
  if (!club || ["guemes", "fatima", "laloma"].includes(id) ||
      !(club.origenDatos === "central" || id === "generico") ||
      !(club.estado === "borrador" || club.activo === true)) {
    throw new ErrorAdministradores(400, "Elegí un club central activo o en borrador.");
  }
}
function validarSuperadmin(perfil) {
  if (perfil?.activo !== true || perfil.rol !== "superadmin") {
    throw new ErrorAdministradores(403, "Se requiere un superadmin activo de TuSede.");
  }
}
function validarAdministrador(datos) {
  const clubId = validarClubId(datos?.clubId);
  const nombre = typeof datos.nombre === "string" ? datos.nombre.trim() : "";
  const email = typeof datos.email === "string" ? datos.email.trim().toLowerCase() : "";
  if (nombre.length < 2 || nombre.length > 100) {
    throw new ErrorAdministradores(400, "El nombre debe tener entre 2 y 100 caracteres.");
  }
  const dominio = email.split("@")[1] || "";
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
      /\.(test|invalid|localhost|example)$/.test(dominio) ||
      /^(example\.(com|org|net))$/.test(dominio)) {
    throw new ErrorAdministradores(400, "Ingresá un correo real al que el administrador tenga acceso.");
  }
  // El cliente no decide rol, UID, permisos ni clubes adicionales.
  return {clubId, nombre, email};
}
function uidAdministrador(clubId, email) {
  return "clubadmin_" + createHash("sha256").update(`${clubId}\n${email}`).digest("hex").slice(0, 48);
}
function perfilCompatible(perfil, datos) {
  return perfil.origenAlta === "plataforma_club" && perfil.rol === "admin" &&
    perfil.activo === true && perfil.email === datos.email &&
    perfil.clubPrincipal === datos.clubId && Array.isArray(perfil.clubIds) &&
    perfil.clubIds.length === 1 && perfil.clubIds[0] === datos.clubId;
}
async function comprobarAcceso(db, actorUid, clubId) {
  if (!actorUid) throw new ErrorAdministradores(403, "Sesión requerida.");
  validarSuperadmin((await db.doc(`usuarios/${actorUid}`).get()).data());
  validarClub(clubId, (await db.doc(`clubes/${clubId}`).get()).data());
}
async function listarAdministradores({db, actorUid, clubId}) {
  validarClubId(clubId);
  await comprobarAcceso(db, actorUid, clubId);
  const snap = await db.collection("usuarios").where("clubIds", "array-contains", clubId).get();
  return snap.docs.filter(d => ["admin", "admin_club"].includes(d.data().rol)).map(d => {
    const p = d.data();
    return {uid: d.id, nombre: p.nombre || "", email: p.email || "", activo: p.activo === true};
  }).sort((a, b) => a.nombre.localeCompare(b.nombre));
}
async function asignarAdministrador({db, auth, actorUid, datos, serverTimestamp}) {
  const validado = validarAdministrador(datos);
  const {clubId, nombre, email} = validado;
  await comprobarAcceso(db, actorUid, clubId);
  const uid = uidAdministrador(clubId, email);
  let cuenta;
  try { cuenta = await auth.getUserByEmail(email); }
  catch (e) { if (e.code !== "auth/user-not-found") throw e; }
  if (!cuenta) {
    try {
      cuenta = await auth.createUser({
        uid, email, displayName: nombre, emailVerified: false,
        // Nadie recibe esta contraseña. El titular establece la suya por email.
        password: randomBytes(32).toString("base64url"),
      });
    } catch (e) {
      if (!["auth/email-already-exists", "auth/uid-already-exists"].includes(e.code)) throw e;
      cuenta = await auth.getUserByEmail(email);
    }
  }
  if (cuenta.uid !== uid || cuenta.disabled) {
    throw new ErrorAdministradores(409,
      "Ese correo ya pertenece a otra cuenta o está deshabilitado. No se modificaron sus permisos ni su contraseña.");
  }
  // Auth y Firestore no comparten transacción. Si falla el perfil, se conserva
  // la cuenta sin permisos y el mismo email permite completar el alta al reintentar.
  const resultado = await db.runTransaction(async tx => {
    const actor = await tx.get(db.doc(`usuarios/${actorUid}`));
    const club = await tx.get(db.doc(`clubes/${clubId}`));
    const ref = db.doc(`usuarios/${uid}`);
    const previo = await tx.get(ref);
    validarSuperadmin(actor.data());
    validarClub(clubId, club.data());
    if (previo.exists) {
      if (!perfilCompatible(previo.data(), validado)) {
        throw new ErrorAdministradores(409, "La cuenta existente requiere revisión. No se modificó.");
      }
      return {uid, email, nombre: previo.data().nombre, yaExistia: true};
    }
    tx.create(ref, {
      nombre, email, rol: "admin", clubPrincipal: clubId, clubIds: [clubId], activo: true,
      origenAlta: "plataforma_club", creadoPor: actorUid, creadoEl: serverTimestamp(),
    });
    tx.create(db.doc(`auditoria_plataforma/alta_${uid}`), {
      accion: "asignar_administrador", clubId, usuarioUid: uid,
      actorUid, fecha: serverTimestamp(),
    });
    return {uid, email, nombre, yaExistia: false};
  });
  return resultado;
}
module.exports = {ErrorAdministradores, validarAdministrador, uidAdministrador,
  asignarAdministrador, listarAdministradores};
