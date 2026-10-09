const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test} = require('node:test');

const reads = [];
let active = true;
let ads = false;
const documents = {
  versiones: {minima_android: '2.0.0', url_playstore: 'central', secreto: 'privado'},
  aviso_entrada: {activo: true, titulo: 'Central', mensaje: 'Hola', admin_email: 'privado'},
  actividades: {items: [{nombre: 'Tenis', arancel: 'Consultar', secreto: 'privado'}, null]},
  contacto: {items: [{titulo: 'Secretaría', url: 'central', token: 'privado'}]},
};
function ref(location) {
  return {
    collection(name) { return ref(`${location}/${name}`); },
    doc(name) { return ref(`${location}/${name}`); },
    where() { return this; }, orderBy() { return this; }, limit() { return this; },
    async get() {
      reads.push(location);
      if (location === 'clubes/generico') return {exists: true, data: () => ({activo: active})};
      if (location.endsWith('/general')) return {data: () => ({modulos_activos: {publicidad: ads}})};
      if (location.endsWith('/publicidad')) return {docs: [{data: () => ({nombre: 'Sponsor', imagen_url: 'img', link: 'link', secreto: 'privado'})}]};
      return {data: () => documents[location.split('/').at(-1)]};
    },
  };
}
const builder = {
  region() { return this; }, runWith() { return this; },
  https: {onRequest(handler) { return handler; }},
  firestore: {document() { return {onCreate() { return () => {}; }}; }},
};
const root = ref('');
root.collection = (name) => ref(name);
const context = vm.createContext({
  exports: {}, console,
  require(name) {
    if (name === 'firebase-functions/v1') return builder;
    if (name === 'firebase-admin/app') return {getApps: () => [{}]};
    if (name === 'firebase-admin/firestore') return {getFirestore: () => root};
    if (name === 'firebase-admin/messaging') return {getMessaging: () => ({})};
    throw new Error(name);
  },
});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../functions_tusede/contenido_publico.js'), 'utf8'), context);
async function request(documento, clubId = 'generico') {
  reads.length = 0;
  let status; let body;
  const res = {set() {}, status(code) { status = code; return this; }, json(data) { body = JSON.parse(JSON.stringify(data)); }};
  await context.exports.contenidoPublico({method: 'POST', body: {accion: 'arranque', documento, clubId}}, res);
  return {status, body};
}
test('documentos públicos omiten campos privados y consultan solo el club Central', async () => {
  for (const doc of Object.keys(documents)) {
    const {status, body} = await request(doc);
    assert.equal(status, 200);
    assert.equal(body.ok, true);
    assert.ok(reads.every((p) => p.startsWith('clubes/generico')));
    assert.ok(!JSON.stringify(body).includes('privado'));
  }
});
test('rechaza documentos privados y clubes Legacy', async () => {
  assert.equal((await request('pagos')).status, 400);
  assert.equal(reads.length, 0);
  assert.equal((await request('versiones', 'guemes')).status, 404);
  assert.equal(reads.length, 0);
});
test('club inactivo no expone configuración', async () => {
  active = false;
  assert.equal((await request('contacto')).status, 404);
  active = true;
});
test('publicidad respeta módulo y omite campos privados', async () => {
  ads = false;
  assert.deepEqual((await request('publicidad')).body.datos, {items: []});
  assert.ok(!reads.includes('clubes/generico/publicidad'));
  ads = true;
  assert.deepEqual((await request('publicidad')).body.datos.items, [{nombre: 'Sponsor', imagen_url: 'img', link: 'link'}]);
});
