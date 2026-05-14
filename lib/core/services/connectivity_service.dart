import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  Stream<bool> get isConnectedStream => Connectivity().onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
}
