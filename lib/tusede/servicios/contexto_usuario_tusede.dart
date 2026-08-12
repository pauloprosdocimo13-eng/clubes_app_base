import '../modelos/usuario_tusede.dart';

class ContextoUsuarioTuSede {
  ContextoUsuarioTuSede._();

  static UsuarioTuSede? _usuarioActual;

  static bool get estaInicializado {
    return _usuarioActual != null;
  }

  static bool get hayUsuario {
    return _usuarioActual != null;
  }

  static UsuarioTuSede? get usuarioActualNullable {
    return _usuarioActual;
  }

  static UsuarioTuSede get usuarioActual {
    final usuario = _usuarioActual;

    if (usuario == null) {
      throw StateError('No existe un usuario TuSede cargado actualmente.');
    }

    return usuario;
  }

  static String get uid {
    return usuarioActual.uid;
  }

  static String get nombre {
    return usuarioActual.nombre;
  }

  static String get rol {
    return usuarioActual.rol;
  }

  static bool get esSuperAdmin {
    return usuarioActual.esSuperAdmin;
  }

  static void establecerUsuario(UsuarioTuSede usuario) {
    _usuarioActual = usuario;
  }

  static void limpiar() {
    _usuarioActual = null;
  }
}
