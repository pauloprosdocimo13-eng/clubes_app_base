const {test} = require('node:test');
const assert = require('node:assert/strict');
const {crearServicioEliminacion, validarId, clasificar} = require('../functions_tusede/eliminacion_club');
const clone = value => value === undefined ? undefined : structuredClone(value);
function entorno() {
  const data = new Map(); const versions = new Map(); let clock = 100000; let tick = 1;
  const put = (path, value) => { data.set(path, clone(value)); versions.set(path, tick++); };
  put('usuarios/super', {rol: 'superadmin', activo: true, clubIds: ['demo', 'otro'], clubPrincipal: 'otro'});
  put('usuarios/exclusivo', {rol: 'admin', activo: true, clubIds: ['demo'], clubPrincipal: 'demo', origenAlta: 'plataforma_club', email: 'a@club.org'});
  put('usuarios/compartido', {rol: 'admin', activo: true, clubIds: ['demo', 'otro'], clubPrincipal: 'demo', email: 'b@club.org'});
  put('clubes/demo', {nombre: 'Demo', origenDatos: 'central', estado: 'activo', activo: true});
  put('clubes/demo/socios/a', {nombre: 'Prueba'});
  put('clubes/demo/socios/padre-ausente/hijos/b', {nombre: 'Hijo'});
  put('clubes/otro/socios/b', {nombre: 'No tocar'});
  put('clubes/guemes', {origenDatos: 'legacy', activo: true});
  const accounts = new Map(['super', 'exclusivo', 'compartido'].map(uid => [uid, {uid, customClaims: {}}]));
  const files = new Map([['clubes/demo/foto.png#1', {name: 'clubes/demo/foto.png', generation: '1'}],
    ['clubes/demo/foto.png#2', {name: 'clubes/demo/foto.png', generation: '2'}],
    ['clubes/demo-otro/logo.png#1', {name: 'clubes/demo-otro/logo.png', generation: '1'}]]);
  let queue = Promise.resolve(); let failRecursive = false; let failStorage = false; let failAuth = false;
  let recursiveCalls = 0;
  function snap(path) { return {id: path.split('/').at(-1), ref: ref(path), exists: data.has(path),
    data: () => clone(data.get(path)), updateTime: {seconds: versions.get(path) || 0, nanoseconds: 0}}; }
  function ref(path) { return {path, id: path.split('/').at(-1), get: async () => snap(path),
    listCollections: async () => [...new Set([...data.keys()].filter(k => k.startsWith(path + '/') &&
      k.slice(path.length + 1).includes('/')).map(k => k.slice(path.length + 1).split('/')[0]))]
      .map(id => ({id, path: path + '/' + id}))}; }
  const db = {
    doc: ref,
    collection: name => ({where: (key, op, val) => ({get: async () => ({docs: [...data.keys()]
      .filter(path => path.startsWith(name + '/') && path.split('/').length === 2 &&
        (op === 'array-contains' ? data.get(path)[key]?.includes(val) : data.get(path)[key] === val))
      .map(snap)})})}),
    runTransaction(fn) {
      const job = queue.then(async () => {
        const writes = [];
        const value = await fn({get: async r => r.path ? snap(r.path) : r.get(),
          create: (r, v) => { assert.equal(data.has(r.path), false); writes.push(() => put(r.path, v)); },
          update: (r, v) => { assert.ok(data.has(r.path)); writes.push(() => put(r.path, {...data.get(r.path), ...v})); },
          delete: r => writes.push(() => data.delete(r.path)),
        });
        writes.forEach(w => w()); return value;
      });
      queue = job.catch(() => {}); return job;
    },
    recursiveDelete: async r => {
      recursiveCalls++;
      const paths = [...data.keys()].filter(p => p === r.path || p.startsWith(r.path + '/'));
      for (const path of paths) {
        assert.ok(path.startsWith('clubes/demo/') || path.startsWith('usuarios/exclusivo'));
        data.delete(path);
        if (failRecursive) { failRecursive = false; throw new Error('fallo parcial'); }
      }
    },
  };
  const auth = {
    getUser: async uid => { if (!accounts.has(uid)) throw Object.assign(new Error(), {code: 'auth/user-not-found'}); return clone(accounts.get(uid)); },
    deleteUser: async uid => { assert.equal(uid, 'exclusivo'); if (failAuth) throw new Error('Auth no disponible'); accounts.delete(uid); },
  };
  const bucket = {getFiles: async opts => {
    assert.equal(opts.prefix, 'clubes/demo/'); assert.equal(opts.versions, true);
    const all = [...files.entries()].filter(([, f]) => f.name.startsWith(opts.prefix));
    return [all.slice(0, opts.maxResults).map(([key, f]) => ({...f, delete: async () => {
      if (failStorage) throw new Error('Storage no disponible'); files.delete(key);
    }})), all.length > opts.maxResults ? {} : null];
  }};
  const service = crearServicioEliminacion({db, auth, bucket, now: () => clock});
  return {data, accounts, files, put, service,
    preview: () => service.preparar('demo', 'super'),
    async start() { const p = await this.preview(); await service.iniciar('demo', 'super', 'demo', p.token); },
    step: () => service.continuar('demo', 'super'),
    advance: () => { clock += 100000; },
    async finish() { this.advance(); for (let i = 0; i < 25; i++) { const r = await this.step(); if (r.estado === 'completada') return; } assert.fail('No terminó'); },
    failRecursive: () => { failRecursive = true; },
    failStorage: v => { failStorage = v; },
    failAuth: v => { failAuth = v; },
    recursiveCalls: () => recursiveCalls,
  };
}

