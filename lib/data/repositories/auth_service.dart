import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../../core/utils/preferences_helper.dart';

class AuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  /// Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if device supports any authentication (biometric or device credentials)
  Future<bool> isAuthenticationAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } catch (e) {
      return false;
    }
  }
  
  /// Get available biometric types (fingerprint, face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
  
  /// Authenticate user with biometric or device credentials
  Future<bool> authenticate() async {
    try {
      // Check if device has any authentication method available
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics && !isDeviceSupported) {
        return false; // Return false to show proper error message
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your item vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/Pattern/Password as fallback
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );

      return authenticated;
    } on PlatformException catch (e) {
      // Handle specific error codes
      if (e.code == 'NotAvailable') {
        return false;
      } else if (e.code == 'PasscodeNotSet' || e.code == 'NotEnrolled') {
        return false;
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        return false;
      } else if (e.code == 'UserCanceled' || e.code == 'SystemCanceled') {
        return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if app lock is enabled
  static bool isAppLockEnabled() {
    return PreferencesHelper.isAppLockEnabled();
  }
  
  /// Enable or disable app lock
  static Future<void> setAppLock(bool enabled) async {
    await PreferencesHelper.setAppLock(enabled);
  }
}
