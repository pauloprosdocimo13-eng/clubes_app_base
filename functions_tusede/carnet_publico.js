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

// MIGRACIÓN SEGURA:
// por ahora SOLO Horizonte/generico puede usar este portal central.
// Güemes sigue completamente en Legacy.
const CLUBES_HABILITADOS = new Set(["generico"]);

// Límites anti-fuerza-bruta.
// No convierten un DNI en una credencial fuerte, pero evitan dejar
// el padrón expuesto directamente y frenan enumeraciones simples.
const VENTANA_MS = 10 * 60 * 1000;
const MAX_INTENTOS_IP_CLUB = 20;
const MAX_INTENTOS_IP_DNI = 6;

class LimiteExcedidoError extends Error {}

function normalizarDni(valor) {
  return String(valor ?? "").replace(/\D/g, "");
}

function normalizarClubId(valor) {
  return String(valor ?? "").trim().toLowerCase();
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

function hashInterno(valor) {
  return crypto.createHash("sha256").update(valor).digest("hex");
}

function numeroSeguro(valor, fallback = 0) {
  const n = Number(valor);
  return Number.isFinite(n) ? n : fallback;
}

function texto(valor) {
  return String(valor ?? "").trim();
}

function listaTexto(valor) {
  if (!Array.isArray(valor)) {
    return [];
  }

  return valor
      .map((item) => String(item ?? "").trim())
      .filter((item) => item.length > 0);
}

function sanitizarSocio(data, docId, dniConsultado, esPrincipal = false) {
  const dniOriginal = texto(data.dni);

  let dniVisible = dniOriginal;

  // En familiares no principales evitamos exponer el DNI completo.
  if (!esPrincipal && dniOriginal.length >= 4) {
    dniVisible =
      `${"*".repeat(Math.max(0, dniOriginal.length - 4))}` +
      `${dniOriginal.slice(-4)}`;
  }

  return {
    _doc_id: docId,
    nombre: texto(data.nombre),
    apellido: texto(data.apellido),
    dni: esPrincipal ? dniConsultado : dniVisible,
    nro_socio: texto(data.nro_socio),
    foto_url: texto(data.foto_url),
    apto_fisico: data.apto_fisico === true,
    actividades: listaTexto(data.actividades),
    actividad: texto(data.actividad),
    categoria_deporte: texto(data.categoria_deporte),
    porcentaje_descuento: numeroSeguro(data.porcentaje_descuento, 0),
    ultimo_mes_pago: texto(data.ultimo_mes_pago),
    al_dia: data.al_dia === true,
    familia_id: texto(data.familia_id || docId),
  };
}

function sanitizarPrecios(data) {
  const raw = data?.precios_cuotas;

  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return {};
  }

  const resultado = {};

  for (const [clave, valor] of Object.entries(raw)) {
    const n = Number(valor);
    if (Number.isFinite(n) && n >= 0) {
      resultado[String(clave)] = n;
    }
  }

  return resultado;
}

function sanitizarPagos(dataPagos, dataContacto) {
  const pagos = dataPagos || {};
  const contacto = dataContacto || {};

  let telefono =
    texto(pagos.telefono_wsp) ||
    texto(pagos.telefono_whatsapp) ||
    texto(pagos.whatsapp) ||
    texto(contacto.whatsapp) ||
    texto(contacto.telefono_wsp) ||
    texto(contacto.telefono_whatsapp) ||
    texto(contacto.telefono);

  if (!telefono && Array.isArray(contacto.contactos)) {
    for (const item of contacto.contactos) {
      if (!item || typeof item !== "object") continue;

      const tipo = texto(item.tipo || item.nombre).toLowerCase();

      if (tipo.includes("whatsapp") || tipo.includes("tel")) {
        telefono =
          texto(item.valor) ||
          texto(item.telefono) ||
          texto(item.numero);

        if (telefono) break;
      }
    }
  }

  return {
    alias_cbu: texto(pagos.alias_cbu),
    link_mp: texto(pagos.link_mp),
    telefono_wsp: telefono,
  };
}

