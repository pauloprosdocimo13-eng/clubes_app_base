const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test} = require('node:test');

// Evalúa el módulo real, sin inicializar Firebase ni ejecutar el endpoint.
const builder = {
  region() { return this; },
  runWith() { return this; },
  https: {onRequest(handler) { return handler; }},
};
const context = vm.createContext({
  exports: {},
  require(name) {
    if (name === 'firebase-functions/v1') return builder;
    if (name === 'firebase-admin/app') return {getApps: () => [{}]};
    if (name === 'firebase-admin/firestore') return {getFirestore: () => ({})};
    if (name === 'crypto') return require('node:crypto');
    throw new Error(`Dependencia inesperada: ${name}`);
  },
});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../functions_tusede/carnet_publico.js'), 'utf8'), context);
const clean = (data) => JSON.parse(JSON.stringify(context.sanitizarSocio(data, 'socio', '1234', true)));

test('portal conserva períodos y omite datos administrativos del historial', () => {
  const data = clean({
    ultimo_mes_pago: '2026-01', primer_mes_cobro: '2026-02',
    historial_actividades_baja: [{
      mes_baja: '2026-03', mes_restauracion: '2026-07',
      actividades: ['Cuota Social', 'Fútbol'],
      motivo: 'privado', admin_email: 'privado',
    }],
  });
  assert.equal(data.ultimo_mes_pago, '2026-01');
  assert.equal(data.primer_mes_cobro, '2026-02');
  assert.deepEqual(data.historial_actividades_baja, [{
    mes_baja: '2026-03', mes_restauracion: '2026-07',
    actividades: ['Cuota Social', 'Fútbol'],
  }]);
});

test('compatibilidad sin historial, actividad Legacy y respaldo vacío', () => {
  assert.deepEqual(clean({actividad: 'Fútbol + Patín'}).actividades, ['Fútbol', 'Patín']);
  assert.deepEqual(clean({actividades: [], actividad: 'Fútbol'}).actividades, []);
  assert.deepEqual(clean({}).historial_actividades_baja, []);
});

test('descarta períodos inválidos y permite bajas sin restaurar', () => {
  assert.deepEqual(clean({historial_actividades_baja: [
    null, {}, {mes_baja: '2026-13'}, {mes_baja: '2026-03', actividades: ['Fútbol']},
  ]}).historial_actividades_baja, [{
    mes_baja: '2026-03', mes_restauracion: null, actividades: ['Fútbol'],
  }]);
});
