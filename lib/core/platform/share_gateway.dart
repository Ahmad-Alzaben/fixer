import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Copy-to-clipboard and native share sheet, behind an interface so the
/// UI can be tested without platform plugins (Adapter).
abstract interface class ShareGateway {
  Future<void> copy(String text);

  /// [origin] is the on-screen rectangle of the button that opened the share
  /// sheet. iPad requires it to position the popover; phones ignore it.
  Future<void> share(String text, {String? subject, Rect? origin});
}

class PlatformShareGateway implements ShareGateway {
  const PlatformShareGateway();

  @override
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<void> share(String text, {String? subject, Rect? origin}) =>
      SharePlus.instance.share(
        ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
      );
}

final shareGatewayProvider = Provider<ShareGateway>(
  (ref) => const PlatformShareGateway(),
);
