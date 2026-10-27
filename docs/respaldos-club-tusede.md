# Respaldos y recuperación por club — TuSede Central

## Qué hace

El superadmin encuentra **Respaldos** en la barra del panel y **Respaldar club** en el menú de cada club Central. El historial funciona incluso cuando el club original fue eliminado. Solo se permite recuperar en un **identificador nuevo**, reservado para esa operación. La recuperación termina como **borrador inactivo**. No sobrescribe clubes existentes ni reutiliza identificadores eliminados.

Incluye todos los documentos y subcolecciones de `clubes/{id}` (también descendientes cuyo documento padre falta), con tipos Firestore preservados, y los objetos actuales de `clubes/{id}/` en el bucket Central. Los archivos se copian a un bucket privado independiente. No se usan enlaces públicos para descargar respaldos.

No incluye Authentication, contraseñas, perfiles globales `usuarios`, auditoría global, migraciones, configuraciones externas ni el proyecto Legacy de Güemes. Al recuperar se omiten `configuracion/permisos_roles` y `configuracion/seguridad`, incluidos sus descendientes: configurar nuevamente matriz y claves, y asignar administradores. Las fotos propias reciben rutas y tokens nuevos. Las URL externas se conservan como enlaces, sin copiar su contenido.

## Instalación (una vez)

**No ejecutado durante el desarrollo.** El proyecto predeterminado de Firebase puede ser Güemes: mantener siempre `--project tu-sede-app --config firebase.tusede.json`.

### 1. PowerShell, en la raíz del repositorio

Publicar primero las reglas que bloquean escritura/lectura de un club mientras se recupera. Después publicar solamente la nueva función:

```powershell
firebase deploy --only firestore:rules --project tu-sede-app --config firebase.tusede.json
$env:FUNCTIONS_DISCOVERY_TIMEOUT = "60"
firebase deploy --only functions:tusede:administrarRespaldos --project tu-sede-app --config firebase.tusede.json
```

### 2. Cloud Shell, después del deploy

Crear el bucket **nuevo**, con acceso uniforme y prevención de acceso público. No agregarlo como bucket público ni crear tokens de descarga. Si informa que el nombre ya existe, verificar que pertenece a este proyecto antes de seguir; no cambiar permisos de un bucket ajeno.

```bash
gcloud storage buckets create gs://tu-sede-app-respaldos --project=tu-sede-app --location=southamerica-east1 --uniform-bucket-level-access --public-access-prevention

TUSEDE_RESPALDOS_SA="$(gcloud functions describe administrarRespaldos --project=tu-sede-app --region=southamerica-east1 --gen2 --format='value(serviceConfig.serviceAccountEmail)')"
```

Verificar que la variable contiene la cuenta de servicio de la función (no un correo personal). Luego otorgarle lectura/creación de objetos y lectura de metadatos **solo en el bucket de respaldos**:

```bash
test -n "$TUSEDE_RESPALDOS_SA" && gcloud storage buckets add-iam-policy-binding gs://tu-sede-app-respaldos --member="serviceAccount:$TUSEDE_RESPALDOS_SA" --role=roles/storage.objectCreator
test -n "$TUSEDE_RESPALDOS_SA" && gcloud storage buckets add-iam-policy-binding gs://tu-sede-app-respaldos --member="serviceAccount:$TUSEDE_RESPALDOS_SA" --role=roles/storage.objectViewer
test -n "$TUSEDE_RESPALDOS_SA" && gcloud storage buckets add-iam-policy-binding gs://tu-sede-app-respaldos --member="serviceAccount:$TUSEDE_RESPALDOS_SA" --role=roles/storage.legacyBucketReader
```

La función utiliza la cuenta predeterminada de Functions Gen2. Debe tener acceso a Firestore Central y lectura/creación de objetos en el bucket original, como el backend existente. Si se usa una cuenta de ejecución distinta, revisar esos permisos específicamente (Firestore `roles/datastore.user`, objetos del bucket original `roles/storage.objectViewer` y `roles/storage.objectCreator`). No otorgar permisos sobre Güemes.

