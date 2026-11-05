# Fechas de ingresos: Güemes y TuSede

La pantalla compartida usa el permiso `Cambiar fecha de ingresos`. Administradores conservan acceso; los demás roles necesitan ese permiso en la matriz, además de `Caja y Finanzas` para operar caja. No se les otorgan otros privilegios administrativos.

## Configuración desde el panel

Abrir Matriz de Permisos → TESORERIA → marcar Caja y Finanzas y Cambiar fecha de ingresos → Guardar cambios. Volver a entrar a Caja. Repetir por club en TuSede. La misma casilla permite delegar o revocar el permiso a cualquier otro rol existente. Crear roles nuevos aún no está implementado: la lista de roles continúa siendo fija.

Las matrices existentes se respetan: no se agregan privilegios automáticamente. Las matrices nuevas incluyen el permiso en los valores iniciales de tesorería. En Güemes, si no existe entrada de tesorería, se aplica el mismo valor predeterminado tanto en cliente como en reglas. Central siempre requiere una matriz guardada.

El permiso se consulta al abrir Caja y nuevamente al guardar, desde el servidor. Las reglas también lo verifican en cada escritura y rechazan fechas de otro día si se revocó el permiso, aunque el cliente fuera antiguo o estuviera manipulado. Sin permiso, los ingresos usan serverTimestamp y el día argentino (UTC-3). Si no se puede consultar la matriz, se limita a la fecha actual.

La fecha contable se separa de fecha_registro, que permanece con hora de servidor. No se pueden alterar fecha_registro, admin_uid o admin_email. Delegar fecha no permite cambiar el tipo de ingreso a egreso ni viceversa. Los cobros de socios siguen usando timestamp del servidor.

## Publicación pendiente

No se desplegaron reglas ni apps ni se modificaron matrices en producción. Esta modificación comparte archivos con la etapa de seguridad todavía pendiente: seguir primero el plan de docs/seguridad-guemes.md. No publicar las reglas completas de Güemes aisladamente: ahora también protegen carnet, reservas, rifas y Prode y requieren los servicios/clientes actualizados. Los clientes antiguos que no envían fecha_registro en ingresos manuales serán rechazados.

Luego de coordinar esa transición, las configuraciones son firebase.guemes-seguridad.json (club-guemes-2) y firebase.tusede.json (tu-sede-app). Las compilaciones siguen separadas: main_guemes.dart/flavor guemes y main_tusede.dart/flavor generico. Firma y versiones Android sin cambios.

## Verificación

- Probar tesorería sin la casilla: solo hoy.
- Habilitarla y guardar un ingreso de ayer: fecha contable de ayer, fecha_registro actual.
- Delegarla a otro rol que tenga Caja y Finanzas; comprobar que no obtiene administración.
- Revocarla y volver a intentar con la misma sesión; el servidor rechaza fechas anteriores.
- Repetir en Güemes y un club Central; comprobar que no habilita otros clubes.

Tests: test/reglas/fechas_legacy_test.cjs, test/reglas/equipo_rules_test.cjs y test/reglas/seguridad_guemes_test.cjs. Ejecutados contra emulador local 127.0.0.1:8185, 20 pruebas aprobadas.
