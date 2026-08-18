import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Sensitivity level enum: low (hard pull), medium (default), high (easy pull)
enum PullSensitivity {
  easy(100.0, 'ดึงน้อย (100px)'),
  medium(160.0, 'ปานกลาง (160px)'),
  deep(240.0, 'ดึงลึกมาก (240px)');

  final double threshold;
  final String label;

  const PullSensitivity(this.threshold, this.label);
}

final pullSensitivityProvider =
    StateNotifierProvider<PullSensitivityNotifier, PullSensitivity>((ref) {
      return PullSensitivityNotifier();
    });

class PullSensitivityNotifier extends StateNotifier<PullSensitivity> {
  static const _key = 'pull_sensitivity_threshold';

  PullSensitivityNotifier() : super(PullSensitivity.deep) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt(_key);
      if (savedIndex != null &&
          savedIndex >= 0 &&
          savedIndex < PullSensitivity.values.length) {
        state = PullSensitivity.values[savedIndex];
      }
    } catch (_) {}
  }

  Future<void> setSensitivity(PullSensitivity sensitivity) async {
    state = sensitivity;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, sensitivity.index);
    } catch (_) {}
  }
}
