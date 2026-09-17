const functions = require("firebase-functions/v1");
const {getApps, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const crypto = require("crypto");

if (getApps().length === 0) {
  initializeApp();
}

const REGION = "southamerica-east1";
const BUCKET_NAME = "tu-sede-app.firebasestorage.app";

const db = getFirestore();

const CLUBES_HABILITADOS = new Set([
  "generico",
]);

const CARPETAS_HABILITADAS = new Set([
  "noticias",
  "galeria",
  "socios",
  "socios_hijos",
  "jugadores",
  "espacios",
  "productos",
  "actividades",
  "logos",
  "publicidad",
]);

const MAX_BYTES = 4 * 1024 * 1024;

function texto(valor) {
  return String(valor ?? "").trim();
}

function limpiarId(valor) {
  return texto(valor)
      .toLowerCase()
      .replace(/[^a-z0-9_-]/g, "_");
}

function extensionSegura(valor) {
  const ext = limpiarId(valor);

  if (ext === "jpg" || ext === "jpeg") {
    return {
      extension: "jpg",
      contentType: "image/jpeg",
    };
  }

  if (ext === "png") {
    return {
      extension: "png",
      contentType: "image/png",
    };
  }

  if (ext === "webp") {
    return {
      extension: "webp",
      contentType: "image/webp",
    };
  }

  return null;
}

function responder(res, status, payload) {
  res.status(status).json(payload);
}

function configurarCors(req, res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set(
      "Access-Control-Allow-Headers",
      "Content-Type, Authorization",
  );
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Cache-Control", "no-store");
  res.set("X-Content-Type-Options", "nosniff");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return true;
  }

  return false;
}

function tokenBearer(req) {
  const header = texto(req.headers.authorization);

  if (!header.toLowerCase().startsWith("bearer ")) {
    return "";
  }

  return header.substring(7).trim();
}

async function autorizarAdministrador(req, clubId) {
  const token = tokenBearer(req);

  if (!token) {
    return null;
  }

  let decoded;

  try {
    decoded = await getAuth().verifyIdToken(token);
  } catch (_) {
    return null;
  }

  const uid = texto(decoded.uid);

  if (!uid) {
    return null;
  }

  const usuarioSnap = await db
      .collection("usuarios")
      .doc(uid)
      .get();

  if (!usuarioSnap.exists || !usuarioSnap.data()) {
    return null;
  }

  const usuario = usuarioSnap.data();

  if (usuario.activo !== true) {
    return null;
  }

  const rol = texto(usuario.rol).toLowerCase();

  if (rol === "superadmin") {
    return {
      uid,
      rol,
    };
  }

  if (rol !== "admin") {
    return null;
  }

  const clubIds = Array.isArray(usuario.clubIds) ?
    usuario.clubIds.map((item) => limpiarId(item)) :
    [];

  if (!clubIds.includes(clubId)) {
    return null;
  }

  return {
    uid,
    rol,
  };
}

async function validarClub(clubId) {
  if (!CLUBES_HABILITADOS.has(clubId)) {
    return false;
  }

  const snap = await db
      .collection("clubes")
      .doc(clubId)
      .get();

  return snap.exists && snap.data()?.activo === true;
}

exports.subirImagenTuSede = functions
    .region(REGION)
    .runWith({
      timeoutSeconds: 30,
      memory: "256MB",
      maxInstances: 10,
    })
    .https.onRequest(async (req, res) => {
      if (configurarCors(req, res)) {
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

      const clubId = limpiarId(body?.clubId);
      const carpeta = limpiarId(body?.carpeta);
      const imagenBase64 = texto(body?.imagenBase64);
      const nombreBase = limpiarId(body?.nombreBase);

      const tipo = extensionSegura(body?.extension);

      try {
        if (!clubId || !CLUBES_HABILITADOS.has(clubId)) {
          responder(res, 404, {
            ok: false,
            mensaje:
              "La carga de imágenes no está habilitada para este club.",
          });
          return;
        }

        if (!CARPETAS_HABILITADAS.has(carpeta)) {
          responder(res, 400, {
            ok: false,
            mensaje: "La carpeta solicitada no está habilitada.",
          });
          return;
        }

        if (!tipo) {
          responder(res, 400, {
            ok: false,
            mensaje: "El formato de imagen no está permitido.",
          });
          return;
        }

        if (!imagenBase64) {
          responder(res, 400, {
            ok: false,
            mensaje: "No se recibió ninguna imagen.",
          });
          return;
        }

        if (!(await validarClub(clubId))) {
          responder(res, 404, {
            ok: false,
            mensaje: "El club no está disponible.",
          });
          return;
        }

        const autorizado =
          await autorizarAdministrador(req, clubId);

        if (!autorizado) {
          responder(res, 403, {
            ok: false,
            mensaje:
              "La sesión no tiene permiso para subir imágenes.",
          });
          return;
        }

        let buffer;

        try {
          buffer = Buffer.from(imagenBase64, "base64");
        } catch (_) {
          responder(res, 400, {
            ok: false,
            mensaje: "La imagen recibida no es válida.",
          });
          return;
        }

        if (!buffer.length) {
          responder(res, 400, {
            ok: false,
            mensaje: "La imagen recibida está vacía.",
          });
          return;
        }

        if (buffer.length > MAX_BYTES) {
          responder(res, 413, {
            ok: false,
            mensaje:
              "La imagen supera el máximo permitido de 4 MB.",
          });
          return;
        }

        const tokenDescarga = crypto.randomUUID();
        const sufijo = crypto
            .randomBytes(6)
            .toString("hex");

        const nombre =
          nombreBase ?
            `${nombreBase}_${Date.now()}_${sufijo}.${tipo.extension}` :
            `${Date.now()}_${sufijo}.${tipo.extension}`;

        const ruta =
          `clubes/${clubId}/${carpeta}/${nombre}`;

        const bucket = getStorage().bucket(BUCKET_NAME);
        const archivo = bucket.file(ruta);

        await archivo.save(
            buffer,
            {
              resumable: false,
              metadata: {
                contentType: tipo.contentType,
                cacheControl:
                  "public,max-age=31536000,immutable",
                metadata: {
                  firebaseStorageDownloadTokens:
                    tokenDescarga,
                  clubId,
                  carpeta,
                  subidoPorUid: autorizado.uid,
                },
              },
            },
        );

        const rutaCodificada =
          encodeURIComponent(ruta);

        const url =
          `https://firebasestorage.googleapis.com/v0/b/` +
          `${bucket.name}/o/${rutaCodificada}` +
          `?alt=media&token=${tokenDescarga}`;

        responder(res, 200, {
          ok: true,
          clubId,
          carpeta,
          ruta,
          url,
        });
      } catch (e) {
        console.error(
            "Error subiendo imagen TuSede:",
            e,
        );

        responder(res, 500, {
          ok: false,
          mensaje:
            "No se pudo subir la imagen en este momento.",
        });
      }
    });
