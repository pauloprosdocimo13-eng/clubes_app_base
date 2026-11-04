# Accesos directos por club — Android

En TuSede Android aparece **Agregar al inicio** en cada tarjeta del catálogo. Dentro del club, **Agregar mi club al inicio** y **Cambiar club** están en el menú de tres puntos de la barra compacta (48 px). Se solicita al lanzador fijar un acceso con nombre y escudo. El usuario debe confirmarlo; la app no informa éxito definitivo solo porque Android aceptó la solicitud. Si ya existe el mismo acceso, actualiza su nombre/ícono sin solicitar otro.

Implementado para Android 8+ (API26) y lanzadores que admiten requestPinShortcut. No aparece en web, iPhone ni dispositivos incompatibles. No instala otra app. Al desinstalar TuSede, el acceso deja de servir.

- El intent contiene solamente el identificador del club, con componente Android explícito. No se agregaron filtros públicos de enlaces ni permisos nuevos.
- Al tocar el acceso se consulta el catálogo público actual; solo se abre un club Central activo. Si fue eliminado/desactivado se ofrece volver al catálogo; si no hay conexión, reintentar.
- Contempla inicio en frío y onNewIntent cuando la app está abierta. Al cambiar se desmonta la navegación anterior antes de configurar el nuevo club.
- El acceso no inicia sesión, cambia roles ni habilita permisos. La administración mantiene sus controles existentes.
- El escudo se descarga por HTTPS con límites de tiempo/tamaño y se reduce a un ícono. Si falla, se usa el ícono de TuSede y se informa al usuario.
- No hay soporte offline del contenido ni actualización automática de íconos remotos. Volver a usar el botón actualiza un acceso existente.
- La apertura normal conserva el catálogo como inicio; si Android entrega un nuevo intent MAIN, vuelve al catálogo. El comportamiento de traer una tarea ya abierta al frente depende del lanzador.

## Prueba en teléfono

No hay deploy de Firebase. Requiere recompilar Android: hot reload o la app web no incluyen Kotlin nuevo.

Con un teléfono Android conectado y depuración USB habilitada:

```powershell
flutter run --debug --flavor generico --target lib/main_tusede.dart
```

También se puede generar un APK de prueba:

```powershell
flutter build apk --debug --flavor generico --target lib/main_tusede.dart
```

Esto utiliza la firma de depuración, sin cambiar la configuración release ni la firma pendiente de recuperar. Si el teléfono ya tiene el mismo paquete firmado con otra clave, Android rechazará la actualización. No desinstalar automáticamente una app con datos locales; utilizar otro dispositivo de prueba o esperar la firma adecuada.

Comprobar:

1. Abrir Naon, tocar el botón, confirmar en Android y ver nombre/escudo.
2. Cerrar la app y tocar el ícono: debe ir directamente a Naon.
3. Crear otro acceso, entrar a un club y tocar el acceso del otro: debe cambiar correctamente, sin conservar pantallas del anterior.
4. Tocar Cambiar club y navegar normalmente al catálogo; comprobar también apertura desde el ícono general.
5. Repetir el botón del mismo club: actualizar el acceso sin duplicarlo (el lanzador decide la posición).
6. Cancelar la confirmación del sistema: no debe afirmarse que se instaló.
7. Sin conexión: mostrar error recuperable. Club de prueba eliminado: mostrar que ya no está disponible.
8. Verificar acceso público sin sesión y controles administrativos intactos.

Validación realizada: pruebas Flutter de canal, IDs/publicación, navegación fría/caliente, club ausente y reintento; compilación directa Kotlin contra Android36/Flutter. El build Gradle completo no pudo verificarse en este entorno: finalizó al iniciar el build sin diagnóstico de compilación. No se generó ni instaló un APK. Falta prueba física del lanzador.

Referencia: [API de accesos directos Android](https://developer.android.com/reference/android/content/pm/ShortcutManager).
