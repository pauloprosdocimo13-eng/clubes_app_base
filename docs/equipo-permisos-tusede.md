# Equipo y permisos por club (TuSede Central)

Los administradores gestionan cuentas de trabajo desde Gestión de Usuarios. Roles: Tesorería, Administración, Deportes, Comunicación y Control de ingreso. La Matriz de Permisos pertenece al club actual y se aplica también en Firestore y en la subida de imágenes, no solamente en los botones.

## Despliegue

Desde la raíz del repositorio, en PowerShell. Publicar reglas antes de habilitar las nuevas cuentas:

```powershell
firebase deploy --only firestore:rules --project tu-sede-app --config firebase.tusede.json
$env:FUNCTIONS_DISCOVERY_TIMEOUT = "60"
firebase deploy --only "functions:tusede:administrarPlataforma,functions:tusede:subirImagenTuSede" --project tu-sede-app --config firebase.tusede.json
```

Reiniciar la aplicación con los cambios de Flutter. No hace falta recuperar la firma Android para probar en web. Estos comandos no se ejecutaron automáticamente durante el desarrollo.

## Prueba manual

1. Entrar como administrador de un club Central y guardar su Matriz de Permisos. Si todavía no existe, se ofrecen permisos iniciales por rol. Revisarlos antes de guardar.
2. Abrir Gestión de Usuarios, crear una cuenta con un correo nuevo y accesible y elegir el rol. La creación no envía correo automáticamente.
3. Pulsar Enviar enlace y confirmar; el titular establece su contraseña.
4. Entrar en incógnito con esa cuenta: verificar los módulos asignados, lectura, escritura y fotos. Probar que otro club y la administración global no estén disponibles.
5. Cambiar el rol desde la sesión administradora y volver a entrar al panel para actualizar sus botones.
6. Desactivar la cuenta y comprobar que la sesión anterior ya no puede leer ni modificar datos protegidos. Reactivar si corresponde.

Los administradores, superadministradores y perfiles compartidos/importados se muestran protegidos. No se permite elevar una cuenta a administrador desde esta pantalla. Desactivar quita acceso mediante el perfil; no borra la cuenta global de Authentication ni sus datos. No se muestran contraseñas y no se reutilizan correos pertenecientes a otras cuentas.

## Alcance y migración

Las reglas nuevas requieren una matriz guardada para los roles de trabajo. Los administradores conservan acceso. Preparar la matriz de cada club que ya tenga personal antes de probar con sus cuentas. Una matriz ausente no otorga permisos por defecto en el servidor.

Prode, votación, streaming y pizarra táctica no se ofrecen para delegación en Central en esta entrega: sus rutas antiguas requieren migración aparte. Güemes conserva su conexión y gestión Legacy. Asignar un permiso no habilita un módulo desactivado en el club.

Si la creación de Authentication termina pero falla el guardado del perfil, esa cuenta no tiene acceso: corregir el problema y reintentar con el mismo correo permite completar el alta.

## Pruebas locales

```powershell
node --test test/equipo_club_test.cjs
flutter test --no-pub test/pantalla_equipo_club_test.dart
npm ci --prefix test/reglas
firebase emulators:exec --only firestore --project demo-equipo --config firebase.equipo-test.json "node --test test/reglas/equipo_rules_test.cjs"
```

El test de reglas exige el emulador local en 127.0.0.1:8185 y utiliza el proyecto demo-equipo. No conectarlo a producción. Requiere Java compatible con Firebase Emulator.
