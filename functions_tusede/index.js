const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");

const {
  initializeApp,
  applicationDefault,
} = require("firebase-admin/app");

const {
  getAuth,
} = require("firebase-admin/auth");

const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

// ============================================================
// TUSEDE CENTRAL
// ============================================================
//
// Esta función se despliega SIEMPRE en:
// tu-sede-app
//
// En Cloud Functions usamos las credenciales automáticas
// del entorno de Google.

const tusedeApp = initializeApp();

const tusedeAuth = getAuth(tusedeApp);
const tusedeDb = getFirestore(tusedeApp);

// ============================================================
// FIREBASE LEGACY DE GÜEMES
// ============================================================
//
// Esta instancia se utiliza únicamente para verificar
// que el token recibido pertenece realmente al proyecto
// antiguo de Güemes.
//
// NO escribimos nada en el Firebase Legacy.

const guemesLegacyApp = initializeApp(
  {
    credential: applicationDefault(),
    projectId: "club-guemes-2",
  },
  "guemes-legacy"
);

const guemesLegacyAuth =
    getAuth(guemesLegacyApp);

// ============================================================
// CONFIGURACIÓN DE CLUBES LEGACY
// ============================================================
//
// Hoy solamente existe Güemes.
//
// Más adelante agregaremos otros clubes durante sus
// respectivas migraciones.

const CLUBES_LEGACY = {
  guemes: {
    projectId: "club-guemes-2",
  },
};

// ============================================================
// RESPUESTAS
// ============================================================

function responderError(
  res,
  status,
  codigo,
  mensaje
) {
  return res.status(status).json({
    ok: false,
    codigo,
    mensaje,
  });
}

// ============================================================
// FUNCIÓN PRINCIPAL
// ============================================================

