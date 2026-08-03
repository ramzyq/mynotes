import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/deeplinks/join_link_handler.dart';
import 'package:mynotes/core/deeplinks/pending_link_store.dart';
import 'package:mynotes/core/encryption/key_manager.dart';
import 'package:mynotes/features/collaboration/services/share_service.dart';

class JoinLinkProcessor {
  final ShareService shareService;
  final KeyManager keyManager;
  final AuthUser? Function() currentUser;
  final void Function(JoinResult) onResult;

  JoinLinkProcessor({
    required this.shareService,
    required this.keyManager,
    required this.currentUser,
    required this.onResult,
  });

  Future<void> handleUri(Uri uri) async {
    final token = JoinLinkHandler.tokenFromUri(uri);
    if (token == null) return;
    final user = currentUser();
    if (user == null || user.uid.isEmpty) {
      await PendingLinkStore.save(uri.toString());
      return;
    }
    await _process(token, user);
  }

  Future<void> processPending() async {
    final stored = await PendingLinkStore.read();
    if (stored == null) return;
    await PendingLinkStore.clear();
    final uri = Uri.tryParse(stored);
    if (uri == null) return;
    final token = JoinLinkHandler.tokenFromUri(uri);
    if (token == null) return;
    final user = currentUser();
    if (user == null || user.uid.isEmpty) return;
    await _process(token, user);
  }

  Future<void> _process(String token, AuthUser user) async {
    final publicKey = await keyManager.getMyPublicKey();
    final result = await shareService.joinSharedNote(
      uid: user.uid,
      token: token,
      recipientPublicKey: publicKey,
      recipientName: user.displayName ?? '',
      recipientEmail: user.email,
    );
    onResult(result);
  }
}
