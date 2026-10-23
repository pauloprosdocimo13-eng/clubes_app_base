# Marca TuSede

La cancha es la identidad de TuSede. La interfaz usa azul petróleo #0B1F27 y menta #B7F6CC.

- `marca.svg`: versión vectorial horizontal, también publicada en `web/tusede_logo.svg`.
- `launcher_icon.png`: icono opaco, con margen para recortes del sistema.
- `splash_icon.png`: símbolo transparente para el arranque nativo.
- La geometría de la cancha se comparte con `PintorCanchaTuSede` en Flutter.

Para regenerar PNG, iconos web/Android y splash Android, desde la raíz:

```powershell
flutter test --no-pub tool/generar_marca_tusede.dart
```

Este generador escribe solamente assets de TuSede, web y Android `generico`. No ejecutar el generador global de launcher icons para este cambio: puede procesar otros flavors.

Para probar:
- Web: reiniciar `flutter run` y recargar con Ctrl+F5 para renovar HTML, manifest e iconos.
- APK: recompilar la variante `generico` usando `lib/main_tusede.dart` e instalar la actualización. Hot restart no reemplaza recursos nativos.
- Acceso instalado desde navegador: tras publicar, el sistema puede conservar el icono anterior; si persiste, quitar el acceso y volver a agregarlo.

Los recursos Android están generados, pero este cambio no incluye compilación ni instalación de un APK. No hay una variante iOS TuSede configurada en este proyecto; no se modificaron los recursos iOS compartidos de otros clubes. El icono web/apple-touch sí fue actualizado.
