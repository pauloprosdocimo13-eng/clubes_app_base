const functions = require("firebase-functions/v1");
const {getApps, initializeApp} = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const crypto = require("crypto");

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();
const REGION = "southamerica-east1";

const CLUBES_HABILITADOS = new Set(["generico"]);

const VENTANA_MS = 10 * 60 * 1000;
const MAX_RESERVAS_IP = 8;

class LimiteExcedidoError extends Error {}
class HorarioOcupadoError extends Error {}

function texto(valor) {
  return String(valor ?? "").trim();
}

function clubIdSeguro(valor) {
  return texto(valor).toLowerCase();
}

function ipCliente(req) {
  const forwarded = req.headers["x-forwarded-for"];

  if (Array.isArray(forwarded) && forwarded.length > 0) {
    return String(forwarded[0]).split(",")[0].trim();
  }

  if (typeof forwarded === "string" && forwarded.trim()) {
    return forwarded.split(",")[0].trim();
  }

  return String(req.ip || req.socket?.remoteAddress || "desconocida");
}

function hash(valor) {
  return crypto.createHash("sha256").update(valor).digest("hex");
}

function numeroSeguro(valor, fallback = 0) {
  const n = Number(valor);
  return Number.isFinite(n) ? n : fallback;
}

function fechaValida(fecha) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(fecha)) {
    return false;
  }

  const [y, m, d] = fecha.split("-").map(Number);
  const objetivo = new Date(Date.UTC(y, m - 1, d, 12, 0, 0));

  if (
    objetivo.getUTCFullYear() !== y ||
    objetivo.getUTCMonth() !== m - 1 ||
    objetivo.getUTCDate() !== d
  ) {
    return false;
  }

  const ahora = new Date();
  const hoy = new Date(Date.UTC(
      ahora.getUTCFullYear(),
      ahora.getUTCMonth(),
      ahora.getUTCDate(),
      12,
      0,
      0,
  ));

  const diffDias = Math.floor(
      (objetivo.getTime() - hoy.getTime()) / (24 * 60 * 60 * 1000),
  );

  return diffDias >= -1 && diffDias <= 61;
}

function horaValida(hora) {
  const match = /^(\d{1,2}):(00|30)$/.exec(hora);
  if (!match) return false;

  const h = Number(match[1]);
  return h >= 8 && h <= 23;
}

function reservaActiva(data) {
  const estado = texto(data.estado || "confirmada");

  if (estado === "confirmada") {
    return true;
  }

  if (estado !== "pendiente") {
    return false;
  }

  const creado = data.creado_el;

  if (!creado || typeof creado.toDate !== "function") {
    return true;
  }

  const minutos =
    (Date.now() - creado.toDate().getTime()) / (60 * 1000);

  return minutos < 30;
}

function sanitizarEspacio(doc) {
  const data = doc.data() || {};

  return {
    id: doc.id,
    titulo: texto(data.titulo || "Espacio"),
    descripcion: texto(data.descripcion),
    precio: texto(data.precio),
    foto_url: texto(data.foto_url),
  };
}

async function validarClub(clubId) {
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

  const data = snap.data() || {};
  const modulos = data.modulos || {};

  if (modulos.espacios === false || modulos.reservas === false) {
    return null;
  }

  return ref;
}

