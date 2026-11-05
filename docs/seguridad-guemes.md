# Seguridad Güemes: publicación coordinada

Estado: cambios preparados, NO desplegados. Backend y Firestore verificados localmente; PHP/Storage pendientes de validación en su entorno (ver abajo). Datos de Güemes permanecen en club-guemes-2. No migrar a TuSede ni cambiar sus reglas como parte de esta publicación.

## Cambios

- Reglas explícitas sin acceso general de lectura/escritura. Socios, caja, auditoría, reservas y permisos dejan de ser públicos.
- Cuenta Auth sola no autoriza: requiere permisos_admin/{email}, rol reconocido y activo distinto de false. Los documentos antiguos sin activo siguen habilitados.
- Matriz configuracion/permisos_roles aplicada en servidor. Sin entrada para el rol se usan los mismos permisos predeterminados de AdminPermisos. Solo admin cambia roles/matriz.
- Auditoría de socios: solo alta, con UID autenticado y fecha de servidor, sin edición posterior.
- Carnet y disponibilidad/reservas pasan por endpoints exclusivos del proyecto/club. Nunca devolver domicilio, teléfono personal, correo, notas ni documentos originales. Se mantienen precios y medios públicos de pago.
- Votación de figura: servicio transaccional, solo incrementa un candidato existente de una votación abierta; token local evita duplicados del mismo dispositivo y hay límite por IP.
- Egresos Güemes: autorización por rol y confirmación, sin contraseña compartida. Otros Legacy mantienen su mecanismo anterior.

## Orden de publicación (requiere coordinación)

1. Confirmar una cuenta existente con rol admin en permisos_admin/{email}, probar roles delegados y revisar la matriz con el club.
2. Publicar solamente los nuevos endpoints, conservando las reglas actuales durante la transición:

```powershell
firebase deploy --only functions:buscarCarnetGuemes,functions:reservasGuemes,functions:votarFiguraGuemes,functions:entretenimientoGuemes,functions:autorizarImagenGuemes --project club-guemes-2 --config firebase.guemes-seguridad.json
```

3. Probar los endpoints de Güemes y luego actualizar web y Android: carnet/familia, reservas, votación, rifas y Prode ahora necesitan esos endpoints. Los builds ya publicados no los usan. No recompilar/publicar desde Codex salvo petición del usuario.
4. Cuando Android actualizado esté disponible y se haya coordinado el cambio, publicar las reglas:

```powershell
firebase deploy --only firestore:rules --project club-guemes-2 --config firebase.guemes-seguridad.json
```

5. Verificar desde sesión anónima y cuentas reales. Las apps antiguas perderán el acceso directo a carnet/reservas y el voto anterior será rechazado. Subir solamente la web NO completa la seguridad. No ejecutar un deploy general de funciones ni cambiar la firma.

## Pruebas

- node --test test/portal_guemes_test.cjs (sanitización, aislamiento de proyecto/club, límites, disponibilidad sin PII, campos de reserva y votos).
- Con emulador 127.0.0.1:8185 y dependencias de test/reglas: node --test test/reglas/seguridad_guemes_test.cjs test/reglas/fechas_legacy_test.cjs.
- Las pruebas mock del backend no sustituyen probar permisos IAM, índices y endpoints desplegados. Las de reglas ejecutan Firestore Emulator real.

## Límites de esta etapa

No es una auditoría completa del sistema ni de Hostinger/Storage. El carnet sigue consultándose por DNI con límite de intentos: un DNI no prueba identidad; una segunda etapa debe agregar una credencial individual (por ejemplo enlace o PIN) si se quiere autenticar al socio. No se afirma que el token de voto sea una identidad personal: borrar datos/cambiar de dispositivo puede permitir nuevos votos.

Las colecciones de contenido público mantienen lectura directa salvo sorteos y prode_votos: ahora solo personal autorizado puede leer sus documentos completos. Rifas entrega campos públicos mediante entretenimientoGuemes y actualiza disponibilidad cada 30 segundos. Prode usa un token aleatorio privado del dispositivo; el servicio valida partidos, goles enteros, fecha abierta y duplicados transaccionalmente, y fija puntos iniciales en cero. No es una identidad personal: borrar los datos del navegador/app permite otro token. Sugerencias conserva alta pública acotada; lectura solo admin. Los contadores de límite necesitan configurar TTL sobre expira_en para evitar acumulación.

