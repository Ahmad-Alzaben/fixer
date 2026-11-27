import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a WhatsApp/SMS link in the matching app (Adapter over
/// url_launcher, so widget tests can capture the link instead).
abstract interface class MessageLauncher {
  /// False if no app could open the link.
  Future<bool> open(Uri uri);
}

class UrlMessageLauncher implements MessageLauncher {
  const UrlMessageLauncher();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}

final messageLauncherProvider = Provider<MessageLauncher>(
  (ref) => const UrlMessageLauncher(),
);
