// lib/firebase_manual_options.dart
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;

class ManualFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isAndroid) {
      return const FirebaseOptions(
          apiKey: 'AIzaSyDDM-V3M9P3_6ACYpHiMb90c3KmgcznLt4',
          appId: '1:605574292104:android:3949de1c0ffca84ae2753d',
          messagingSenderId: '605574292104',
          projectId: 'manaquem-aa62e',
          storageBucket: 'manaquem-aa62e.firebasestorage.app',
      );
    } else if (Platform.isIOS) {
      return const FirebaseOptions(
          apiKey: 'AIzaSyDDM-V3M9P3_6ACYpHiMb90c3KmgcznLt4',
          appId: '1:605574292104:android:3949de1c0ffca84ae2753d',
          messagingSenderId: '605574292104',
          projectId: 'manaquem-aa62e',
          storageBucket: 'manaquem-aa62e.firebasestorage.app',
      );
    } else {
      throw UnsupportedError('This platform is not supported');
    }
  }
}
