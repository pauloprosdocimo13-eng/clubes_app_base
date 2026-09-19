import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clubes_app_base/servicios/actividades_baja_socio.dart';

Map<String, dynamic> baja(Map<String, dynamic> datos, DateTime fecha) => {
  ...datos,
  ...cambiosActividadesBaja(datos, fecha: fecha),
  'eliminado': true,
};

Map<String, dynamic> restaurar(
  Map<String, dynamic> datos,
  DateTime fecha,
  bool reinscribir,
) => {
  ...datos,
  ...cambiosActividadesRestauracion(
    datos,
    reinscribir: reinscribir,
    fecha: fecha,
  ),
  'eliminado': false,
};

void main() {
  final original = <String, dynamic>{
    'actividades': ['Cuota Social', 'Fútbol'],
    'ultimo_mes_pago': '2026-01',
  };

  test(
    'el movimiento identifica meses deportivos reales, no meses de baja',
    () {
      final socio = restaurar(
        baja(original, DateTime(2026, 3)),
        DateTime(2026, 7),
        true,
      );
      expect(mesesDeActividad(socio, 'Fútbol', DateTime(2026, 2), 6), [
        '2026-02',
        '2026-03',
        '2026-07',
      ]);
      expect(mesesDeActividad(socio, 'Fútbol', DateTime(2026, 4), 3), isEmpty);
    },
  );

  test('deuda previa + solo social en la baja + deportes al reinscribir', () {
    final eliminado = baja(original, DateTime(2026, 3, 15));
    final socio = restaurar(eliminado, DateTime(2026, 7, 20), true);
    expect(mesesPorActividad(socio, DateTime(2026, 2), 6), {
      'Cuota Social': 6,
      'Fútbol': 3,
    });
    // Social 100, fútbol 200: febrero/marzo 600 + abril/junio 300 + julio 300.
    final cantidades = mesesPorActividad(socio, DateTime(2026, 2), 6);
    expect(
      cantidades['Cuota Social']! * 100 + cantidades['Fútbol']! * 200,
      1200,
    );
    expect(socio['ultimo_mes_pago'], '2026-01');
    expect(eliminado['actividades'], isEmpty);
    expect(eliminado['actividad'], 'Cuota Social');
  });

  test('no reinscribir nunca perdona la deuda deportiva previa', () {
    final socio = restaurar(
      baja(original, DateTime(2026, 3)),
      DateTime(2026, 7),
      false,
    );
    expect(socio['actividades'], isEmpty);
    expect(mesesPorActividad(socio, DateTime(2026, 2), 6), {
      'Cuota Social': 6,
      'Fútbol': 2,
    });
    expect(actividadesParaMes(socio, DateTime(2026, 7)), ['Cuota Social']);
  });

  test('pago parcial mueve el inicio sin volver a cobrar meses cancelados', () {
    final socio = restaurar(
      baja(original, DateTime(2026, 3)),
      DateTime(2026, 7),
      true,
    );
    socio['ultimo_mes_pago'] = '2026-03';
    expect(primerMesPendiente(socio, DateTime(2026, 7)), DateTime(2026, 4));
    expect(mesesPorActividad(socio, DateTime(2026, 4), 4), {
      'Cuota Social': 4,
      'Fútbol': 1,
    });
  });

  test(
    'mes ya devengado se conserva al dar de baja y no se duplica al restaurar',
    () {
      final socio = restaurar(
        baja(original, DateTime(2026, 3, 10)),
        DateTime(2026, 3, 20),
        true,
      );
      expect(mesesPorActividad(socio, DateTime(2026, 3), 1), {
        'Cuota Social': 1,
        'Fútbol': 1,
      });
    },
  );

  test('durante la baja la deuda anterior persiste y solo crece la social', () {
    final socio = baja(original, DateTime(2026, 3));
    expect(mesesPorActividad(socio, DateTime(2026, 2), 5), {
      'Cuota Social': 5,
      'Fútbol': 2,
    });
  });

  test('múltiples bajas conservan actividades de cada período', () {
    var socio = restaurar(
      baja(original, DateTime(2026, 3)),
      DateTime(2026, 7),
      true,
    );
    socio['actividades'] = ['Cuota Social', 'Patín'];
    socio = restaurar(
      baja(socio, DateTime(2026, 8)),
      DateTime(2026, 11),
      false,
    );
    expect(mesesPorActividad(socio, DateTime(2026, 2), 10), {
      'Cuota Social': 10,
      'Fútbol': 2,
      'Patín': 2,
    });
    expect(historialBajas(socio), hasLength(2));
  });

  test(
    'baja con último pago adelantado no genera deuda deportiva anterior',
    () {
      final socio = restaurar(
        baja({...original, 'ultimo_mes_pago': '2026-05'}, DateTime(2026, 3)),
        DateTime(2026, 7),
        true,
      );
      expect(
        mesesPorActividad(
          socio,
          primerMesPendiente(socio, DateTime(2026, 7)),
          2,
        ),
        {'Cuota Social': 2, 'Fútbol': 1},
      );
    },
  );

  test('cambio de año y períodos sin deuda', () {
    final socio = restaurar(
      baja(original, DateTime(2026, 11)),
      DateTime(2027, 2),
      true,
    );
    expect(mesesPorActividad(socio, DateTime(2026, 11), 4), {
      'Cuota Social': 4,
      'Fútbol': 2,
    });
    expect(mesesPorActividad(socio, DateTime(2027, 3), 0), isEmpty);
    expect(mesesPorActividad(socio, DateTime(2027, 3), -2), isEmpty);
  });

  test('Legacy sin historial usa eliminado_en y actividad singular', () {
    final socio = restaurar(
      {
        'actividad': 'Fútbol + Patín',
        'eliminado': true,
        'eliminado_en': Timestamp.fromDate(DateTime(2026, 3, 5)),
        'ultimo_mes_pago': '2026-01',
      },
      DateTime(2026, 7),
      false,
    );
    expect(mesesPorActividad(socio, DateTime(2026, 2), 6), {
      'Fútbol': 2,
      'Patín': 2,
      'Cuota Social': 4,
    });
  });

  test('respaldo vacío tiene prioridad sobre actividad antigua', () {
    expect(
      actividadesAntesBaja({
        'actividades_antes_baja': [],
        'actividad': 'Fútbol',
      }),
      isEmpty,
    );
    expect(
      actividadesSocio({'actividades': [], 'actividad': 'Fútbol'}),
      isEmpty,
    );
    expect(
      actividadesSocio({'actividad': ' Fútbol, Patín + Fútbol, Ninguna '}),
      ['Fútbol', 'Patín'],
    );
  });

  test('sin pagos se conserva el inicio incluso meses después de la baja', () {
    var socio = baja({'actividad': 'Fútbol'}, DateTime(2026, 3));
    socio = restaurar(socio, DateTime(2026, 7), false);
    expect(primerMesPendiente(socio, DateTime(2026, 7)), DateTime(2026, 3));
    expect(mesesPorActividad(socio, DateTime(2026, 3), 5), {
      'Fútbol': 1,
      'Cuota Social': 4,
    });
  });

  test('fecha de alta determina inicio si no hay último pago', () {
    final socio = baja({
      'actividad': 'Fútbol',
      'fecha_alta': Timestamp.fromDate(DateTime(2026, 1, 8)),
    }, DateTime(2026, 3));
    expect(primerMesPendiente(socio, DateTime(2026, 7)), DateTime(2026, 1));
  });

  test('no se muta el historial original ni se escribe último pago', () {
    final socio = baja(original, DateTime(2026, 3));
    final cambios = cambiosActividadesRestauracion(
      socio,
      reinscribir: false,
      fecha: DateTime(2026, 7),
    );
    expect(historialBajas(socio).last.containsKey('mes_restauracion'), isFalse);
    expect(cambios.containsKey('ultimo_mes_pago'), isFalse);
    expect(
      cambiosActividadesBaja(original).containsKey('ultimo_mes_pago'),
      isFalse,
    );
  });

  test('registros sin baja conservan el cálculo de actividades existente', () {
    expect(mesesPorActividad(original, DateTime(2026, 2), 6), {
      'Cuota Social': 6,
      'Fútbol': 6,
    });
    expect(mesesPorActividad({'actividad': 'Ninguna'}, DateTime(2026, 2), 1), {
      'Cuota Social': 1,
    });
  });
}
