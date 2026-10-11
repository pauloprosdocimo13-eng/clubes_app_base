import 'package:flutter_test/flutter_test.dart';
import 'package:clubes_app_base/tusede/modelos/club_tusede.dart';
import 'package:clubes_app_base/tusede/servicios/contexto_club.dart';
import 'package:clubes_app_base/tusede/servicios/servicio_datos_club.dart';

void main() {
  tearDown(ContextoClub.limpiar);
  test(
    'Club nuevo usa Central por origen explícito y conserva su identidad',
    () {
      final club = ClubTuSede.fromMap('club-nuevo', {
        'nombre': 'Club Nuevo',
        'origenDatos': 'central',
        'activo': true,
        'identidad': {
          'colorPrimario': '#123ABC',
          'logoUrl': 'https://example.com/logo.png',
        },
      });
      ContextoClub.cambiarClub(club);
      expect(ServicioDatosClub.usaTuSedeCentral, isTrue);
      expect(ContextoClub.clubId, 'club-nuevo');
      expect(club.logoUrl, 'https://example.com/logo.png');
      expect(club.toMap()['origenDatos'], 'central');
      expect(club.copyWith(nombre: 'Otro nombre').origenDatos, 'central');
    },
  );
  test('Cambiar desde Central a Güemes conserva el origen Legacy', () {
    ContextoClub.cambiarClub(
      ClubTuSede.fromMap('club-nuevo', {'origenDatos': 'central'}),
    );
    expect(ServicioDatosClub.usaTuSedeCentral, isTrue);
    ContextoClub.cambiarClub(
      ClubTuSede.fromMap('guemes', {'nombre': 'Güemes'}),
    );
    expect(ServicioDatosClub.usaTuSedeCentral, isFalse);
  });
}
