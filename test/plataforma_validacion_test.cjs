const {test} = require('node:test');
const assert = require('node:assert/strict');
const {validarAlta} = require('../functions_tusede/plataforma_validacion');
const alta = {id: 'club-nuevo', nombre: 'Club Nuevo', colorPrimario: '#123abc', colorSecundario: '#FFFFFF', modulos: ['socios', 'noticias']};
test('Alta central nace en borrador y no permite inyectar estado ni permisos', () => {
  const club = validarAlta({...alta, activo: true, estado: 'publicado', creadoPor: 'otro', rol: 'superadmin'});
  assert.equal(club.activo, false); assert.equal(club.estado, 'borrador');
  assert.equal(club.origenDatos, 'central'); assert.equal(club.identidad.colorPrimario, '#123ABC');
  assert.equal(club.modulos.socios, true); assert.equal(club.modulos.cuotas, false);
  assert.equal(club.creadoPor, undefined); assert.equal(club.rol, undefined);
});
test('Rechaza rutas, IDs reservados, módulos desconocidos y colores inválidos', () => {
  for (const id of ['guemes', 'generico', '../club', 'club/nuevo', 'Club']) assert.throws(() => validarAlta({...alta, id}));
  assert.throws(() => validarAlta({...alta, modulos: ['superadmin']}));
  assert.throws(() => validarAlta({...alta, colorPrimario: 'rojo'}));
});

const {validarEdicion} = require('../functions_tusede/plataforma_validacion');
test('Edición conserva logo y solo devuelve campos editables', () => {
  const anterior = {...validarAlta(alta), identidad: {logoUrl: 'https://example.com/logo.png'}};
  const cambios = validarEdicion({...alta, nombre: 'Nuevo Nombre', activo: true, origenDatos: 'legacy', identidad: {logoUrl: 'otro'}}, anterior);
  assert.equal(cambios.nombre, 'Nuevo Nombre');
  assert.equal(cambios.identidad.logoUrl, anterior.identidad.logoUrl);
  assert.deepEqual(Object.keys(cambios).sort(), ['identidad', 'modulos', 'nombre']);
});
test('Edición rechaza estado activo inconsistente, Legacy y datos inválidos', () => {
  const anterior = validarAlta(alta);
  assert.throws(() => validarEdicion(alta, {...anterior, estado: 'activo'}));
  assert.throws(() => validarEdicion(alta, {...anterior, origenDatos: 'legacy'}));
  assert.throws(() => validarEdicion({...alta, colorPrimario: 'incorrecto'}, anterior));
});

const {esClubCentralActivo, validarActivacion} = require('../functions_tusede/plataforma_validacion');
test('Catálogo y servicios excluyen borradores, inactivos y Legacy', () => {
  const borrador = validarAlta(alta);
  assert.equal(esClubCentralActivo('club-nuevo', borrador), false);
  assert.equal(esClubCentralActivo('club-nuevo', {...borrador, activo: true}), false);
  assert.equal(esClubCentralActivo('club-nuevo', {...borrador, activo: true, estado: 'activo'}), true);
  assert.equal(esClubCentralActivo('guemes', {activo: true}), false);
  assert.equal(esClubCentralActivo('generico', {activo: true}), true);
  assert.equal(esClubCentralActivo('club-nuevo', {...borrador, activo: false, estado: 'activo'}), false);
});
test('Activación exige borrador central, logo y módulos', () => {
  const borrador = validarAlta(alta);
  assert.throws(() => validarActivacion(alta.id, borrador));
  const listo = {...borrador, identidad: {...borrador.identidad, logoUrl: 'https://example.com/logo.png'}};
  assert.doesNotThrow(() => validarActivacion(alta.id, listo));
  assert.throws(() => validarActivacion(alta.id, {...listo, modulos: {}}));
  assert.throws(() => validarActivacion(alta.id, {...listo, estado: 'activo'}));
  assert.throws(() => validarActivacion('guemes', listo));
});


test('Edición de activo permite cambiar módulos sin alterar estado, logo ni origen', () => {
  const anterior = {...validarAlta(alta), estado: 'activo', activo: true};
  anterior.identidad.logoUrl = 'https://example.com/logo.png';
  const snapshot = JSON.stringify(anterior);
  const cambios = validarEdicion({...alta, modulos: ['jugadores', 'partidos'], activo: false, rol: 'superadmin'}, anterior);
  assert.equal(cambios.modulos.socios, false);
  assert.equal(cambios.modulos.jugadores, true);
  assert.equal(cambios.modulos.partidos, true);
  assert.equal(cambios.identidad.logoUrl, anterior.identidad.logoUrl);
  assert.deepEqual(Object.keys(cambios).sort(), ['identidad', 'modulos', 'nombre']);
  assert.equal(JSON.stringify(anterior), snapshot);
  assert.throws(() => validarEdicion({...alta, modulos: []}, anterior));
  assert.throws(() => validarEdicion({...alta, modulos: ['inventado']}, anterior));
  assert.throws(() => validarEdicion(alta, {...anterior, estado: 'suspendido'}));
  assert.throws(() => validarEdicion(alta, {...anterior, origenDatos: 'legacy'}));
});