async function consumirLimiteReserva(req, clubId) {
  const bucket = Math.floor(Date.now() / VENTANA_MS);
  const ipHash = hash(ipCliente(req));
  const docId = hash(
      `reservas|ip:${ipHash}|club:${clubId}|b:${bucket}`,
  );

  const ref = db
      .collection("_seguridad_reservas_publicas")
      .doc(docId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const intentos = snap.exists ?
      numeroSeguro(snap.data()?.intentos, 0) :
      0;

    if (intentos >= MAX_RESERVAS_IP) {
      throw new LimiteExcedidoError();
    }

    tx.set(
        ref,
        {
          intentos: intentos + 1,
          club_id: clubId,
          tipo: "reserva_publica",
          expira_en: Timestamp.fromMillis(
              (bucket + 2) * VENTANA_MS,
          ),
          actualizado_en: FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  });
}

function responder(res, status, payload) {
  res.status(status).json(payload);
}

exports.reservasPublicas = functions
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
        const clubRef = await validarClub(clubId);

        if (!clubRef) {
          responder(res, 404, {
            ok: false,
            mensaje: "Reservas no está disponible para este club.",
          });
          return;
        }

        if (accion === "listar") {
          const [espaciosSnap, configSnap] = await Promise.all([
            clubRef.collection("espacios").get(),
            clubRef.collection("configuracion").doc("reservas").get(),
          ]);

          const espacios = [];

          for (const doc of espaciosSnap.docs) {
            const data = doc.data() || {};
            if (data.activo === false) continue;
            espacios.push(sanitizarEspacio(doc));
          }

          espacios.sort((a, b) =>
            a.titulo.localeCompare(b.titulo, "es"),
          );

          responder(res, 200, {
            ok: true,
            clubId,
            telefono_wsp: texto(
                configSnap.exists ?
                  configSnap.data()?.telefono_wsp :
                  "",
            ),
            espacios,
          });
          return;
        }

        if (accion === "disponibilidad") {
          const espacioId = texto(body?.espacioId);
          const fecha = texto(body?.fecha);

          if (!espacioId || !fechaValida(fecha)) {
            responder(res, 400, {
              ok: false,
              mensaje: "Solicitud de disponibilidad inválida.",
            });
            return;
          }

          const espacio = await clubRef
              .collection("espacios")
              .doc(espacioId)
              .get();

          if (!espacio.exists || espacio.data()?.activo === false) {
            responder(res, 404, {
              ok: false,
              mensaje: "El espacio no existe.",
            });
            return;
          }

          const reservas = await clubRef
              .collection("reservas")
              .where("espacio_id", "==", espacioId)
              .where("fecha", "==", fecha)
              .get();

          const horarios = {};

          for (const doc of reservas.docs) {
            const data = doc.data() || {};
            const hora = texto(data.hora);

            if (!hora || !reservaActiva(data)) {
              continue;
            }

            const estado = texto(data.estado || "confirmada");

            if (estado === "confirmada") {
              horarios[hora] = "confirmada";
            } else if (
              estado === "pendiente" &&
              horarios[hora] !== "confirmada"
            ) {
              horarios[hora] = "pendiente";
            }
          }

          responder(res, 200, {
            ok: true,
            clubId,
            horarios,
          });
          return;
        }

        if (accion === "reservar") {
          const espacioId = texto(body?.espacioId);
          const espacioNombre = texto(body?.espacioNombre);
          const fecha = texto(body?.fecha);
          const hora = texto(body?.hora);

          if (
            !espacioId ||
            !fechaValida(fecha) ||
            !horaValida(hora)
          ) {
            responder(res, 400, {
              ok: false,
              mensaje: "Los datos de la reserva no son válidos.",
            });
            return;
          }

          try {
            await consumirLimiteReserva(req, clubId);
          } catch (e) {
            if (e instanceof LimiteExcedidoError) {
              responder(res, 429, {
                ok: false,
                mensaje:
                  "Se realizaron demasiados intentos de reserva. " +
                  "Esperá unos minutos y volvé a probar.",
              });
              return;
            }

            throw e;
          }

          const espacioRef = clubRef
              .collection("espacios")
              .doc(espacioId);

          const espacioSnap = await espacioRef.get();

          if (
            !espacioSnap.exists ||
            espacioSnap.data()?.activo === false
          ) {
            responder(res, 404, {
              ok: false,
              mensaje: "El espacio no existe.",
            });
            return;
          }

          const existentes = await clubRef
              .collection("reservas")
              .where("espacio_id", "==", espacioId)
              .where("fecha", "==", fecha)
              .where("hora", "==", hora)
              .get();

          for (const doc of existentes.docs) {
            if (reservaActiva(doc.data() || {})) {
              responder(res, 409, {
                ok: false,
                mensaje:
                  "¡Uy! Alguien acaba de reservar este horario.",
              });
              return;
            }
          }

          const slotId =
            "pub_" +
            hash(`${clubId}|${espacioId}|${fecha}|${hora}`)
                .slice(0, 40);

          const slotRef = clubRef
              .collection("reservas")
              .doc(slotId);

          try {
            await db.runTransaction(async (tx) => {
              const slotSnap = await tx.get(slotRef);

              if (
                slotSnap.exists &&
                reservaActiva(slotSnap.data() || {})
              ) {
                throw new HorarioOcupadoError();
              }

              tx.set(
                  slotRef,
                  {
                    espacio_id: espacioId,
                    espacio_nombre:
                      espacioNombre ||
                      texto(espacioSnap.data()?.titulo || "Espacio"),
                    fecha,
                    hora,
                    estado: "pendiente",
                    creado_el: FieldValue.serverTimestamp(),
                    origen: "portal_publico",
                    club_id: clubId,
                  },
                  {merge: false},
              );
            });
          } catch (e) {
            if (e instanceof HorarioOcupadoError) {
              responder(res, 409, {
                ok: false,
                mensaje:
                  "¡Uy! Alguien acaba de reservar este horario.",
              });
              return;
            }

            throw e;
          }

          responder(res, 200, {
            ok: true,
            clubId,
            reservaId: slotId,
            estado: "pendiente",
          });
          return;
        }

        responder(res, 400, {
          ok: false,
          mensaje: "Acción no válida.",
        });
      } catch (e) {
        console.error("Error en reservas públicas:", e);

        responder(res, 500, {
          ok: false,
          mensaje:
            "No pudimos procesar Reservas en este momento. " +
            "Intentá nuevamente.",
        });
      }
    });
