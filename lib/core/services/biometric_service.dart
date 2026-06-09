import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      debugPrint('[BIOMETRICS] canCheckBiometrics: $canCheck, isDeviceSupported: $supported');
      return canCheck || supported;
    } catch (e) {
      debugPrint('[BIOMETRICS] isAvailable check failed: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> authenticate({
    required String reason,
    bool stickyAuth = true,
  }) async {
    try {
      debugPrint('[BIOMETRICS] Starting authentication: $reason');
      final result = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: false,
        ),
      );
      debugPrint('[BIOMETRICS] Authentication result: $result');
      return result;
    } catch (e) {
      debugPrint('[BIOMETRICS] Authentication exception: $e');
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics({
    required String reason,
    bool stickyAuth = true,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
