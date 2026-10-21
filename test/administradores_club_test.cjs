const {test} = require('node:test');
const assert = require('node:assert/strict');
const {asignarAdministrador, listarAdministradores, validarAdministrador, uidAdministrador} =
  require('../functions_tusede/administradores_club');

// Doble de Auth/Firestore: sin credenciales ni escrituras remotas.
function entorno() {
  const datos = new Map([
    ['usuarios/super', {rol: 'superadmin', activo: true}],
    ['clubes/club-prueba', {origenDatos: 'central', estado: 'activo', activo: true}],
    ['clubes/otro-club', {origenDatos: 'central', estado: 'borrador', activo: false}],
  ]);
  const cuentas = new Map();
  let creadas = 0;
  let falloTransaccion = false;
  let antesTransaccion;
  const snapshot = path => ({exists: datos.has(path), id: path.split('/').at(-1), data: () => datos.get(path)});
  let cola = Promise.resolve();
  const db = {
    doc: path => ({path, get: async () => snapshot(path)}),
    collection: name => ({where: (key, op, valor) => ({get: async () => ({docs:
      [...datos.keys()].filter(path => path.startsWith(name + '/') &&
        datos.get(path)[key]?.includes(valor)).map(snapshot),
    })})}),
    runTransaction(fn) {
      const siguiente = cola.then(async () => {
        if (antesTransaccion) antesTransaccion();
        if (falloTransaccion) { falloTransaccion = false; throw new Error('Firestore no disponible'); }
        const pendientes = [];
        const resultado = await fn({
          get: async ref => snapshot(ref.path),
          create: (ref, value) => {
            assert.equal(datos.has(ref.path), false, 'create no sobrescribe');
            pendientes.push([ref.path, value]);
          },
        });
        pendientes.forEach(([k, v]) => datos.set(k, v));
        return resultado;
      });
      cola = siguiente.catch(() => {});
      return siguiente;
    },
  };
  const errorAuth = code => Object.assign(new Error(code), {code});
  const auth = {
    getUserByEmail: async email => {
      if (!cuentas.has(email)) throw errorAuth('auth/user-not-found');
      return cuentas.get(email);
    },
    createUser: async data => {
      if (cuentas.has(data.email)) throw errorAuth('auth/email-already-exists');
      assert.ok(data.password.length >= 32);
      creadas++;
      const user = {uid: data.uid, email: data.email, disabled: false};
      cuentas.set(data.email, user);
      return user;
    },
  };
  const entrada = {clubId: 'club-prueba', nombre: 'Ana Pérez', email: 'ana@club.org'};
  return {datos, cuentas, entrada,
    alta: (cambios = {}, actorUid = 'super') => asignarAdministrador({
      db, auth, actorUid, datos: {...entrada, ...cambios}, serverTimestamp: () => 'fecha-servidor',
    }),
    lista: (clubId = 'club-prueba', actorUid = 'super') => listarAdministradores({db, actorUid, clubId}),
    creadas: () => creadas,
    fallar: () => { falloTransaccion = true; },
    antes: fn => { antesTransaccion = fn; },
  };
}

