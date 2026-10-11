"use strict";
const MODULOS = ["socios", "cuotas", "finanzas", "deportes", "partidos", "jugadores", "noticias", "avisos", "actividades", "galeria", "asistencias", "espacios", "reservas", "productos", "sorteos", "prode", "votacion"];
function validarAlta(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error("Datos inválidos.");
  const id = String(data.id || "").trim();
  const nombre = String(data.nombre || "").trim();
  if (!/^[a-z0-9][a-z0-9_-]{1,39}$/.test(id)) throw new Error("El identificador debe tener entre 2 y 40 caracteres: letras minúsculas, números, guiones.");
  if (["guemes", "fatima", "laloma", "generico", "tusede"].includes(id)) throw new Error("Ese identificador está reservado.");
  if (nombre.length < 2 || nombre.length > 100) throw new Error("El nombre debe tener entre 2 y 100 caracteres.");
  const identidad = {};
  for (const key of ["colorPrimario", "colorSecundario"]) {
    const valor = String(data[key] || "");
    if (!/^#[0-9a-fA-F]{6}$/.test(valor)) throw new Error("Los colores deben tener formato #RRGGBB.");
    identidad[key] = valor.toUpperCase();
  }
  identidad.nombreCorto = String(data.nombreCorto || nombre).trim().slice(0, 100);
  identidad.lema = String(data.lema || "").trim().slice(0, 200);
  identidad.logoUrl = "";
  const seleccion = data.modulos || [];
  if (!Array.isArray(seleccion) || seleccion.some(m => !MODULOS.includes(m))) throw new Error("Módulos inválidos.");
  return {nombre, slug: id, flavor_legacy: "generico", origenDatos: "central", estado: "borrador", activo: false, tusedeBridgeActivo: false, versionConfiguracion: 1, identidad, modulos: Object.fromEntries(MODULOS.map(m => [m, seleccion.includes(m)]))};
}
function validarEdicion(data, anterior) {
  if (!anterior || anterior.estado !== "borrador" || anterior.origenDatos !== "central") {
    throw new Error("Solo se permite editar los clubes centrales en borrador.");
  }
  const validado = validarAlta(data);
  return {
    nombre: validado.nombre,
    identidad: {...(anterior.identidad || {}), ...validado.identidad, logoUrl: anterior.identidad?.logoUrl || ""},
    modulos: validado.modulos,
  };
}
function esClubCentralActivo(id, data) {
  return /^[a-z0-9][a-z0-9_-]{1,39}$/.test(id) && data?.activo === true &&
    (id === "generico" || (data.origenDatos === "central" && data.estado === "activo"));
}
function validarActivacion(id, data) {
  if (!data || data.estado !== "borrador" || data.origenDatos !== "central") throw new Error("Solo se activan clubes centrales en borrador.");
  validarAlta({id, nombre: data.nombre, ...data.identidad, modulos: Object.keys(data.modulos || {}).filter(k => data.modulos[k] === true)});
  if (!data.identidad?.logoUrl || !Object.values(data.modulos || {}).includes(true)) throw new Error("Cargá el logo y seleccioná al menos un módulo antes de activar.");
}
module.exports = {validarAlta, validarEdicion, esClubCentralActivo, validarActivacion};
