import 'package:flutter_test/flutter_test.dart';
import 'package:clubes_app_base/tusede/modelos/usuario_tusede.dart';

void main() {
  test('Administrador provisionado no obtiene acceso a otros clubes', () {
    final usuario = UsuarioTuSede.fromMap('uid-prueba', {
      'nombre': 'Administrador',
      'email': 'admin@club.org',
      'rol': 'admin',
      'activo': true,
      'clubPrincipal': 'club-prueba',
      'clubIds': ['club-prueba'],
    });
    expect(usuario.tieneAccesoAClub('club-prueba'), isTrue);
    expect(usuario.tieneAccesoAClub('generico'), isFalse);
    expect(usuario.tieneAccesoAClub('guemes'), isFalse);
    expect(usuario.esSuperAdmin, isFalse);
    expect(
      usuario.copyWith(activo: false).tieneAccesoAClub('club-prueba'),
      isFalse,
    );
  });
}