test('normaliza email y descarta rol, UID y clubes inyectados', () => {
  const e = entorno();
  assert.deepEqual(validarAdministrador({...e.entrada, email: ' Ana@Club.org ', rol: 'superadmin',
    uid: 'super', clubIds: ['generico']}), e.entrada);
});
test('rechaza correo ficticio, datos malformados y rutas', () => {
  const e = entorno();
  for (const email of ['admin@club.test', 'a@example.com', 'a@b.invalid', 'mal', 'a b@club.org']) {
    assert.throws(() => validarAdministrador({...e.entrada, email}));
  }
  assert.throws(() => validarAdministrador({...e.entrada, clubId: '../usuarios'}));
  assert.throws(() => validarAdministrador({...e.entrada, nombre: ''}));
});
test('alta fija admin, un solo club y auditoría; no expone contraseña', async () => {
  const e = entorno();
  const resultado = await e.alta({rol: 'superadmin', clubIds: ['generico']});
  const perfil = e.datos.get('usuarios/' + resultado.uid);
  assert.equal(perfil.rol, 'admin');
  assert.deepEqual(perfil.clubIds, ['club-prueba']);
  assert.equal(perfil.clubPrincipal, 'club-prueba');
  assert.equal(perfil.creadoPor, 'super');
  assert.equal(perfil.password, undefined);
  assert.equal(resultado.password, undefined);
  assert.equal(e.datos.get('auditoria_plataforma/alta_' + resultado.uid).actorUid, 'super');
});
test('deniega al admin de club, al superadmin inactivo y a una sesión ausente', async () => {
  for (const actor of [undefined, {rol: 'admin', activo: true}, {rol: 'superadmin', activo: false}]) {
    const e = entorno();
    if (actor) e.datos.set('usuarios/actor', actor);
    await assert.rejects(e.alta({}, 'actor'), {status: 403});
    await assert.rejects(e.lista('club-prueba', 'actor'), {status: 403});
    assert.equal(e.creadas(), 0);
  }
});
test('rechaza Legacy, club inexistente e inactivo antes de crear Auth', async () => {
  const e = entorno();
  e.datos.set('clubes/guemes', {activo: true, origenDatos: 'central'});
  e.datos.set('clubes/inactivo', {activo: false, origenDatos: 'central', estado: 'inactivo'});
  for (const clubId of ['guemes', 'no-existe', 'inactivo']) {
    await assert.rejects(e.alta({clubId}), {status: 400});
  }
  assert.equal(e.creadas(), 0);
});
test('no adopta cuentas existentes ni modifica al superadmin', async () => {
  const e = entorno();
  e.cuentas.set(e.entrada.email, {uid: 'super', email: e.entrada.email});
  await assert.rejects(e.alta(), {status: 409});
  assert.equal(e.datos.get('usuarios/super').rol, 'superadmin');
  assert.equal(e.creadas(), 0);
});
test('reintentos y altas simultáneas conservan un único perfil y auditoría', async () => {
  const e = entorno();
  const resultados = await Promise.all([e.alta(), e.alta()]);
  assert.equal(e.creadas(), 1);
  assert.equal(resultados[0].uid, resultados[1].uid);
  assert.equal(resultados.filter(r => r.yaExistia).length, 1);
  assert.equal([...e.datos.keys()].filter(k => k.startsWith('auditoria_plataforma/')).length, 1);
});
test('fallo entre Auth y perfil se recupera con el mismo email sin conceder acceso previo', async () => {
  const e = entorno(); e.fallar();
  await assert.rejects(e.alta(), /Firestore no disponible/);
  const uid = uidAdministrador(e.entrada.clubId, e.entrada.email);
  assert.equal(e.datos.has('usuarios/' + uid), false);
  const resultado = await e.alta();
  assert.equal(resultado.uid, uid);
  assert.equal(e.creadas(), 1);
});
test('rechaza asignar el mismo correo a otro club y no amplía permisos', async () => {
  const e = entorno(); const r = await e.alta();
  await assert.rejects(e.alta({clubId: 'otro-club'}), {status: 409});
  assert.deepEqual(e.datos.get('usuarios/' + r.uid).clubIds, ['club-prueba']);
});
test('rechaza cuentas deshabilitadas y perfiles modificados sin reactivarlos', async () => {
  const e = entorno(); const r = await e.alta();
  e.cuentas.get(e.entrada.email).disabled = true;
  await assert.rejects(e.alta(), {status: 409});
  e.cuentas.get(e.entrada.email).disabled = false;
  e.datos.get('usuarios/' + r.uid).rol = 'superadmin';
  await assert.rejects(e.alta(), {status: 409});
  assert.equal(e.datos.get('usuarios/' + r.uid).rol, 'superadmin');
});
test('revocación del operador durante el alta impide crear perfil', async () => {
  const e = entorno();
  e.antes(() => e.datos.set('usuarios/super', {rol: 'superadmin', activo: false}));
  await assert.rejects(e.alta(), {status: 403});
  assert.equal(e.datos.has('usuarios/' + uidAdministrador(e.entrada.clubId, e.entrada.email)), false);
});
test('listado devuelve únicamente administradores del club y campos de presentación', async () => {
  const e = entorno(); await e.alta();
  await e.alta({clubId: 'otro-club', email: 'otra@club.org'});
  const listado = await e.lista();
  assert.equal(listado.length, 1);
  assert.equal(listado[0].email, 'ana@club.org');
  assert.deepEqual(Object.keys(listado[0]).sort(), ['activo', 'email', 'nombre', 'uid']);
});
