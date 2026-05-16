import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/firebase_paths.dart';

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  Future<({bool required, String? storeUrl})> checkUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final doc = await FirebaseFirestore.instance
          .collection(FirebasePaths.config)
          .doc(FirebasePaths.appSettings)
          .get();

      if (!doc.exists) {
        return (required: false, storeUrl: null);
      }

      final data = doc.data()!;
      final isAndroid = Platform.isAndroid;

      final minimumVersion =
          (isAndroid
                  ? data['minimumAndroidVersion']
                  : data['minimumIosVersion'])
              as String? ??
          '0.0.0';

      final storeUrl =
          (isAndroid ? data['androidStoreUrl'] : data['iosStoreUrl'])
              as String?;

      final required = _isBelow(info.version, minimumVersion);
      return (required: required, storeUrl: required ? storeUrl : null);
    } catch (_) {
      return (required: false, storeUrl: null);
    }
  }

  bool _isBelow(String installed, String minimum) {
    final installedTuple = _parse(installed);
    final minimumTuple = _parse(minimum);

    for (int i = 0; i < 3; i++) {
      if (installedTuple[i] < minimumTuple[i]) {
        return true;
      }
      if (installedTuple[i] > minimumTuple[i]) {
        return false;
      }
    }

    return false;
  }

  List<int> _parse(String version) {
    final parts = version.split('.');

    return List.generate(3, (index) {
      if (index >= parts.length) {
        return 0;
      }
      return int.tryParse(parts[index]) ?? 0;
    });
  }
}
