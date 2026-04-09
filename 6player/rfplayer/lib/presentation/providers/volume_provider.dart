import 'package:flutter_riverpod/flutter_riverpod.dart';

class VolumeNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  void setVolume(double volume) {
    state = volume.clamp(0.0, 1.0);
  }
}

final volumeProvider = NotifierProvider<VolumeNotifier, double>(
  VolumeNotifier.new,
);