No borrar la clave de egresos histórica hasta terminar la transición; ahora solo administradores pueden consultar el documento de seguridad.


## Imágenes: Storage y Hostinger

- Las reglas entregadas de Storage eran lectura y escritura universal. `storage.guemes.rules` conserva GET público para no cortar fotos existentes, pero bloquea listados y toda escritura directa, incluso autenticada. Admin SDK no depende de esas reglas. No equivale a privatizar las imágenes existentes ni sustituye revisar los archivos del bucket.
- El código actual de Güemes sube por PHP, no directamente al bucket. TuSede conserva su circuito autenticado y su proyecto; no desplegar estas reglas en TuSede.
- `tool/hostinger-guemes/subir_foto.php` requiere token Firebase vigente/no revocado y permiso de módulo comprobados por `autorizarImagenGuemes`. La verificación usa el Admin SDK con checkRevoked, siguiendo https://firebase.google.com/docs/auth/admin/manage-sessions . No hay claves compartidas en el cliente ni credenciales de servicio en PHP.
- El PHP limita a 4 MB, JPG/PNG/WebP, dimensiones hasta 4096 por lado y 16 millones de píxeles; recodifica con GD y genera nombres aleatorios exclusivos, sin usar DNI/nombres del archivo recibido. Las fotos anteriores se conservan. Imágenes subidas siguen siendo públicas por URL.
- Requisitos Hostinger: PHP 8+, cURL, fileinfo, GD y salida HTTPS al endpoint; `upload_max_filesize` al menos 4M y `post_max_size` mayor a 4M. Asegurar que Authorization llegue a PHP. Si no llega, ajustar configuración del hosting; nunca quitar la validación para resolverlo.
- Copiar el PHP a `public_html/api/subir_foto.php` e integrar `uploads.htaccess` en `public_html/uploads/.htaccess`, conservando reglas anteriores. Probar en una ruta de ensayo antes del reemplazo. No se instalaron archivos en Hostinger desde esta sesión.
- Probar rechazo sin token (401), con cuenta inactiva/sin permiso (403), archivo ejecutable/no imagen (400), archivo mayor de 4 MB (413), y foto válida desde web y Android. Verificar que fotos antiguas siguen visibles y una segunda subida no reemplaza la primera. Confirmar que la regla .htaccess realmente impide ejecución de scripts en el servidor usado.
- Las apps Android anteriores no envían token al PHP; dejar planificada la actualización antes de reemplazarlo. Actualizar solo la web deja a los administradores con Android antiguo sin poder subir fotos.

Después de revisar el uso del bucket y probar los cambios, el comando exclusivo de Storage es:

```powershell
firebase deploy --only storage --project club-guemes-2 --config firebase.guemes-seguridad.json
```

No ejecutar un deploy general. Conservar copia del PHP previo para diagnóstico, pero no reabrir escritura pública como solución permanente.

## Transición del Prode

El identificador antiguo del dispositivo era predecible y aparecía en documentos públicos: no se usa como prueba de propiedad para recuperar un voto. Los votos previos se conservan para el administrador, pero no se vinculan automáticamente al nuevo token del participante. Hacer la transición entre fechas del Prode, después de cerrar/liquidar la fecha actual. El historial administrativo no se elimina. Conservar el almacenamiento de la app/navegador para poder consultar los nuevos pronósticos propios.

## Validación de esta etapa

- `node --test test/entretenimiento_guemes_test.cjs test/portal_guemes_test.cjs`: 10 pruebas de backend (dependencias simuladas).
- Firestore Emulator: 9 pruebas de privacidad, permisos, revocación, fechas y escrituras públicas rechazadas. Los tests usan proyectos demo locales, no datos reales.
- Análisis de los cinco archivos Dart modificados; sin errores, con avisos de estilo heredados.
- No hay PHP instalado en el entorno local: el PHP fue revisado pero no ejecutado. No se ejecutó Storage Emulator. Ambas validaciones quedan pendientes antes de publicación; no confundirlas con los tests de Firestore.