No hace falta publicar `administrarPlataforma` ni modificar reglas de Storage de las fotos existentes. No hay una configuración `storage.rules` nueva que reemplace permisos del bucket principal.

### 3. Reiniciar Flutter y comprobar

1. Entrar como superadmin y abrir Respaldos.
2. Elegir un club de prueba que tenga un socio y una foto; crear el respaldo y esperar **completado**.
3. Recuperarlo como `naon-recuperado` (u otro ID nuevo) y repetir el identificador en la confirmación.
4. Comprobar el borrador en Administración de clubes. Revisar logo/configuración, asignar administrador y activar **solo la copia de prueba** para revisar sus módulos y registros.
5. Confirmar que documentos, fecha/valores y fotos se conservan; que el club original no cambió; y que los usuarios antiguos no obtuvieron acceso a la copia.
6. Probar cerrar el panel durante una operación y usar **Retomar**. No crear otra recuperación con diferente ID para retomar la misma.
7. Una copia recuperada puede eliminarse desde el flujo normal, sin borrar su respaldo. Mantener el club en uso intacto durante esta prueba.

## Integridad, límites y operación

- Firestore se lee usando un único `readTime` para documento raíz, colecciones y páginas. No es un export administrado global de Firebase.
- Storage se enumera y copia por generación; verifica tamaño y MD5, y usa validación CRC32C durante el guardado. El manifiesto tiene SHA-256. Si una foto referenciada propia falta o una generación desaparece, la copia no se marca completa.
- Firestore y Storage **no comparten una transacción**. Para un punto de recuperación operativo claro, pedir que no se carguen o eliminen datos/imágenes mientras se hace la copia. Si falla por cambios, generar un respaldo nuevo.
- Límite inicial: 500 documentos visitados (incluidos padres sin campos), 10 MB de manifiesto, 100 archivos, 16 MB por archivo y 256 MB totales. Si se excede, falla explícitamente: no ofrece una recuperación parcial como completa. Clubes mayores requieren ampliar el procesamiento o un respaldo asistido.
- La copia de documentos dura como máximo unos minutos; los archivos y la recuperación se procesan por pasos reanudables. Tras una interrupción abrupta puede ser necesario esperar **10 minutos** a que venza el bloqueo de un paso.
- Un fallo de recuperación deja el destino inactivo y bloqueado. Retomar la misma operación. No activar, borrar manualmente ni editar sus documentos durante la recuperación.
- Los respaldos y las operaciones incompletas se conservan; esta versión no incluye purga automática ni programación. Hay consumo de lecturas/escrituras y almacenamiento. No es protección contra eliminación completa del proyecto o pérdida de su cuenta de Google.
- Las políticas de soft delete/retención de Google Cloud son independientes. No se borran ni cambian desde la app.

## Verificación de desarrollo

```powershell
node --test test/respaldos_club_test.cjs test/respaldo_adaptador_test.cjs
flutter test --no-pub test/pantalla_respaldos_club_test.dart
npm ci --prefix test/reglas
firebase emulators:exec --only firestore --project demo-equipo --config firebase.equipo-test.json "node --test test/reglas/equipo_rules_test.cjs test/reglas/respaldos_integracion_test.cjs"
```

El test de integración exige 127.0.0.1:8185 y usa exclusivamente el proyecto emulado `demo-respaldo`. Comprueba el commit real de recuperación, tipos y padres ausentes. El emulador REST no soporta `readTime`: solo en el transporte del test se omite ese parámetro. La prueba del adaptador comprueba que producción lo envía en todas las páginas. Cloud Storage se prueba con dobles, incluyendo corrupción y generaciones; queda pendiente el ensayo real del bucket tras instalar.

Referencias: [lecturas históricas de documentos](https://docs.cloud.google.com/firestore/docs/reference/rest/v1/projects.databases.documents/listDocuments), [roles de Cloud Storage](https://docs.cloud.google.com/storage/docs/access-control/iam-roles).