async function consumirLimite(req, clubId, dni) {
  const ahora = Date.now();
  const bucket = Math.floor(ahora / VENTANA_MS);
  const ipHash = hashInterno(ipCliente(req));

  const idIpClub = hashInterno(
      `ip:${ipHash}|club:${clubId}|b:${bucket}`,
  );
  const idIpDni = hashInterno(
      `ip:${ipHash}|club:${clubId}|dni:${dni}|b:${bucket}`,
  );

  const refIpClub = db
      .collection("_seguridad_carnet_publico")
      .doc(idIpClub);

  const refIpDni = db
      .collection("_seguridad_carnet_publico")
      .doc(idIpDni);

  await db.runTransaction(async (tx) => {
    const snapIpClub = await tx.get(refIpClub);
    const snapIpDni = await tx.get(refIpDni);

    const intentosIpClub = snapIpClub.exists ?
      numeroSeguro(snapIpClub.data()?.intentos, 0) :
      0;

    const intentosIpDni = snapIpDni.exists ?
      numeroSeguro(snapIpDni.data()?.intentos, 0) :
      0;

    if (
      intentosIpClub >= MAX_INTENTOS_IP_CLUB ||
      intentosIpDni >= MAX_INTENTOS_IP_DNI
    ) {
      throw new LimiteExcedidoError();
    }

    const expira = Timestamp.fromMillis(
        (bucket + 2) * VENTANA_MS,
    );

    tx.set(
        refIpClub,
        {
          intentos: intentosIpClub + 1,
          club_id: clubId,
          tipo: "ip_club",
          expira_en: expira,
          actualizado_en: FieldValue.serverTimestamp(),
        },
        {merge: true},
    );

    tx.set(
        refIpDni,
        {
          intentos: intentosIpDni + 1,
          club_id: clubId,
          tipo: "ip_dni",
          expira_en: expira,
          actualizado_en: FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  });
}

function responderJson(res, status, payload) {
  res.status(status).json(payload);
}

function esperar(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

exports.buscarCarnetPublico = functions
    .region(REGION)
    .runWith({
      timeoutSeconds: 15,
      memory: "256MB",
      maxInstances: 10,
    })
    .https.onRequest(async (req, res) => {
      // Endpoint público: CORS necesario para Flutter Web.
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
        responderJson(res, 405, {
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

      const clubId = normalizarClubId(body?.clubId);
      const dni = normalizarDni(body?.dni);

      if (!/^[a-z0-9_-]{2,40}$/.test(clubId)) {
        responderJson(res, 400, {
          ok: false,
          mensaje: "Solicitud inválida.",
        });
        return;
      }

      if (dni.length < 6 || dni.length > 12) {
        responderJson(res, 400, {
          ok: false,
          mensaje: "Ingresá un DNI válido.",
        });
        return;
      }

      // Seguridad de migración: todavía NO habilitamos Güemes.
      if (!CLUBES_HABILITADOS.has(clubId)) {
        responderJson(res, 404, {
          ok: false,
          mensaje: "No encontramos un socio con esos datos.",
        });
        return;
      }

      try {
        await consumirLimite(req, clubId, dni);
      } catch (e) {
        if (e instanceof LimiteExcedidoError) {
          responderJson(res, 429, {
            ok: false,
            mensaje:
              "Se realizaron demasiados intentos. " +
              "Esperá unos minutos y volvé a probar.",
          });
          return;
        }

        console.error("Error aplicando límite del carnet:", e);
        responderJson(res, 503, {
          ok: false,
          mensaje:
            "El portal está temporalmente ocupado. " +
            "Intentá nuevamente en unos minutos.",
        });
        return;
      }

      try {
        const clubRef = db.collection("clubes").doc(clubId);
        const clubSnap = await clubRef.get();

        if (!clubSnap.exists || clubSnap.data()?.activo !== true) {
          await esperar(250);
          responderJson(res, 404, {
            ok: false,
            mensaje: "No encontramos un socio con esos datos.",
          });
          return;
        }

        const clubData = clubSnap.data() || {};
        const modulos = clubData.modulos || {};

        if (modulos.socios === false) {
          responderJson(res, 404, {
            ok: false,
            mensaje: "No encontramos un socio con esos datos.",
          });
          return;
        }

        const querySocio = await clubRef
            .collection("socios")
            .where("dni", "==", dni)
            .limit(5)
            .get();

        let socioDoc = null;

        for (const doc of querySocio.docs) {
          const data = doc.data() || {};

          if (data.eliminado === true) {
            continue;
          }

          socioDoc = doc;
          break;
        }

        if (!socioDoc) {
          await esperar(250);
          responderJson(res, 404, {
            ok: false,
            mensaje: "No encontramos un socio con esos datos.",
          });
          return;
        }

        const socioData = socioDoc.data() || {};
        const familiaId = texto(
            socioData.familia_id || socioDoc.id,
        );

        const [
          familiaSnap,
          preciosSnap,
          pagosSnap,
          contactoSnap,
        ] = await Promise.all([
          clubRef
              .collection("socios")
              .where("familia_id", "==", familiaId)
              .get(),
          clubRef.collection("configuracion").doc("precios").get(),
          clubRef.collection("configuracion").doc("pagos").get(),
          clubRef.collection("configuracion").doc("contacto").get(),
        ]);

        const familia = [];

        for (const doc of familiaSnap.docs) {
          const data = doc.data() || {};

          if (data.eliminado === true) {
            continue;
          }

          familia.push(
              sanitizarSocio(
                  data,
                  doc.id,
                  dni,
                  doc.id === socioDoc.id,
              ),
          );
        }

        // Fallback si un socio viejo no tiene familia_id coherente.
        if (!familia.some((item) => item._doc_id === socioDoc.id)) {
          familia.unshift(
              sanitizarSocio(
                  socioData,
                  socioDoc.id,
                  dni,
                  true,
              ),
          );
        }

        const socio = sanitizarSocio(
            socioData,
            socioDoc.id,
            dni,
            true,
        );

        const precios = sanitizarPrecios(
            preciosSnap.exists ? preciosSnap.data() : {},
        );

        const pagos = sanitizarPagos(
            pagosSnap.exists ? pagosSnap.data() : {},
            contactoSnap.exists ? contactoSnap.data() : {},
        );

        responderJson(res, 200, {
          ok: true,
          clubId,
          socioId: socioDoc.id,
          socio,
          familia,
          precios,
          pagos,
          seguridad: {
            datosSensiblesOmitidos: true,
            accesoDirectoFirestore: false,
          },
        });
      } catch (e) {
        console.error("Error buscando carnet público:", e);

        responderJson(res, 500, {
          ok: false,
          mensaje:
            "No pudimos cargar el carnet en este momento. " +
            "Intentá nuevamente.",
        });
      }
    });
