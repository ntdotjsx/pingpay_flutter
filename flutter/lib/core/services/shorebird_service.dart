import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

final shorebirdUpdaterProvider = Provider<ShorebirdUpdater>((ref) {
  return ShorebirdUpdater();
});

final shorebirdServiceProvider = Provider<ShorebirdService>((ref) {
  final updater = ref.watch(shorebirdUpdaterProvider);
  return ShorebirdService(updater);
});

class ShorebirdService {
  final ShorebirdUpdater _updater;

  ShorebirdService(this._updater);

  /// Checks whether Shorebird Code Push is available on the current platform/build
  bool get isShorebirdAvailable => _updater.isAvailable;

  /// Gets the currently installed patch number (if any)
  Future<int?> getCurrentPatchNumber() async {
    if (!isShorebirdAvailable) return null;
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      debugPrint('[Shorebird] Error getting current patch: $e');
      return null;
    }
  }

  /// Checks for OTA update and downloads it seamlessly in the background
  Future<bool> checkForUpdatesInBackground() async {
    if (!isShorebirdAvailable) {
      debugPrint('[Shorebird] Code Push is unavailable in debug / non-shorebird build.');
      return false;
    }

    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        debugPrint('[Shorebird] New patch available! Downloading in background...');
        await _updater.update();
        debugPrint('[Shorebird] New patch downloaded successfully. It will apply on next restart.');
        return true;
      } else if (status == UpdateStatus.restartRequired) {
        debugPrint('[Shorebird] Patch downloaded and ready. Restart required to apply.');
        return true;
      } else {
        debugPrint('[Shorebird] App is up to date ($status).');
      }
    } catch (e) {
      debugPrint('[Shorebird] Error checking/downloading update: $e');
    }
    return false;
  }
}

