const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test} = require('node:test');

const reads = [];
const filters = [];
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
    where(...args) { filters.push(args); return this; }, orderBy() { return this; }, limit() { return this; },
    async get() {
      reads.push(location);
      if (location === 'clubes/generico') return {exists: true, data: () => ({activo: active})};
      if (location.endsWith('/rivales')) return {docs:[{id:'uno',data:()=>({nombre:'Rival',direccion:'Calle 1',deporte_id:'baby',es_techado:true,escudo_url:'https://example.com/logo.png',mapa_url:'javascript:alert(1)',email:'privado',secreto:'privado'})}]};
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
    if (name === './plataforma_validacion') return require('../functions_tusede/plataforma_validacion');
    if (name === 'firebase-functions/v1') return builder;
    if (name === 'firebase-admin/app') return {getApps: () => [{}]};
    if (name === 'firebase-admin/firestore') return {getFirestore: () => root};
    if (name === 'firebase-admin/messaging') return {getMessaging: () => ({})};
    throw new Error(name);
  },
});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../functions_tusede/contenido_publico.js'), 'utf8'), context);
async function request(documento, clubId = 'generico', accion = 'arranque', deporteId = 'baby') {
  reads.length = 0; filters.length = 0;
  let status; let body;
  const res = {set() {}, status(code) { status = code; return this; }, json(data) { body = JSON.parse(JSON.stringify(data)); }};
  await context.exports.contenidoPublico({method: 'POST', body: {accion, documento, clubId, deporteId}}, res);
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
  assert.deepEqual(reads, ['clubes/guemes']);
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


test('rivales públicos filtran club/deporte y solo exponen campos de presentación', async () => {
  const {status,body} = await request(null,'generico','rivales');
  assert.equal(status,200);
  assert.deepEqual(reads,['clubes/generico','clubes/generico/rivales']);
  assert.deepEqual(filters,[['deporte_id','==','baby']]);
  assert.equal(body.rivales[0].nombre,'Rival');
  assert.equal(body.rivales[0].mapa_url,'');
  assert.ok(!JSON.stringify(body).includes('privado'));
});
test('rivales rechazan deporte inválido y clubes inactivos/Legacy', async () => {
  assert.equal((await request(null,'generico','rivales','')).status,400);
  assert.equal(reads.length,0);
  active=false; assert.equal((await request(null,'generico','rivales')).status,404); active=true;
  assert.equal((await request(null,'guemes','rivales')).status,404);
});


test('minuto pedido se publica para sincronizar el reloj y se limpia al reanudar', () => {
  const data = context.sanitizarVivo({activo:true,estado:'1T',inicio_tiempo:{toMillis:()=>1000},minuto_pedido_en:{toMillis:()=>36000},admin_email:'privado'});
  assert.equal(data.inicio_tiempo_ms, 1000);
  assert.equal(data.minuto_pedido_en_ms, 36000);
  assert.equal(data.admin_email, undefined);
  assert.equal(context.sanitizarVivo({minuto_pedido_en:null}).minuto_pedido_en_ms, 0);
});
