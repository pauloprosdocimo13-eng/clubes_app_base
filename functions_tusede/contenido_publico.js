const functions = require("firebase-functions/v1");
const {getApps, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

const REGION = "southamerica-east1";

// ============================================================
// CLUBES HABILITADOS EN TUSEDE CENTRAL
// ============================================================
//
// "generico" es el identificador técnico del club de prueba
// que actualmente se muestra como Club Horizonte.
//
// Güemes continúa utilizando Firebase Legacy y NO se sirve
// desde este backend central todavía.
// ============================================================

const CLUBES_HABILITADOS = new Set([
  "generico",
]);

// ============================================================
// UTILIDADES
// ============================================================

function texto(valor) {
  return String(valor ?? "").trim();
}

function clubIdSeguro(valor) {
  return texto(valor).toLowerCase();
}

function topicGeneralClub(clubId) {
  const seguro = clubId.replace(
      /[^a-z0-9_-]/g,
      "_",
  );

  return `tusede_${seguro}_general`;
}

function fechaMillis(valor) {
  if (
    valor &&
    typeof valor.toMillis === "function"
  ) {
    return valor.toMillis();
  }

  return 0;
}

function numeroSeguro(
    valor,
    defecto = 0,
) {
  const numero = Number(valor);

  if (!Number.isFinite(numero)) {
    return defecto;
  }

  return numero;
}

function enteroSeguro(
    valor,
    defecto = 0,
) {
  const numero = Number(valor);

  if (!Number.isFinite(numero)) {
    return defecto;
  }

  return Math.trunc(numero);
}

function responder(
    res,
    status,
    payload,
) {
  res.status(status).json(payload);
}

// ============================================================
// CLUB
// ============================================================

async function obtenerClubHabilitado(
    clubId,
    modulo,
) {
  if (
    !/^[a-z0-9_-]{2,40}$/.test(
        clubId,
    )
  ) {
    return null;
  }

  if (
    !CLUBES_HABILITADOS.has(
        clubId,
    )
  ) {
    return null;
  }

  const ref = db
      .collection("clubes")
      .doc(clubId);

  const snap = await ref.get();

  if (
    !snap.exists ||
    snap.data()?.activo !== true
  ) {
    return null;
  }

  const modulos =
    snap.data()?.modulos || {};

  if (
    modulo &&
    modulos[modulo] === false
  ) {
    return null;
  }

  return ref;
}

// ============================================================
// SANITIZACIÓN GENERAL
// ============================================================

function listaTexto(valor) {
  if (!Array.isArray(valor)) {
    return [];
  }

  return valor
      .map((item) => texto(item))
      .filter((item) => item.length > 0)
      .slice(0, 100);
}

// Documentos públicos del arranque. Lista cerrada de campos para evitar
// exponer datos operativos, credenciales o información de socios.
function sanitizarConfiguracionArranque(documento, data = {}) {
  const items = Array.isArray(data.items) ? data.items : [];
  if (documento === "actividades") {
    return {items: items.filter((item) => item && typeof item === "object")
        .map((item) => ({
          nombre: texto(item.nombre), horarios: texto(item.horarios),
          arancel: texto(item.arancel), icono: texto(item.icono),
          color: texto(item.color), es_futbol: item.es_futbol === true,
        })).filter((item) => item.nombre).slice(0, 100)};
  }
  if (documento === "contacto") {
    return {items: items.filter((item) => item && typeof item === "object")
        .map((item) => ({
          titulo: texto(item.titulo), subtitulo: texto(item.subtitulo),
          url: texto(item.url), icono: texto(item.icono), color: texto(item.color),
        })).filter((item) => item.titulo).slice(0, 100)};
  }
  if (documento === "versiones") {
    return {minima_android: texto(data.minima_android),
      url_playstore: texto(data.url_playstore)};
  }
  if (documento === "aviso_entrada") {
    return {activo: data.activo === true, titulo: texto(data.titulo),
      mensaje: texto(data.mensaje), imagen_url: texto(data.imagen_url)};
  }
  return null;
}

// ============================================================
// NOTICIAS
// ============================================================

function sanitizarNoticia(doc) {
  const data = doc.data() || {};

  return {
    _doc_id: doc.id,
    titulo: texto(data.titulo),
    bajada: texto(data.bajada),
    cuerpo: texto(data.cuerpo),
    imagen_url:
      texto(data.imagen_url),
    visible:
      data.visible !== false,
    fecha_ms:
      fechaMillis(data.fecha),
  };
}

// ============================================================
// AVISOS
// ============================================================

function sanitizarAviso(doc) {
  const data = doc.data() || {};

  return {
    _doc_id: doc.id,
    titulo: texto(data.titulo),
    mensaje: texto(data.mensaje),
    importante:
      data.importante === true,
    deporte_id:
      texto(data.deporte_id),
    fecha_ms:
      fechaMillis(data.fecha),
  };
}

// ============================================================
// GALERÍA
// ============================================================

function sanitizarGaleria(doc) {
  const data = doc.data() || {};

  return {
    _doc_id: doc.id,
    titulo: texto(data.titulo),
    imagen_url:
      texto(data.imagen_url),
    categoria:
      texto(data.categoria) ||
      "General",
    deporte_id:
      texto(data.deporte_id),
    fecha_ms:
      fechaMillis(data.fecha),
  };
}

// ============================================================
// PRODUCTOS
// ============================================================

function sanitizarProducto(doc) {
  const data = doc.data() || {};

  const precio =
    numeroSeguro(
        data.precio,
        0,
    );

  return {
    _doc_id: doc.id,
    titulo: texto(data.titulo),
    precio,
    descripcion:
      texto(data.descripcion),
    imagen_url:
      texto(data.imagen_url),
    activo:
      data.activo === true,
  };
}

// ============================================================
// CONFIGURACIÓN PÚBLICA DEPORTIVA
// ============================================================

function sanitizarDeporte(item) {
  if (
    !item ||
    typeof item !== "object"
  ) {
    return null;
  }

  const id =
    texto(item.id);

  const titulo =
    texto(item.titulo);

  if (
    !id ||
    id.length > 80 ||
    !titulo
  ) {
    return null;
  }

  const categorias =
    Array.isArray(item.categorias) ?
      item.categorias
          .map(
              (categoria) =>
                texto(categoria),
          )
          .filter(
              (categoria) =>
                categoria.length > 0,
          )
          .slice(0, 100) :
      [];

  return {
    id,
    titulo,
    tipo:
      texto(item.tipo) ||
      "competencia",
    categorias,
  };
}

// ============================================================
// TRADUCCIÓN DE MÓDULOS CENTRAL → APP PÚBLICA
// ============================================================

function sanitizarModulosActivos(
    valorLegacy,
    valorCentral,
) {
  const legacy =
    valorLegacy &&
    typeof valorLegacy === "object" ?
      valorLegacy :
      {};

  const central =
    valorCentral &&
    typeof valorCentral === "object" ?
      valorCentral :
      {};

  const tieneConfiguracionCentral =
    Object.keys(central).length > 0;

  if (!tieneConfiguracionCentral) {
    return {
      minuto_a_minuto:
        legacy.minuto_a_minuto === true,

      tienda:
        legacy.tienda === true,

      sorteos:
        legacy.sorteos === true,

      stream:
        legacy.stream === true,

      prode:
        legacy.prode === true,

      votacion:
        legacy.votacion === true,

      institucional:
        legacy.institucional === true,

      reservas:
        legacy.reservas === true,

      publicidad:
        legacy.publicidad === true,
    };
  }

  return {
    minuto_a_minuto:
      central.deportes === true &&
      central.partidos === true,

    tienda:
      central.productos === true,

    sorteos:
      central.sorteos === true,

    prode:
      central.prode === true,

    votacion:
      central.votacion === true,

    institucional:
      central.socios === true,

    reservas:
      central.reservas === true,

    stream:
      legacy.stream === true,

    publicidad:
      legacy.publicidad === true,
  };
}

function sanitizarEnlaces(valor) {
  if (
    !valor ||
    typeof valor !== "object"
  ) {
    return {};
  }

  const resultado = {};

  for (
    const [claveRaw, urlRaw]
    of Object.entries(valor)
  ) {
    const clave =
      texto(claveRaw);

    const url =
      texto(urlRaw);

    if (
      !/^[a-zA-Z0-9_-]{1,80}$/
          .test(clave)
    ) {
      continue;
    }

    if (
      !/^https?:\/\//i.test(url)
    ) {
      continue;
    }

    resultado[clave] = url;
  }

  return resultado;
}

function sanitizarStreamPublico(
    valor,
) {
  const data =
    valor &&
    typeof valor === "object" ?
      valor :
      {};

  const url =
    texto(data.url);

  return {
    en_vivo:
      data.en_vivo === true,
    url:
      /^https?:\/\//i.test(url) ?
        url :
        "",
  };
}

// ============================================================
// JUGADORES
// ============================================================

function sanitizarJugador(doc) {
  const data = doc.data() || {};

  return {
    _doc_id: doc.id,

    nombre:
      texto(data.nombre),

    apellido:
      texto(data.apellido),

    dorsal:
      enteroSeguro(
          data.dorsal,
          0,
      ),

    posicion:
      texto(data.posicion),

    foto:
      texto(data.foto),

    fecha_nacimiento:
      texto(
          data.fecha_nacimiento,
      ),

    pierna_habil:
      texto(
          data.pierna_habil,
      ),

    goles:
      enteroSeguro(
          data.goles,
          0,
      ),

    asistencias:
      enteroSeguro(
          data.asistencias,
          0,
      ),

    categoria:
      texto(data.categoria) ||
      "General",

    deporte_id:
      texto(data.deporte_id),

    rol:
      texto(data.rol) ||
      "Jugador",
  };
}

// ============================================================
// RESULTADOS
// ============================================================

function sanitizarResultadoCategoria(
    resultado,
) {
  if (
    !resultado ||
    typeof resultado !== "object"
  ) {
    return null;
  }

  return {
    categoria:
      texto(resultado.categoria),

    goles_propios:
      enteroSeguro(
          resultado.goles_propios,
          0,
      ),

    goles_rival:
      enteroSeguro(
          resultado.goles_rival,
          0,
      ),

    autores_propios:
      listaTexto(
          resultado.autores_propios,
      ),

    autores_rival:
      listaTexto(
          resultado.autores_rival,
      ),
  };
}

function sanitizarListaResultados(
    valor,
) {
  if (!Array.isArray(valor)) {
    return [];
  }

  return valor
      .map(
          sanitizarResultadoCategoria,
      )
      .filter(Boolean)
      .slice(0, 100);
}

function sanitizarPartido(doc) {
  const data = doc.data() || {};

  return {
    _doc_id: doc.id,

    deporte_id:
      texto(data.deporte_id),

    torneo:
      texto(data.torneo),

    rival:
      texto(data.rival),

    es_local:
      data.es_local !== false,

    estado:
      texto(data.estado) ||
      "programado",

    jornada:
      texto(data.jornada) ||
      "Partido",

    escudo_rival:
      texto(
          data.escudo_rival,
      ) ||
      texto(
          data.escudo_url,
      ),

    fecha_ms:
      fechaMillis(data.fecha),

    resultado:
      sanitizarListaResultados(
          data.resultado,
      ),

    resultados:
      sanitizarListaResultados(
          data.resultados,
      ),
  };
}

// ============================================================
// MINUTO A MINUTO
// ============================================================

function sanitizarEventoVivo(
    evento,
) {
  if (
    !evento ||
    typeof evento !== "object"
  ) {
    return null;
  }

  return {
    tipo:
      texto(evento.tipo),

    equipo:
      texto(evento.equipo),

    detalle:
      texto(evento.detalle),

    minuto:
      texto(evento.minuto),
  };
}

function sanitizarEventosVivo(
    valor,
) {
  if (!Array.isArray(valor)) {
    return [];
  }

  return valor
      .map(
          sanitizarEventoVivo,
      )
      .filter(Boolean)
      .slice(0, 500);
}

function sanitizarVivo(data) {
  data = data || {};

  return {
    activo:
      data.activo === true,

    deporte_id:
      texto(data.deporte_id),

    categoria:
      texto(data.categoria),

    rival:
      texto(data.rival),

    escudo_rival:
      texto(
          data.escudo_rival,
      ),

    goles_local:
      enteroSeguro(
          data.goles_local,
          0,
      ),

    goles_visita:
      enteroSeguro(
          data.goles_visita,
          0,
      ),

    estado:
      texto(data.estado),

    inicio_tiempo_ms:
      fechaMillis(
          data.inicio_tiempo,
      ),

    inicio_partido_real_ms:
      fechaMillis(
          data.inicio_partido_real,
      ),

    eventos:
      sanitizarEventosVivo(
          data.eventos,
      ),
  };
}

// ============================================================
// HISTORIAL PÚBLICO DEL MINUTO A MINUTO
// ============================================================
//
// No se exponen:
// - sesion_id
// - idAutor
// - idAsistencia
// - timestamps internos de eventos
//
// Solo se devuelve lo necesario para mostrar el partido finalizado.
// ============================================================

function sanitizarPartidoHistorial(doc) {
  const data = doc.data() || {};

  return {
    _doc_id:
      doc.id,

    deporte_id:
      texto(
          data.deporte_id,
      ),

    categoria:
      texto(
          data.categoria,
      ),

    rival:
      texto(
          data.rival,
      ),

    escudo_rival:
      texto(
          data.escudo_rival,
      ),

    goles_local:
      enteroSeguro(
          data.goles_local,
          0,
      ),

    goles_visita:
      enteroSeguro(
          data.goles_visita,
          0,
      ),

    estado:
      texto(
          data.estado,
      ) ||
      "FINALIZADO",

    motivo_suspension:
      texto(
          data.motivo_suspension,
      ),

    fecha_ms:
      fechaMillis(
          data.fecha,
      ),

    eventos:
      sanitizarEventosVivo(
          data.eventos,
      ),
  };
}

// ============================================================
// TIENDA - TELÉFONO
// ============================================================

async function obtenerTelefonoVentas(
    clubRef,
) {
  let telefono = "";

  try {
    const configSnap =
      await clubRef
          .collection(
              "configuracion",
          )
          .doc("general")
          .get();

    if (configSnap.exists) {
      const config =
        configSnap.data() || {};

      telefono =
        texto(
            config.telefono_ventas,
        ) ||
        texto(
            config.telefono_contacto,
        );
    }
  } catch (e) {
    console.warn(
        "No se pudo leer el teléfono " +
        "de ventas de configuración:",
        e,
    );
  }

  if (telefono) {
    return telefono;
  }

  try {
    const clubSnap =
      await clubRef.get();

    const club =
      clubSnap.data() || {};

    const identidad =
      club.identidad || {};

    telefono =
      texto(
          club.telefono_ventas,
      ) ||
      texto(
          club.telefono_contacto,
      ) ||
      texto(
          identidad.telefonoVentas,
      ) ||
      texto(
          identidad.telefonoContacto,
      );
  } catch (e) {
    console.warn(
        "No se pudo leer el teléfono " +
        "de ventas del club:",
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
    .https.onRequest(
        async (req, res) => {
          res.set(
              "Access-Control-Allow-Origin",
              "*",
          );

          res.set(
              "Access-Control-Allow-Headers",
              "Content-Type",
          );

          res.set(
              "Access-Control-Allow-Methods",
              "POST, OPTIONS",
          );

          res.set(
              "Cache-Control",
              "no-store",
          );

          res.set(
              "X-Content-Type-Options",
              "nosniff",
          );

          if (
            req.method === "OPTIONS"
          ) {
            res.status(204).send("");
            return;
          }

          if (
            req.method !== "POST"
          ) {
            responder(
                res,
                405,
                {
                  ok: false,
                  mensaje:
                    "Método no permitido.",
                },
            );

            return;
          }

          let body = req.body;

          if (
            typeof body === "string"
          ) {
            try {
              body =
                JSON.parse(body);
            } catch (_) {
              body = {};
            }
          }

          const accion =
            texto(body?.accion);

          const clubId =
            clubIdSeguro(
                body?.clubId,
            );

          try {
            if (accion === "arranque") {
              const documento = texto(body?.documento);
              if (!["actividades", "contacto", "versiones", "aviso_entrada",
                "publicidad"].includes(documento)) {
                responder(res, 400, {ok: false, mensaje: "Documento no permitido."});
                return;
              }
              const clubRef = await obtenerClubHabilitado(clubId);
              if (!clubRef) {
                responder(res, 404, {ok: false, mensaje: "El club no está disponible."});
                return;
              }
              let datos;
              if (documento === "publicidad") {
                const [clubSnap, generalSnap] = await Promise.all([
                  clubRef.get(), clubRef.collection("configuracion").doc("general").get(),
                ]);
                const modulos = sanitizarModulosActivos(
                    generalSnap.data()?.modulos_activos, clubSnap.data()?.modulos,
                );
                let items = [];
                if (modulos.publicidad) {
                  const snap = await clubRef.collection("publicidad")
                      .where("activo", "==", true).orderBy("orden").limit(100).get();
                  items = snap.docs.map((doc) => {
                    const data = doc.data() || {};
                    return {nombre: texto(data.nombre), imagen_url: texto(data.imagen_url),
                      link: texto(data.link)};
                  });
                }
                datos = {items};
              } else {
                const snap = await clubRef.collection("configuracion").doc(documento).get();
                datos = sanitizarConfiguracionArranque(documento, snap.data() || {});
              }
              responder(res, 200, {ok: true, clubId, datos});
              return;
            }
            // ================================================
            // CONFIGURACIÓN PÚBLICA DEL CLUB
            // ================================================

            if (
              accion ===
              "configuracion"
            ) {
              const clubRef =
                await obtenerClubHabilitado(
                    clubId,
                );

              if (!clubRef) {
                responder(
                    res,
                    404,
                    {
                      ok: false,
                      mensaje:
                        "El club no está disponible.",
                    },
                );

                return;
              }

              const [
                clubSnap,
                generalSnap,
                enlacesSnap,
                streamSnap,
              ] =
                await Promise.all([
                  clubRef.get(),

                  clubRef
                      .collection(
                          "configuracion",
                      )
                      .doc("general")
                      .get(),

                  clubRef
                      .collection(
                          "configuracion",
                      )
                      .doc("enlaces")
                      .get(),

                  clubRef
                      .collection(
                          "configuracion",
                      )
                      .doc("stream")
                      .get(),
                ]);

              const clubData =
                clubSnap.data() ||
                {};

              const general =
                generalSnap.data() ||
                {};

              const menuRaw =
                Array.isArray(
                    general.menu_deportes,
                ) ?
                  general.menu_deportes :
                  [];

              const menuDeportes =
                menuRaw
                    .map(
                        sanitizarDeporte,
                    )
                    .filter(Boolean)
                    .slice(0, 100);

              const modulosActivos =
                sanitizarModulosActivos(
                    general.modulos_activos,
                    clubData.modulos,
                );

              const enlaces =
                sanitizarEnlaces(
                    enlacesSnap.data(),
                );

              const stream =
                sanitizarStreamPublico(
                    streamSnap.data(),
                );

              responder(
                  res,
                  200,
                  {
                    ok: true,
                    clubId,
                    menu_deportes:
                      menuDeportes,
                    modulos_activos:
                      modulosActivos,
                    activar_multi_actividad:
                      general
                          .activar_multi_actividad ===
                        true,
                    enlaces,
                    stream,
                  },
              );

              return;
            }

            // ================================================
            // NOTICIAS
            // ================================================

            if (
              accion ===
              "noticias"
            ) {
              const clubRef =
                await obtenerClubHabilitado(
                    clubId,
                    "noticias",
                );

              if (!clubRef) {
                responder(
                    res,
                    404,
                    {
                      ok: false,
                      mensaje:
                        "Noticias no está disponible para este club.",
                    },
                );

                return;
              }

              const snap =
                await clubRef
                    .collection(
                        "noticias",
                    )
                    .limit(200)
                    .get();

              const noticias =
                snap.docs
                    .filter(
                        (doc) =>
                          doc.data()
                              ?.visible !==
                            false,
                    )
                    .map(
                        sanitizarNoticia,
                    )
                    .sort(
                        (a, b) =>
                          b.fecha_ms -
                          a.fecha_ms,
                    )
                    .slice(0, 100);

              responder(
                  res,
                  200,
                  {
                    ok: true,
                    clubId,
                    noticias,
                  },
              );

              return;
            }

            // ================================================
            // AVISOS
            // ================================================

            if (
              accion ===
              "avisos"
            ) {
              const deporteId =
                texto(
                    body?.deporteId,
                );

              if (
                !deporteId ||
                deporteId.length > 80
              ) {
                responder(
                    res,
                    400,
                    {
                      ok: false,
                      mensaje:
                        "El deporte solicitado no es válido.",
                    },
                );

                return;
              }

              const clubRef =
                await obtenerClubHabilitado(
                    clubId,
                    "avisos",
                );

              if (!clubRef) {
                responder(
                    res,
                    404,
                    {
                      ok: false,
                      mensaje:
                        "Avisos no está disponible para este club.",
                    },
                );

                return;
              }

              const snap =
                await clubRef
                    .collection(
                        "avisos",
                    )
                    .limit(300)
                    .get();

              const avisos =
                snap.docs
                    .filter(
                        (doc) =>
                          texto(
                              doc.data()
                                  ?.deporte_id,
                          ) ===
                          deporteId,
                    )
                    .map(
                        sanitizarAviso,
                    )
                    .sort(
                        (a, b) =>
                          b.fecha_ms -
                          a.fecha_ms,
                    )
                    .slice(0, 100);

              responder(
                  res,
                  200,
                  {
                    ok: true,
                    clubId,
                    deporteId,
                    avisos,
                  },
              );

              return;
            }

            // ================================================
            // GALERÍA
            // ================================================

            if (
              accion ===
              "galeria"
            ) {
              const deporteId =
                texto(
                    body?.deporteId,
                );

              if (
                !deporteId ||
                deporteId.length > 80
              ) {
                responder(
                    res,
                    400,
                    {
                      ok: false,
                      mensaje:
                        "El deporte solicitado no es válido.",
                    },
                );

                return;
              }

              const clubRef =
                await obtenerClubHabilitado(
                    clubId,
                    "galeria",
                );

              if (!clubRef) {
                responder(
                    res,
                    404,
                    {
                      ok: false,
                      mensaje:
                        "Galería no está disponible para este club.",
                    },
                );

                return;
              }

              const snap =
                await clubRef
                    .collection(
                        "galeria",
                    )
                    .where(
                        "deporte_id",
                        "==",
                        deporteId,
                    )
                    .limit(500)
                    .get();

              const galeria =
                snap.docs
                    .map(
                        sanitizarGaleria,
                    )
                    .filter(
                        (foto) =>
                          foto.imagen_url,
                    )
                    .sort(
                        (a, b) =>
                          b.fecha_ms -
                          a.fecha_ms,
                    )
                    .slice(0, 300);

              responder(
                  res,
                  200,
                  {
                    ok: true,
                    clubId,
                    deporteId,
                    galeria,
                  },
              );

              return;
            }

            // ================================================
            // PRODUCTOS
            // ================================================

            if (
              accion ===
              "productos"
            ) {
              const clubRef =
                await obtenerClubHabilitado(
                    clubId,
                    "productos",
                );

              if (!clubRef) {
                responder(
                    res,
                    404,
                    {
                      ok: false,
                      mensaje:
                        "Tienda no está disponible para este club.",
                    },
                );

                return;
              }

              const snap =
                await clubRef
                    .collection(
                        "productos",
                    )
                    .limit(300)
                    .get();

              const productos =
                snap.docs
                    .filter(
                        (doc) =>
                          doc.data()
                              ?.activo ===
                            true,
                    )
                    .map(
                        sanitizarProducto,
                    )
                    .filter(
                        (producto) =>
                          producto.titulo,
                    )
                    .sort(
                        (a, b) =>
                          a.titulo
                              .localeCompare(
                                  b.titulo,
                                  "es",
                              ),
                    )
                    .slice(0, 200);

              const telefonoVentas =
                await obtenerTelefonoVentas(
                    clubRef,
                );

              responder(
                  res,
                  200,
                  {
                    ok: true,
                    clubId,
                    telefono_ventas:
                      telefonoVentas,
                    productos,
                  },
              );

              return;
            }

            // ================================================
            // PLANTELES PÚBLICOS
            // ================================================

            if (
              accion ===
              "jugadores"
            ) {
              const deporteId =
                texto(
                    body?.deporteId,
                );

              if (
                !deporteId ||
                deporteId.length > 80
              ) {
                responder(
                    res,
                    400,
                    {
                      ok: false,
                      mensaje:
                        "El deporte solicitado no es válido.",
                    },
                );

                return;
              }

              const clubRef =
                await obtenerClubHabilitado(
                    clubId,
                    "deportes",
                );

              if (!clubRef) {
                responder(
                    res,
                    404,
                    {
                      ok: false,
                      mensaje:
                        "Deportes no está disponible para este club.",
                    },
                );

                return;
              }

              const snap =
                await clubRef
                    .collection(
                        "jugadores",
                    )
                    .where(
                        "deporte_id",
                        "==",
                        deporteId,
                    )
                    .limit(500)
                    .get();

              const jugadores =
                snap.docs
                    .map(
                        sanitizarJugador,
                    )
                    .sort(
                        (a, b) => {
                          const rolA =
                            a.rol ===
                            "DT" ?
                              0 :
                              1;

                          const rolB =
                            b.rol ===
                            "DT" ?
                              0 :
                              1;

                          if (
                            rolA !== rolB
                          ) {
                            return (
                              rolA -
                              rolB
                            );
                          }

                          if (
                            a.dorsal !==
                            b.dorsal
                          ) {
                            return (
                              a.dorsal -
                              b.dorsal
                            );
                          }

                          return a.apellido
                              .localeCompare(
                                  b.apellido,
                                  "es",
                              );
                        },
                    );

              responder(
                  res,
                  200,
                  {
                    ok: true,
                    clubId,
                    deporteId,
                    jugadores,
                  },
              );

              return;
            }

            // ================================================
            // RESULTADOS PÚBLICOS
            // ================================================

            if (
              accion ===
              "resultados"
            ) {
              const deporteId =
                texto(
                    body?.deporteId,
                );

              const torneo =
                texto(
                    body?.torneo,
                );

              if (
                !deporteId ||
                deporteId.length > 80 ||
                torneo.length > 100
              ) {
                responder(
                    res,
                    400,
                    {
                      ok: false,
                      mensaje:
                        "La consulta de resultados no es válida.",
                    },
                );

                return;
              }

              const clubRef =
                await obtenerClubHabilitado(
                    clubId,
                    "deportes",
                );

              if (!clubRef) {
                responder(
                    res,
                    404,
                    {
                      ok: false,
                      mensaje:
                        "Deportes no está disponible para este club.",
                    },
                );

                return;
              }

              const snap =
                await clubRef
                    .collection(
                        "partidos",
                    )
                    .where(
                        "deporte_id",
                        "==",
                        deporteId,
                    )
                    .limit(500)
                    .get();

              const partidos =
                snap.docs
                    .filter(
                        (doc) =>
                          !torneo ||
                          texto(
                              doc.data()
                                  ?.torneo,
                          ) ===
                            torneo,
                    )
                    .map(
                        sanitizarPartido,
                    )
                    .sort(
                        (a, b) =>
                          a.fecha_ms -
                          b.fecha_ms,
                    );

              responder(
                  res,
                  200,
                  {
                    ok: true,
                    clubId,
                    deporteId,
                    torneo,
                    partidos,
                  },
              );

              return;
            }

            // ================================================
            // MINUTO A MINUTO PÚBLICO
            // ================================================

            if (
              accion ===
              "vivo"
            ) {
              const deporteId =
                texto(
                    body?.deporteId,
                );

              if (
                !deporteId ||
                deporteId.length > 80
              ) {
                responder(
                    res,
                    400,
                    {
                      ok: false,
                      mensaje:
                        "El deporte solicitado no es válido.",
                    },
                );

                return;
              }

              const clubRef =
                await obtenerClubHabilitado(
                    clubId,
                    "deportes",
                );

              if (!clubRef) {
                responder(
                    res,
                    404,
                    {
                      ok: false,
                      mensaje:
                        "Deportes no está disponible para este club.",
                    },
                );

                return;
              }

              const snap =
                await clubRef
                    .collection(
                        "partidos_en_vivo",
                    )
                    .doc(deporteId)
                    .get();

              responder(
                  res,
                  200,
                  {
                    ok: true,
                    clubId,
                    deporteId,
                    vivo:
                      snap.exists ?
                        sanitizarVivo(
                            snap.data(),
                        ) :
                        null,
                  },
              );

              return;
            }

            // ================================================
            // HISTORIAL PÚBLICO DEL MINUTO A MINUTO
            // ================================================

            if (
              accion ===
              "historial"
            ) {
              const deporteId =
                texto(
                    body?.deporteId,
                );

              if (
                !deporteId ||
                deporteId.length > 80
              ) {
                responder(
                    res,
                    400,
                    {
                      ok: false,
                      mensaje:
                        "El deporte solicitado no es válido.",
                    },
                );

                return;
              }

              const clubRef =
                await obtenerClubHabilitado(
                    clubId,
                    "deportes",
                );

              if (!clubRef) {
                responder(
                    res,
                    404,
                    {
                      ok: false,
                      mensaje:
                        "Deportes no está disponible para este club.",
                    },
                );

                return;
              }

              const snap =
                await clubRef
                    .collection(
                        "historial_partidos",
                    )
                    .where(
                        "deporte_id",
                        "==",
                        deporteId,
                    )
                    .limit(500)
                    .get();

              const historial =
                snap.docs
                    .map(
                        sanitizarPartidoHistorial,
                    )
                    .sort(
                        (a, b) =>
                          b.fecha_ms -
                          a.fecha_ms,
                    )
                    .slice(0, 300);

              responder(
                  res,
                  200,
                  {
                    ok: true,
                    clubId,
                    deporteId,
                    historial,
                  },
              );

              return;
            }

            // ================================================
            // ACCIÓN INVÁLIDA
            // ================================================

            responder(
                res,
                400,
                {
                  ok: false,
                  mensaje:
                    "Acción no válida.",
                },
            );
          } catch (e) {
            console.error(
                "Error en contenido público TuSede:",
                e,
            );

            responder(
                res,
                500,
                {
                  ok: false,
                  mensaje:
                    "No pudimos cargar el contenido " +
                    "en este momento. " +
                    "Intentá nuevamente.",
                },
            );
          }
        },
    );

// ============================================================
// PUSH MULTICLUB - NOTICIAS
// ============================================================

exports.notificarNuevaNoticiaTuSede =
  functions
      .region(REGION)
      .firestore
      .document(
          "clubes/{clubId}/noticias/{noticiaId}",
      )
      .onCreate(
          async (
              snap,
              context,
          ) => {
            const clubId =
              clubIdSeguro(
                  context
                      .params
                      .clubId,
              );

            if (
              !CLUBES_HABILITADOS
                  .has(clubId)
            ) {
              console.log(
                  "Push noticia omitido: " +
                  `club no habilitado ${clubId}`,
              );

              return null;
            }

            const data =
              snap.data() || {};

            if (
              data.enviar_push ===
                false ||
              data.visible ===
                false
            ) {
              return null;
            }

            const clubRef =
              await obtenerClubHabilitado(
                  clubId,
                  "noticias",
              );

            if (!clubRef) {
              return null;
            }

            const titulo =
              texto(data.titulo) ||
              "Nueva Noticia";

            const cuerpo =
              texto(data.resumen) ||
              texto(data.bajada) ||
              "Leé la última novedad del club.";

            const payload = {
              notification: {
                title:
                  `📰 ${titulo}`,
                body: cuerpo,
              },

              topic:
                topicGeneralClub(
                    clubId,
                ),

              data: {
                click_action:
                  "FLUTTER_NOTIFICATION_CLICK",

                tipo:
                  "noticia",

                id:
                  context
                      .params
                      .noticiaId,

                club_id:
                  clubId,
              },

              android: {
                notification: {
                  sound:
                    "default",
                },
              },

              apns: {
                payload: {
                  aps: {
                    sound:
                      "default",
                  },
                },
              },
            };

            try {
              await getMessaging()
                  .send(payload);

              console.log(
                  "Push noticia TuSede enviado a " +
                  `${payload.topic}: ${titulo}`,
              );
            } catch (e) {
              console.error(
                  "Error enviando push de noticia TuSede:",
                  e,
              );
            }

            return null;
          },
      );

// ============================================================
// PUSH MULTICLUB - AVISOS
// ============================================================

exports.notificarNuevoAvisoTuSede =
  functions
      .region(REGION)
      .firestore
      .document(
          "clubes/{clubId}/avisos/{avisoId}",
      )
      .onCreate(
          async (
              snap,
              context,
          ) => {
            const clubId =
              clubIdSeguro(
                  context
                      .params
                      .clubId,
              );

            if (
              !CLUBES_HABILITADOS
                  .has(clubId)
            ) {
              console.log(
                  "Push aviso omitido: " +
                  `club no habilitado ${clubId}`,
              );

              return null;
            }

            const data =
              snap.data() || {};

            if (
              data.enviar_push ===
                false
            ) {
              return null;
            }

            const clubRef =
              await obtenerClubHabilitado(
                  clubId,
                  "avisos",
              );

            if (!clubRef) {
              return null;
            }

            const importante =
              data.importante === true;

            const tituloBase =
              texto(data.titulo) ||
              (
                importante ?
                  "AVISO URGENTE" :
                  "Nuevo Aviso"
              );

            const titulo =
              importante ?
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

              topic:
                topicGeneralClub(
                    clubId,
                ),

              data: {
                click_action:
                  "FLUTTER_NOTIFICATION_CLICK",

                tipo:
                  "aviso",

                id:
                  context
                      .params
                      .avisoId,

                club_id:
                  clubId,
              },

              android: {
                notification: {
                  sound:
                    "default",
                },
              },

              apns: {
                payload: {
                  aps: {
                    sound:
                      "default",
                  },
                },
              },
            };

            try {
              await getMessaging()
                  .send(payload);

              console.log(
                  "Push aviso TuSede enviado a " +
                  `${payload.topic}: ${titulo}`,
              );
            } catch (e) {
              console.error(
                  "Error enviando push de aviso TuSede:",
                  e,
              );
            }

            return null;
          },
      );