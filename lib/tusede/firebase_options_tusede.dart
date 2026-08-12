import 'package:firebase_core/firebase_core.dart';

class FirebaseOptionsTuSede {
  FirebaseOptionsTuSede._();

  // ============================================================
  // FIREBASE CENTRAL TUSEDE - ANDROID
  // ============================================================
  //
  // Esta configuración pertenece al proyecto:
  // tu-sede-app
  //
  // NO reemplaza al Firebase actual de Güemes.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCY2GcpvdPQ6qf5OXJce-4sI20toRaRvVM',
    appId: '1:22406792089:android:5fb86e6f1ba37e1bca0908',
    messagingSenderId: '22406792089',
    projectId: 'tu-sede-app',
    storageBucket: 'tu-sede-app.firebasestorage.app',
  );

  // ============================================================
  // FIREBASE CENTRAL TUSEDE - WEB
  // ============================================================

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBCFGr5USl4W0rwCGlCpKX1wU1Qpl3okdA',
    appId: '1:22406792089:web:47bd882b2587e7a7ca0908',
    messagingSenderId: '22406792089',
    projectId: 'tu-sede-app',
    authDomain: 'tu-sede-app.firebaseapp.com',
    storageBucket: 'tu-sede-app.firebasestorage.app',
  );
}
