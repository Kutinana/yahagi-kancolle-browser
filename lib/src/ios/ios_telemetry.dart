import 'package:flutter/services.dart';
import 'package:telemetrydecksdk/telemetrydecksdk.dart';

/// Avoids Flutter SDK 4's reserved TelemetryDeck.SDK.* default parameters.
/// The native SDK supplies its own metadata; app telemetry remains unchanged.
Future<void> startIOSTelemetry(TelemetryManagerConfiguration configuration) =>
    const MethodChannel(
      'telemetrydecksdk',
    ).invokeMethod<void>('start', configuration.toMap());
