"use strict";
const {onRequest} = require("firebase-functions/v2/https");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {randomUUID} = require("node:crypto");
const {ErrorAdministradores, asignarAdministrador, listarAdministradores} = require("./administradores_club");
const {validarAlta, validarEdicion, validarActivacion, esClubCentralActivo} = require("./plataforma_validacion");
exports.administrarPlataforma = onRequest({region: "southamerica-east1", cors: true, timeoutSeconds: 60}, async (req, res) => {
  res.set("Cache-Control", "no-store");
  if (req.method !== "POST") return res.status(405).json({ok: false, mensaje: "Usá POST."});
  const body = req.body || {};
  if (body.accion === "catalogo") {
    try {
      const snap = await getFirestore().collection("clubes").where("activo", "==", true).get();
      const clubes = snap.docs.filter(d => esClubCentralActivo(d.id, d.data())).map(d => {
        const data = d.data();
        const i = data.identidad || {};
        return {id: d.id, nombre: data.nombre, slug: data.slug || d.id, activo: true, origenDatos: "central", estado: "activo", flavor_legacy: "generico",
          identidad: {nombreCorto: i.nombreCorto || "", logoUrl: i.logoUrl || "", colorPrimario: i.colorPrimario || "", colorSecundario: i.colorSecundario || "", lema: i.lema || ""},
          modulos: data.modulos || {}};
      });
      return res.json({ok: true, clubes});
    } catch (e) { console.error("catalogo", e); return res.status(503).json({ok: false, mensaje: "No se pudo cargar el catálogo."}); }
  }
  let usuario;
  try {
    const match = /^Bearer (.+)$/.exec(req.headers.authorization || "");
    if (!match) throw new Error();
    usuario = await getAuth().verifyIdToken(match[1], true);
  } catch (_) { return res.status(401).json({ok: false, mensaje: "Iniciá sesión nuevamente."}); }
  const db = getFirestore();
  try {
    const perfil = await db.doc(`usuarios/${usuario.uid}`).get();
    if (!perfil.exists || perfil.data().activo !== true || perfil.data().rol !== "superadmin") return res.status(403).json({ok: false, mensaje: "Se requiere un superadmin activo de TuSede."});

    if (body.accion === "listarAdministradores" || body.accion === "asignarAdministrador") {
      try {
        if (body.accion === "listarAdministradores") {
          const administradores = await listarAdministradores({db, actorUid: usuario.uid, clubId: body.clubId});
          return res.json({ok: true, administradores});
        }
        const administrador = await asignarAdministrador({db, auth: getAuth(), actorUid: usuario.uid,
          datos: body, serverTimestamp: () => FieldValue.serverTimestamp()});
        return res.json({ok: true, administrador});
      } catch (e) {
        if (e instanceof ErrorAdministradores) return res.status(e.status).json({ok: false, mensaje: e.message});
        console.error("administradores_club", e.code || e.name);
        return res.status(500).json({ok: false, mensaje: "No se pudo completar el alta. Reintentá con el mismo correo para recuperar una operación pendiente."});
      }
    }

    if (body.accion === "listar") {
      const clubes = await db.collection("clubes").orderBy("nombre").get();
      return res.json({ok: true, clubes: clubes.docs.map(d => ({...d.data(), id: d.id}))});
    }
    if (body.accion === "crear") {
      let datos;
      try { datos = validarAlta(body.club); } catch (e) { return res.status(400).json({ok: false, mensaje: e.message}); }
      const id = String(body.club.id).trim();
      const ref = db.doc(`clubes/${id}`);
      const creado = await db.runTransaction(async tx => {
        const anterior = await tx.get(ref);
        if (anterior.exists) return false;
        tx.create(ref, {...datos, creadoPor: usuario.uid, creadoEl: FieldValue.serverTimestamp()});
        tx.create(ref.collection("configuracion").doc("general"), {activar_multi_actividad: true, menu_deportes: []});
        return true;
      });
      if (!creado) return res.status(409).json({ok: false, mensaje: "Ya existe un club con ese identificador."});
      return res.status(201).json({ok: true, id});
    }
    if (body.accion === "activar") {
      const id = String(body.clubId || "");
      if (!/^[a-z0-9][a-z0-9_-]{1,39}$/.test(id)) return res.status(400).json({ok: false, mensaje: "Club inválido."});
      const ref = db.doc(`clubes/${id}`);
      let mensaje;
      const activado = await db.runTransaction(async tx => {
        mensaje = undefined;
        const snap = await tx.get(ref);
        try { validarActivacion(id, snap.data()); }
        catch (e) { mensaje = e.message; return false; }
        tx.update(ref, {activo: true, estado: "activo", activadoPor: usuario.uid, activadoEl: FieldValue.serverTimestamp(), versionConfiguracion: FieldValue.increment(1)});
        return true;
      });
      if (!activado) return res.status(400).json({ok: false, mensaje});
      return res.json({ok: true, id});
    }
    if (body.accion === "editar") {
      const id = String(body.club?.id || "").trim();
      if (!/^[a-z0-9][a-z0-9_-]{1,39}$/.test(id)) return res.status(400).json({ok: false, mensaje: "Club inválido."});
      const ref = db.doc(`clubes/${id}`);
      let errorValidacion;
      const actualizado = await db.runTransaction(async tx => {
        errorValidacion = undefined;
        const anterior = await tx.get(ref);
        if (!anterior.exists) { errorValidacion = "El club ya no existe."; return false; }
        let cambios;
        try { cambios = validarEdicion(body.club, anterior.data()); }
        catch (e) { errorValidacion = e.message; return false; }
        tx.update(ref, {...cambios, versionConfiguracion: FieldValue.increment(1), actualizadoPor: usuario.uid, actualizadoEl: FieldValue.serverTimestamp()});
        return true;
      });
      if (!actualizado) return res.status(400).json({ok: false, mensaje: errorValidacion});
      return res.json({ok: true, id});
    }
    if (body.accion === "logo") {
      const id = String(body.clubId || "");
      if (!/^[a-z0-9][a-z0-9_-]{1,39}$/.test(id)) return res.status(400).json({ok: false, mensaje: "Club inválido."});
      const ref = db.doc(`clubes/${id}`);
      const club = await ref.get();
      if (!club.exists || club.data().estado !== "borrador" || club.data().origenDatos !== "central") return res.status(409).json({ok: false, mensaje: "Solo se permite cargar el logo de un nuevo club en borrador."});
      const buffer = Buffer.from(String(body.base64 || ""), "base64");
      const png = buffer.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
      const jpg = buffer[0] === 255 && buffer[1] === 216 && buffer[2] === 255;
      if ((!png && !jpg) || buffer.length > 4 * 1024 * 1024) return res.status(400).json({ok: false, mensaje: "Elegí una imagen PNG o JPG de hasta 4 MB."});
      const bucket = getStorage().bucket("tu-sede-app.firebasestorage.app");
      const token = randomUUID();
      const path = `clubes/${id}/logos/${randomUUID()}.${png ? "png" : "jpg"}`;
      await bucket.file(path).save(buffer, {resumable: false, metadata: {contentType: png ? "image/png" : "image/jpeg", metadata: {firebaseStorageDownloadTokens: token}}});
      const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
      await ref.update({"identidad.logoUrl": url, actualizadoPor: usuario.uid, actualizadoEl: FieldValue.serverTimestamp()});
      return res.json({ok: true, logoUrl: url});
    }
    return res.status(400).json({ok: false, mensaje: "Acción desconocida."});
  } catch (e) {
    console.error("administrarPlataforma", e);
    return res.status(500).json({ok: false, mensaje: "No se pudo completar la operación. Revisá el listado antes de reintentar."});
  }
});