exports.vincularSesionLegacy = onRequest(
  {
    region: "southamerica-east1",

    // Necesitamos Web + Android.
    //
    // El endpoint NO queda desprotegido:
    // igualmente exigimos y verificamos el ID Token
    // real de Firebase Güemes.
    cors: true,

    timeoutSeconds: 30,

    memory: "256MiB",

    maxInstances: 5,
  },

  async (req, res) => {
    // ========================================================
    // 1. SOLO POST
    // ========================================================

    if (req.method !== "POST") {
      return responderError(
        res,
        405,
        "METODO_NO_PERMITIDO",
        "Solo se permite POST."
      );
    }

    // ========================================================
    // 2. CLUB
    // ========================================================

    const clubId =
        String(req.body?.clubId || "")
            .trim()
            .toLowerCase();

    if (!clubId) {
      return responderError(
        res,
        400,
        "CLUB_REQUERIDO",
        "No se recibió el clubId."
      );
    }

    const configLegacy =
        CLUBES_LEGACY[clubId];

    if (!configLegacy) {
      return responderError(
        res,
        400,
        "CLUB_NO_SOPORTADO",
        "Este club todavía no tiene migración Legacy configurada."
      );
    }

    // ========================================================
    // 3. TOKEN LEGACY
    // ========================================================

    const authorization =
        req.get("Authorization") || "";

    if (!authorization.startsWith("Bearer ")) {
      return responderError(
        res,
        401,
        "TOKEN_FALTANTE",
        "No se recibió una sesión Legacy válida."
      );
    }

    const legacyToken =
        authorization.substring(7).trim();

    if (!legacyToken) {
      return responderError(
        res,
        401,
        "TOKEN_VACIO",
        "El token Legacy está vacío."
      );
    }

    // ========================================================
    // 4. VERIFICAR TOKEN CONTRA FIREBASE GÜEMES
    // ========================================================

    let decodedToken;

    try {
      decodedToken =
          await guemesLegacyAuth
              .verifyIdToken(legacyToken);
    } catch (error) {
      logger.warn(
        "Token Legacy rechazado",
        {
          error: error?.message,
        }
      );

      return responderError(
        res,
        401,
        "TOKEN_LEGACY_INVALIDO",
        "La sesión de Güemes no es válida."
      );
    }

    // ========================================================
    // 5. IDENTIDAD
    // ========================================================

    const uidLegacy =
        String(decodedToken.uid || "")
            .trim();

    const email =
        String(decodedToken.email || "")
            .trim()
            .toLowerCase();

    if (!uidLegacy || !email) {
      return responderError(
        res,
        403,
        "IDENTIDAD_INCOMPLETA",
        "La sesión Legacy no contiene UID y email."
      );
    }

    // ========================================================
    // 6. AUTORIZACIÓN DE MIGRACIÓN TUSEDE
    // ========================================================

    const migrationId =
        encodeURIComponent(email);

    const migrationRef =
        tusedeDb
            .collection("migraciones_admin")
            .doc(clubId)
            .collection("usuarios")
            .doc(migrationId);

    const migrationSnap =
        await migrationRef.get();

    if (!migrationSnap.exists) {
      return responderError(
        res,
        403,
        "MIGRACION_NO_PREPARADA",
        "Este administrador todavía no tiene una migración preparada."
      );
    }

    const migration =
        migrationSnap.data() || {};

    const migrationEmail =
        String(migration.email || "")
            .trim()
            .toLowerCase();

    const migrationClub =
        String(migration.clubId || "")
            .trim()
            .toLowerCase();

    const rolLegacy =
        String(migration.rolLegacy || "")
            .trim()
            .toLowerCase();

    const rolTuSede =
        String(migration.rolTuSede || "")
            .trim()
            .toLowerCase();

    const estado =
        String(migration.estado || "")
            .trim()
            .toLowerCase();

    const autorizado =
        migration.autorizado === true;

    if (
      migrationEmail !== email ||
      migrationClub !== clubId ||
      !autorizado
    ) {
      return responderError(
        res,
        403,
        "MIGRACION_INVALIDA",
        "La autorización de migración no coincide con esta sesión."
      );
    }

    // Permitimos repetir la operación.
    //
    // Esto hace que la función sea idempotente.
    if (
      estado !== "preparado" &&
      estado !== "vinculado"
    ) {
      return responderError(
        res,
        403,
        "ESTADO_MIGRACION_INVALIDO",
        `La migración está en estado "${estado}".`
      );
    }

    if (!rolLegacy || !rolTuSede) {
      return responderError(
        res,
        403,
        "ROL_INCOMPLETO",
        "La migración no tiene roles correctamente definidos."
      );
    }

    // ========================================================
    // 7. VALIDAR CATÁLOGO CENTRAL DE ROLES
    // ========================================================

    const rolRef =
        tusedeDb
            .collection("roles")
            .doc(rolTuSede);

    const rolSnap =
        await rolRef.get();

    if (!rolSnap.exists) {
      return responderError(
        res,
        403,
        "ROL_NO_EXISTE",
        `El rol "${rolTuSede}" no existe en TuSede.`
      );
    }

    const rolData =
        rolSnap.data() || {};

    const rolActivo =
        rolData.activo === true;

    const alcance =
        String(rolData.alcance || "")
            .trim()
            .toLowerCase();

    const equivalente =
        String(
          rolData.legacyEquivalente || ""
        )
            .trim()
            .toLowerCase();

    if (
      !rolActivo ||
      alcance !== "club" ||
      equivalente !== rolLegacy
    ) {
      return responderError(
        res,
        403,
        "ROL_NO_COMPATIBLE",
        "El rol central no coincide con el rol Legacy autorizado."
      );
    }

    // ========================================================
    // 8. CONFIRMAR QUE LA CUENTA YA EXISTE EN AUTH TUSEDE
    // ========================================================
    //
    // Las cuentas fueron importadas durante 3F-2.
    //
    // Esta función NO crea cuentas Authentication nuevas.

    let usuarioDestino;

    try {
      usuarioDestino =
          await tusedeAuth
              .getUserByEmail(email);
    } catch (error) {
      logger.warn(
        "Usuario no encontrado en Authentication TuSede",
        {
          email,
          error: error?.message,
        }
      );

      return responderError(
        res,
        403,
        "AUTH_TUSEDE_NO_EXISTE",
        "La cuenta todavía no fue importada a Authentication TuSede."
      );
    }

    if (usuarioDestino.disabled) {
      return responderError(
        res,
        403,
        "USUARIO_DESACTIVADO",
        "La cuenta TuSede se encuentra desactivada."
      );
    }

    // ========================================================
    // 9. VERIFICAR UID
    // ========================================================
    //
    // Nuestra migración conservó los UID de Firebase Güemes.
    //
    // Si no coinciden, frenamos para evitar vincular
    // dos identidades diferentes con el mismo email.

    if (usuarioDestino.uid !== uidLegacy) {
      logger.error(
        "Conflicto de UID durante migración",
        {
          email,
          uidLegacy,
          uidTuSede: usuarioDestino.uid,
        }
      );

      return responderError(
        res,
        409,
        "CONFLICTO_UID",
        "El UID de Güemes no coincide con el UID importado en TuSede."
      );
    }

    // ========================================================
    // 10. CREAR / VALIDAR PERFIL CENTRAL
    // ========================================================

    const perfilRef =
        tusedeDb
            .collection("usuarios")
            .doc(usuarioDestino.uid);

    const perfilSnap =
        await perfilRef.get();

    const nombrePreparado =
        String(migration.nombre || "")
            .trim();

    const nombre =
        nombrePreparado || email;

    const perfilEsperado = {
      nombre,
      email,
      rol: rolTuSede,
      clubPrincipal: clubId,
      clubIds: [clubId],
      activo: true,
    };

    if (!perfilSnap.exists) {
      await perfilRef.set(
        perfilEsperado
      );

      logger.info(
        "Perfil TuSede creado desde sesión Legacy",
        {
          email,
          clubId,
          rol: rolTuSede,
        }
      );
    } else {
      const perfil =
          perfilSnap.data() || {};

      const perfilEmail =
          String(perfil.email || "")
              .trim()
              .toLowerCase();

      const perfilRol =
          String(perfil.rol || "")
              .trim()
              .toLowerCase();

      const perfilClub =
          String(perfil.clubPrincipal || "")
              .trim()
              .toLowerCase();

      const perfilClubIds =
          Array.isArray(perfil.clubIds)
              ? perfil.clubIds.map(
                  (item) =>
                    String(item)
                      .trim()
                      .toLowerCase()
                )
              : [];

      if (
        perfilEmail !== email ||
        perfilRol !== rolTuSede ||
        perfil.activo !== true ||
        (
          perfilClub !== clubId &&
          !perfilClubIds.includes(clubId)
        )
      ) {
        logger.error(
          "Perfil TuSede existente incompatible",
          {
            email,
            perfilRol,
            rolEsperado: rolTuSede,
            perfilClub,
            clubEsperado: clubId,
          }
        );

        return responderError(
          res,
          409,
          "PERFIL_INCOMPATIBLE",
          "El perfil TuSede existente no coincide con la migración autorizada."
        );
      }
    }

    // ========================================================
    // 11. MARCAR MIGRACIÓN COMO VINCULADA
    // ========================================================

    await migrationRef.set(
      {
        estado: "vinculado",
        vinculado: true,
        uidLegacy,
        uidTuSede: usuarioDestino.uid,
        fechaVinculacion:
            FieldValue.serverTimestamp(),
        actualizadoEl:
            FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      }
    );

    // ========================================================
    // 12. CREAR CUSTOM TOKEN TUSEDE
    // ========================================================
    //
    // El cliente usará este token para abrir una sesión
    // Firebase Auth en TuSede sin solicitar otra vez
    // usuario y contraseña.

    const customToken =
        await tusedeAuth.createCustomToken(
          usuarioDestino.uid,
          {
            clubId,
            origen: "legacy_bridge",
          }
        );

    logger.info(
      "Vinculación Legacy -> TuSede correcta",
      {
        email,
        clubId,
        rol: rolTuSede,
      }
    );

    // ========================================================
    // 13. RESPUESTA
    // ========================================================

    return res.status(200).json({
      ok: true,

      customToken,

      usuario: {
        uid: usuarioDestino.uid,
        nombre,
        email,
        rol: rolTuSede,
        clubPrincipal: clubId,
        clubIds: [clubId],
        activo: true,
      },
    });
  }
);