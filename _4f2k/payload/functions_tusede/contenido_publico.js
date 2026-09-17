const functions = require("firebase-functions/v1");
const {getApps, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();
const REGION = "southamerica-east1";

// Migración deliberadamente explícita.
// Güemes NO se sirve desde este backend central todavía.
const CLUBES_HABILITADOS = new Set(["generico"]);

function texto(valor) {
  return String(valor ?? "").trim();
}

function clubIdSeguro(valor) {
  return texto(valor).toLowerCase();
}

function topicGeneralClub(clubId) {
  const seguro = clubId.replace(/[^a-z0-9_-]/g, "_");
  return `tusede_${seguro}_general`;
}

function fechaMillis(valor) {
  if (valor && typeof valor.toMillis === "function") {
    return valor.toMillis();
  }

  return 0;
}

function responder(res, status, payload) {
  res.status(status).json(payload);
}

async function obtenerClubHabilitado(clubId, modulo) {
  if (!/^[a-z0-9_-]{2,40}$/.test(clubId)) {
    return null;
  }

  if (!CLUBES_HABILITADOS.has(clubId)) {
    return null;
  }

  const ref = db.collection("clubes").doc(clubId);
  const snap = await ref.get();

  if (!snap.exists || snap.data()?.activo !== true) {
    return null;
  }

  const modulos = snap.data()?.modulos || {};
  if (modulo && modulos[modulo] === false) {
    return null;
  }

  return ref;
}

function sanitizarNoticia(doc) {
  const data = doc.data() || {};

  return {
    _doc_id: doc.id,
    titulo: texto(data.titulo),
    bajada: texto(data.bajada),
    cuerpo: texto(data.cuerpo),
    imagen_url: texto(data.imagen_url),
    visible: data.visible !== false,
    fecha_ms: fechaMillis(data.fecha),
  };
}

function sanitizarAviso(doc) {
  const data = doc.data() || {};

  return {
    _doc_id: doc.id,
    titulo: texto(data.titulo),
    mensaje: texto(data.mensaje),
    importante: data.importante === true,
    deporte_id: texto(data.deporte_id),
    fecha_ms: fechaMillis(data.fecha),
  };
}

function sanitizarGaleria(doc) {
  const data = doc.data() || {};

  return {
    _doc_id: doc.id,
    titulo: texto(data.titulo),
    imagen_url: texto(data.imagen_url),
    categoria: texto(data.categoria) || "General",
    deporte_id: texto(data.deporte_id),
    fecha_ms: fechaMillis(data.fecha),
  };
}

function sanitizarProducto(doc) {
  const data = doc.data() || {};
  const precio = Number(data.precio);

  return {
    _doc_id: doc.id,
    titulo: texto(data.titulo),
    precio: Number.isFinite(precio) ? precio : 0,
    descripcion: texto(data.descripcion),
    imagen_url: texto(data.imagen_url),
    activo: data.activo === true,
  };
}

async function obtenerTelefonoVentas(clubRef) {
  let telefono = "";

  try {
    const configSnap = await clubRef
        .collection("configuracion")
        .doc("general")
        .get();

    if (configSnap.exists) {
      const config = configSnap.data() || {};
      telefono =
        texto(config.telefono_ventas) ||
        texto(config.telefono_contacto);
    }
  } catch (e) {
    console.warn(
        "No se pudo leer el teléfono de ventas de configuración:",
        e,
    );
  }

  if (telefono) {
    return telefono;
  }

  try {
    const clubSnap = await clubRef.get();
    const club = clubSnap.data() || {};
    const identidad = club.identidad || {};

    telefono =
      texto(club.telefono_ventas) ||
      texto(club.telefono_contacto) ||
      texto(identidad.telefonoVentas) ||
      texto(identidad.telefonoContacto);
  } catch (e) {
    console.warn(
        "No se pudo leer el teléfono de ventas del club:",
        e,
    );
  }

  return telefono;
}

// ============================================================
// LECTURA PÚBLICA CONTROLADA
// ============================================================

exports.contenidoPublico = functions
    .region(REGION)
    .runWith({
      timeoutSeconds: 15,
      memory: "256MB",
      maxInstances: 10,
    })
    .https.onRequest(async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Cache-Control", "no-store");
      res.set("X-Content-Type-Options", "nosniff");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        responder(res, 405, {
          ok: false,
          mensaje: "Método no permitido.",
        });
        return;
      }

      let body = req.body;

      if (typeof body === "string") {
        try {
          body = JSON.parse(body);
        } catch (_) {
          body = {};
        }
      }

      const accion = texto(body?.accion);
      const clubId = clubIdSeguro(body?.clubId);

      try {
        if (accion === "noticias") {
          const clubRef = await obtenerClubHabilitado(
              clubId,
              "noticias",
          );

          if (!clubRef) {
            responder(res, 404, {
              ok: false,
              mensaje: "Noticias no está disponible para este club.",
            });
            return;
          }

          const snap = await clubRef
              .collection("noticias")
              .limit(200)
              .get();

          const noticias = snap.docs
              .filter((doc) => doc.data()?.visible !== false)
              .map(sanitizarNoticia)
              .sort((a, b) => b.fecha_ms - a.fecha_ms)
              .slice(0, 100);

          responder(res, 200, {
            ok: true,
            clubId,
            noticias,
          });
          return;
        }

        if (accion === "avisos") {
          const deporteId = texto(body?.deporteId);

          if (
            !deporteId ||
            deporteId.length > 80
          ) {
            responder(res, 400, {
              ok: false,
              mensaje: "El deporte solicitado no es válido.",
            });
            return;
          }

          const clubRef = await obtenerClubHabilitado(
              clubId,
              "avisos",
          );

          if (!clubRef) {
            responder(res, 404, {
              ok: false,
              mensaje: "Avisos no está disponible para este club.",
            });
            return;
          }

          const snap = await clubRef
              .collection("avisos")
              .limit(300)
              .get();

          const avisos = snap.docs
              .filter(
                  (doc) =>
                    texto(doc.data()?.deporte_id) === deporteId,
              )
              .map(sanitizarAviso)
              .sort((a, b) => b.fecha_ms - a.fecha_ms)
              .slice(0, 100);

          responder(res, 200, {
            ok: true,
            clubId,
            deporteId,
            avisos,
          });
          return;
        }

        if (accion === "galeria") {
          const deporteId = texto(body?.deporteId);

          if (
            !deporteId ||
            deporteId.length > 80
          ) {
            responder(res, 400, {
              ok: false,
              mensaje: "El deporte solicitado no es válido.",
            });
            return;
          }

          const clubRef = await obtenerClubHabilitado(
              clubId,
              "galeria",
          );

          if (!clubRef) {
            responder(res, 404, {
              ok: false,
              mensaje: "Galería no está disponible para este club.",
            });
            return;
          }

          const snap = await clubRef
              .collection("galeria")
              .where("deporte_id", "==", deporteId)
              .limit(500)
              .get();

          const galeria = snap.docs
              .map(sanitizarGaleria)
              .filter((foto) => foto.imagen_url)
              .sort((a, b) => b.fecha_ms - a.fecha_ms)
              .slice(0, 300);

          responder(res, 200, {
            ok: true,
            clubId,
            deporteId,
            galeria,
          });
          return;
        }

        if (accion === "productos") {
          const clubRef = await obtenerClubHabilitado(
              clubId,
              "productos",
          );

          if (!clubRef) {
            responder(res, 404, {
              ok: false,
              mensaje: "Tienda no está disponible para este club.",
            });
            return;
          }

          const snap = await clubRef
              .collection("productos")
              .limit(300)
              .get();

          const productos = snap.docs
              .filter((doc) => doc.data()?.activo === true)
              .map(sanitizarProducto)
              .filter((producto) => producto.titulo)
              .sort((a, b) =>
                a.titulo.localeCompare(b.titulo, "es"),
              )
              .slice(0, 200);

          const telefonoVentas =
            await obtenerTelefonoVentas(clubRef);

          responder(res, 200, {
            ok: true,
            clubId,
            telefono_ventas: telefonoVentas,
            productos,
          });
          return;
        }

        responder(res, 400, {
          ok: false,
          mensaje: "Acción no válida.",
        });
      } catch (e) {
        console.error("Error en contenido público TuSede:", e);

        responder(res, 500, {
          ok: false,
          mensaje:
            "No pudimos cargar el contenido en este momento. " +
            "Intentá nuevamente.",
        });
      }
    });