test('bloquea identificadores Legacy, reservados y rutas', () => {
  for (const id of ['guemes', 'generico', 'fatima', 'laloma', 'tusede', '../otro', 'a/b', '', null]) assert.throws(() => validarId(id));
});
test('preview no escribe ni borra y distingue exclusivas, compartidas y protegidas', async () => {
  const e = entorno(); const before = [...e.data]; const p = await e.preview();
  assert.deepEqual([...e.data], before); assert.equal(e.accounts.size, 3); assert.equal(e.files.size, 3);
  assert.equal(p.cuentas.find(p => p.uid === 'super').tipo, 'protegida');
  assert.equal(p.cuentas.find(p => p.uid === 'exclusivo').tipo, 'exclusiva');
  assert.equal(p.cuentas.find(p => p.uid === 'compartido').tipo, 'compartida');
});
test('deniega todas las acciones a un admin de club y confirma ID exacto', async () => {
  const e = entorno();
  await assert.rejects(e.service.preparar('demo', 'exclusivo'));
  await assert.rejects(e.service.iniciar('demo', 'exclusivo', 'demo', 'token'));
  await assert.rejects(e.service.continuar('demo', 'exclusivo'));
  const p = await e.preview(); await assert.rejects(e.service.iniciar('demo', 'super', 'otro', p.token));
  assert.equal(e.data.get('clubes/demo').activo, true);
});
test('preview obsoleto no inicia ni desactiva el club', async () => {
  const e = entorno(); const p = await e.preview();
  e.put('clubes/demo', {...e.data.get('clubes/demo'), nombre: 'Modificado'});
  await assert.rejects(e.service.iniciar('demo', 'super', 'demo', p.token));
  assert.equal(e.data.has('eliminaciones_club/demo'), false);
});
test('completa limpieza, retiene otros clubes y Auth compartido/superadmin, audita y es idempotente', async () => {
  const e = entorno(); await e.start();
  assert.equal(e.data.get('clubes/demo').activo, false);
  assert.equal(e.data.get('usuarios/exclusivo').activo, false);
  assert.deepEqual(e.data.get('usuarios/compartido').clubIds, ['otro']);
  assert.equal(e.data.get('usuarios/compartido').clubPrincipal, 'otro');
  await e.step(); assert.ok(e.accounts.has('exclusivo'), 'espera solicitudes en vuelo');
  await e.finish();
  assert.equal([...e.data.keys()].some(k => k === 'clubes/demo' || k.startsWith('clubes/demo/')), false);
  assert.equal(e.accounts.has('exclusivo'), false); assert.ok(e.accounts.has('compartido')); assert.ok(e.accounts.has('super'));
  assert.ok(e.data.has('clubes/guemes')); assert.ok(e.data.has('clubes/otro/socios/b'));
  assert.deepEqual([...e.files.keys()], ['clubes/demo-otro/logo.png#1']);
  assert.equal(e.data.get('auditoria_plataforma/eliminacion_demo').estado, 'completada');
  assert.equal((await e.step()).estado, 'completada');
});
test('fallo después de borrar Auth retoma sin perder el UID pendiente', async () => {
  const e = entorno(); await e.start(); e.advance(); e.failRecursive();
  await assert.rejects(e.step()); assert.equal(e.accounts.has('exclusivo'), false);
  assert.equal(e.data.get('eliminaciones_club/demo').procesados, 0);
  await e.finish(); assert.equal(e.data.has('usuarios/exclusivo'), false);
});
test('fallo de Auth y Storage no marca completado y permite reintento', async () => {
  const e = entorno(); await e.start(); e.advance(); e.failAuth(true);
  await assert.rejects(e.step()); assert.ok(e.data.has('usuarios/exclusivo'));
  e.failAuth(false); e.failStorage(true);
  await assert.rejects(e.finish());
  assert.notEqual(e.data.get('eliminaciones_club/demo').estado, 'completada');
  assert.ok(e.data.has('clubes/demo'));
  e.failStorage(false); await e.finish();
});
test('lease impide doble ejecución y permite retomar después de expiración', async () => {
  const e = entorno(); await e.start();
  e.put('eliminaciones_club/demo', {...e.data.get('eliminaciones_club/demo'), leaseHasta: 190000});
  await assert.rejects(e.step()); assert.equal(e.recursiveCalls(), 0);
  await e.finish();
});
test('no borra cuentas especiales, importadas ni roles modificados durante operación', async () => {
  const e = entorno(); e.accounts.set('exclusivo', {uid: 'exclusivo', customClaims: {admin: true}});
  await assert.rejects(e.preview()); assert.ok(e.data.get('clubes/demo').activo);
  const f = entorno(); f.put('usuarios/exclusivo', {...f.data.get('usuarios/exclusivo'), origenAlta: 'legacy'});
  await assert.rejects(f.preview());
  const g = entorno(); await g.start(); g.advance();
  g.put('usuarios/exclusivo', {...g.data.get('usuarios/exclusivo'), rol: 'superadmin'});
  await assert.rejects(g.step()); assert.ok(g.accounts.has('exclusivo'));
});
test('revocación del operador detiene pasos posteriores', async () => {
  const e = entorno(); await e.start(); e.advance();
  e.put('usuarios/super', {...e.data.get('usuarios/super'), activo: false});
  await assert.rejects(e.step()); assert.ok(e.accounts.has('exclusivo'));
});
test('rechaza asociaciones inconsistentes y mantiene otras membresías', () => {
  assert.throws(() => clasificar('a', {rol: 'admin', clubIds: ['demo'], clubPrincipal: 'guemes'}, 'demo', 's'));
  assert.equal(clasificar('a', {rol: 'admin', clubIds: ['demo', 'guemes'], clubPrincipal: 'guemes'}, 'demo', 's').tipo, 'compartida');
});
