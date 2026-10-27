"use strict";
const {createHash} = require('node:crypto');
const PROJECT = 'tu-sede-app';
const ROOT = `projects/${PROJECT}/databases/(default)/documents`;
const SOURCE_BUCKET = 'tu-sede-app.firebasestorage.app';
const BACKUP_BUCKET = 'tu-sede-app-respaldos';
const LIMITS = {documents: 500, files: 100, fileBytes: 16 * 1024 * 1024, totalBytes: 256 * 1024 * 1024, manifestBytes: 10 * 1024 * 1024};
class ErrorRespaldo extends Error { constructor(message, status = 409) { super(message); this.status = status; } }
function exigir(ok, message, status) { if (!ok) throw new ErrorRespaldo(message, status); }
function validarId(id) {
  exigir(typeof id === 'string' && /^[a-z0-9][a-z0-9_-]{1,39}$/.test(id) &&
    !['guemes','fatima','laloma','generico','tusede'].includes(id), 'Identificador inválido o protegido.', 400);
}
function validarOperacion(id) { exigir(typeof id === 'string' && /^[a-f0-9]{32}$/.test(id), 'Operación inválida.', 400); }
function validarActor(p) { exigir(p?.activo === true && p.rol === 'superadmin', 'Se requiere un superadmin activo.', 403); }
function validarClub(c) { exigir(c?.origenDatos === 'central' && ['activo','borrador'].includes(c.estado), 'Solo se respaldan clubes Central disponibles.'); }
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const md5 = bytes => createHash('md5').update(bytes).digest('base64');
function validarManifiesto(m, clubId) {
  exigir(m?.version === 1 && m.proyecto === PROJECT && m.clubId === clubId, 'Formato de respaldo incompatible.');
  exigir(Array.isArray(m.documents) && m.documents.length > 0 && m.documents.length <= LIMITS.documents, 'Cantidad de documentos inválida.');
  exigir(Array.isArray(m.files) && m.files.length <= LIMITS.files, 'Cantidad de archivos inválida.');
  const prefix = `${ROOT}/clubes/${clubId}`;
  const names = new Set();
  for (const d of m.documents) {
    exigir(typeof d.name === 'string' && (d.name === prefix || d.name.startsWith(prefix + '/')) && !names.has(d.name), 'Documento fuera del club o duplicado.');
    exigir(d.fields && typeof d.fields === 'object', 'Documento sin datos.');
    names.add(d.name);
  }
  exigir(names.has(prefix), 'Falta el documento del club.');
  const paths = new Set(); let bytes = 0;
  for (const f of m.files) {
    exigir(typeof f.name === 'string' && f.name.startsWith(`clubes/${clubId}/`) && !paths.has(f.name), 'Archivo fuera del club o duplicado.');
    exigir(/^\d+$/.test(f.generation) && typeof f.md5 === 'string' && f.md5.length > 0 && Number.isSafeInteger(f.size) && f.size >= 0 && f.size <= LIMITS.fileBytes, 'Archivo no verificable.');
    bytes += f.size; paths.add(f.name);
  }
  exigir(bytes <= LIMITS.totalBytes, 'El respaldo supera el límite de archivos.');
  return m;
}
function rutaImagen(value) {
  if (typeof value !== 'string') return null;
  try {
    const u = new URL(value);
    if (u.protocol === 'gs:' && u.hostname === SOURCE_BUCKET) return decodeURIComponent(u.pathname.slice(1));
    const prefix = `/v0/b/${SOURCE_BUCKET}/o/`;
    if (u.protocol === 'https:' && u.hostname === 'firebasestorage.googleapis.com' && u.pathname.startsWith(prefix)) return decodeURIComponent(u.pathname.slice(prefix.length));
  } catch (_) { /* Texto normal. */ }
  return null;
}
function revisarEnlaces(m) {
  const paths = new Set(m.files.map(f => f.name)); let externos = 0;
  function visit(v) {
    if (!v || typeof v !== 'object') return;
    if (typeof v.stringValue === 'string') {
      const path = rutaImagen(v.stringValue);
      if (path?.startsWith(`clubes/${m.clubId}/`)) exigir(paths.has(path), 'Hay una imagen referenciada que ya no existe. Corregí el enlace antes de respaldar.');
      else if (/^https?:\/\//.test(v.stringValue)) externos++;
    }
    Object.values(v).forEach(x => { if (Array.isArray(x)) x.forEach(visit); else if (x && typeof x === 'object') visit(x); });
  }
  m.documents.forEach(d => visit(d.fields)); return externos;
}
function transformarDocumento(d, m, destino, operacion) {
  const old = `${ROOT}/clubes/${m.clubId}`, nuevo = `${ROOT}/clubes/${destino}`;
  const urls = new Map(m.files.map(f => {
    const path = `clubes/${destino}/${f.name.slice(`clubes/${m.clubId}/`.length)}`;
    // Token nuevo, determinista para reintentos de esta recuperación (operacion es aleatoria).
    const token = sha(`${operacion}\n${path}`);
    return [f.name, `https://firebasestorage.googleapis.com/v0/b/${SOURCE_BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=${token}`];
  }));
  function value(v, key) {
    if (v.stringValue !== undefined) {
      const path = rutaImagen(v.stringValue);
      if (urls.has(path)) return {stringValue: urls.get(path)};
      if (['clubId','clubPrincipal'].includes(key) && v.stringValue === m.clubId) return {stringValue: destino};
    }
    if (v.referenceValue === old || v.referenceValue?.startsWith(old + '/')) return {referenceValue: nuevo + v.referenceValue.slice(old.length)};
    if (v.mapValue) return {mapValue: {fields: Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k,x]) => [k,value(x,k)]))}};
    if (v.arrayValue) return {arrayValue: {values: (v.arrayValue.values || []).map(x => value(x,key))}};
    return v;
  }
  const fields = Object.fromEntries(Object.entries(d.fields).map(([k,v]) => [k,value(v,k)]));
  return {name: nuevo + d.name.slice(old.length), fields};
}
function documentosRestaurables(m) {
  return m.documents.filter(d => d.name !== `${ROOT}/clubes/${m.clubId}` &&
    !['configuracion/permisos_roles','configuracion/seguridad'].some(p => d.name === `${ROOT}/clubes/${m.clubId}/${p}` || d.name.startsWith(`${ROOT}/clubes/${m.clubId}/${p}/`)));
}
module.exports = {PROJECT, ROOT, SOURCE_BUCKET, BACKUP_BUCKET, LIMITS, ErrorRespaldo, exigir, validarId, validarOperacion, validarActor, validarClub, sha, md5, validarManifiesto, revisarEnlaces, transformarDocumento, documentosRestaurables};