// ============================================================
// PUSH MULTICLUB - NOTICIAS
// ============================================================

exports.notificarNuevaNoticiaTuSede = functions
    .region(REGION)
    .firestore
    .document("clubes/{clubId}/noticias/{noticiaId}")
    .onCreate(async (snap, context) => {
      const clubId = clubIdSeguro(context.params.clubId);

      if (!CLUBES_HABILITADOS.has(clubId)) {
        console.log(
            `Push noticia omitido: club no habilitado ${clubId}`,
        );
        return null;
      }

      const data = snap.data() || {};

      if (
        data.enviar_push === false ||
        data.visible === false
      ) {
        return null;
      }

      const clubRef = await obtenerClubHabilitado(
          clubId,
          "noticias",
      );

      if (!clubRef) {
        return null;
      }

      const titulo =
        texto(data.titulo) || "Nueva Noticia";

      const cuerpo =
        texto(data.resumen) ||
        texto(data.bajada) ||
        "Leé la última novedad del club.";

      const payload = {
        notification: {
          title: `📰 ${titulo}`,
          body: cuerpo,
        },
        topic: topicGeneralClub(clubId),
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          tipo: "noticia",
          id: context.params.noticiaId,
          club_id: clubId,
        },
        android: {
          notification: {
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      };

      try {
        await getMessaging().send(payload);
        console.log(
            `Push noticia TuSede enviado a ${payload.topic}: ${titulo}`,
        );
      } catch (e) {
        console.error(
            "Error enviando push de noticia TuSede:",
            e,
        );
      }

      return null;
    });

// ============================================================
// PUSH MULTICLUB - AVISOS
// ============================================================

exports.notificarNuevoAvisoTuSede = functions
    .region(REGION)
    .firestore
    .document("clubes/{clubId}/avisos/{avisoId}")
    .onCreate(async (snap, context) => {
      const clubId = clubIdSeguro(context.params.clubId);

      if (!CLUBES_HABILITADOS.has(clubId)) {
        console.log(
            `Push aviso omitido: club no habilitado ${clubId}`,
        );
        return null;
      }

      const data = snap.data() || {};

      if (data.enviar_push === false) {
        return null;
      }

      const clubRef = await obtenerClubHabilitado(
          clubId,
          "avisos",
      );

      if (!clubRef) {
        return null;
      }

      const importante = data.importante === true;

      const tituloBase =
        texto(data.titulo) ||
        (importante ? "AVISO URGENTE" : "Nuevo Aviso");

      const titulo = importante ?
        `🚨 ${tituloBase}` :
        tituloBase;

      const cuerpo =
        texto(data.mensaje) ||
        "Tenés información nueva en el club.";

      const payload = {
        notification: {
          title: titulo,
          body: cuerpo,
        },
        topic: topicGeneralClub(clubId),
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          tipo: "aviso",
          id: context.params.avisoId,
          club_id: clubId,
        },
        android: {
          notification: {
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      };

      try {
        await getMessaging().send(payload);
        console.log(
            `Push aviso TuSede enviado a ${payload.topic}: ${titulo}`,
        );
      } catch (e) {
        console.error(
            "Error enviando push de aviso TuSede:",
            e,
        );
      }

      return null;
    });
