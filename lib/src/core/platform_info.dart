import 'dart:io' show Platform;

import 'package:meta/meta.dart';

import 'scraper_exceptions.dart';

/// Reports which platform the code is running on.
///
/// This exists so the Android/iOS gate can be exercised in tests. In 1.x the
/// gate read `Platform.environment` looking for `FLUTTER_TEST` and skipped
/// itself when it found it — which shipped test awareness inside production
/// code and left the gate itself with no coverage at all. Injecting the lookup
/// removes both problems: production uses [PlatformInfo.current], tests pass a
/// [FakePlatformInfo].
abstract class PlatformInfo {
  /// Const constructor for subclasses.
  const PlatformInfo();

  /// The real platform, as reported by `dart:io`.
  static const PlatformInfo current = _DartIoPlatformInfo();

  /// Lowercase operating system name, e.g. `android`, `ios`, `macos`.
  String get operatingSystem;

  /// Whether the host is Android.
  bool get isAndroid;

  /// Whether the host is iOS.
  bool get isIOS;

  /// Whether this package supports the host.
  ///
  /// Android and iOS only — see `platforms:` in `pubspec.yaml`.
  bool get isSupported => isAndroid || isIOS;

  /// Throws [UnsupportedPlatformException] unless the host is supported.
  void requireSupported() {
    if (!isSupported) {
      throw UnsupportedPlatformException(operatingSystem);
    }
  }
}

class _DartIoPlatformInfo extends PlatformInfo {
  const _DartIoPlatformInfo();

  @override
  String get operatingSystem => Platform.operatingSystem;

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIOS => Platform.isIOS;
}

/// A [PlatformInfo] that reports whatever it is told to.
///
/// Exposed (rather than hidden in `test/`) so consumers can exercise their own
/// error handling for the unsupported-platform path.
@visibleForTesting
class FakePlatformInfo extends PlatformInfo {
  /// Creates a fake reporting [operatingSystem].
  const FakePlatformInfo(this.operatingSystem);

  /// A fake reporting Android.
  const FakePlatformInfo.android() : operatingSystem = 'android';

  /// A fake reporting iOS.
  const FakePlatformInfo.ios() : operatingSystem = 'ios';

  @override
  final String operatingSystem;

  @override
  bool get isAndroid => operatingSystem == 'android';

  @override
  bool get isIOS => operatingSystem == 'ios';
}
