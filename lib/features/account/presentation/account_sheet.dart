import 'package:flutter/material.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/features/account/presentation/change_password_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/analytics/consent_providers.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/providers/theme_mode_provider.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_avatar.dart';
import 'package:mynotes/core/theme/widgets/notely_dialog.dart';
import 'package:mynotes/core/theme/widgets/notely_sheet.dart';
import 'package:mynotes/features/account/presentation/trash_view.dart';
import 'package:mynotes/features/backup/backup_view.dart';
import 'package:mynotes/features/reminders/reminder_providers.dart';
import 'package:mynotes/features/account/presentation/archived_notes_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';
import 'package:mynotes/features/study/presentation/review_view.dart';
import 'package:mynotes/features/study/providers/study_providers.dart';

class AccountSheet extends ConsumerWidget {
  final AuthUser? authUser;
  const AccountSheet({super.key, this.authUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notely = NotelyTheme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    // Null until loaded: rows show nothing rather than a made-up "0".
    final due = ref.watch(dueCountProvider(_uid(ref))).valueOrNull;
    final notes = ref.watch(notesProvider(_uid(ref))).valueOrNull;
    final archivedCount = notes?.where((n) => n.isArchived && !n.isTrashed).length;
    final trashCount = notes?.where((n) => n.isTrashed).length;
    final consent = ref.watch(consentStatusProvider).valueOrNull;
    final user = authUser ?? _currentUser(ref);

    String consentDetail() => switch (consent) {
          null => 'Not asked',
          true => 'On',
          false => 'Off',
        };

    String appearanceLabel() => switch (themeMode) {
          ThemeMode.light => 'Light',
          ThemeMode.dark => 'Dark',
          ThemeMode.system => 'System',
        };

    return NotelySheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              NotelyAvatar(size: 44, initial: _initialOf(user)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName?.isNotEmpty == true ? user.displayName! : user.email.split('@').first,
                      style: TextStyle(fontFamily: 'Geist', fontSize: 16, fontWeight: FontWeight.w500, color: notely.text),
                    ),
                    const SizedBox(height: 2),
                    Text(user.email, style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: notely.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.lock_outline, size: 16, color: notely.text2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your notes are encrypted on this device before they sync. Only you and the people you share with can read them.',
                  style: TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.text2),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _JoinRequestsSection(uid: _uid(ref)),
          _SheetRow(
            icon: Icons.contrast,
            label: 'Appearance',
            detail: appearanceLabel(),
            onTap: () {
              final next = themeMode == ThemeMode.light ? ThemeMode.dark : (themeMode == ThemeMode.dark ? ThemeMode.system : ThemeMode.light);
              ref.read(themeModeProvider.notifier).set(next);
            },
          ),
          _SheetRow(
            icon: Icons.style_outlined,
            label: 'Study',
            detail: due == null ? null : (due == 0 ? 'Nothing due' : '$due due'),
            onTap: () => _push(context, (c) => ReviewView(authUser: user)),
          ),
          _SheetRow(
            icon: Icons.archive_outlined,
            label: 'Archive',
            detail: archivedCount?.toString(),
            onTap: () => _push(context, (c) => ArchivedNotesView(authUser: user)),
          ),
          _SheetRow(
            icon: Icons.delete_outline,
            label: 'Trash',
            detail: trashCount?.toString(),
            onTap: () => _push(context, (c) => TrashView(authUser: user)),
          ),
          _SheetRow(
            icon: Icons.save_alt,
            label: 'Backup',
            detail: 'Export or import',
            onTap: () => _push(context, (c) => BackupView(authUser: user)),
          ),
          if (user.hasPassword)
            _SheetRow(
              icon: Icons.password_outlined,
              label: 'Change password',
              onTap: () => _push(context, (c) => ChangePasswordView(authUser: user)),
            ),
          _SheetRow(
            icon: Icons.insights_outlined,
            label: 'Usage analytics',
            detail: consentDetail(),
            onTap: () => _showConsentDialog(context, ref),
          ),
          const SizedBox(height: 8),
          _SheetRow(
            icon: Icons.logout,
            label: 'Sign out',
            danger: true,
            last: true,
            onTap: () {
              Navigator.of(context).pop();
              ref.read(reminderServiceProvider).cancelAll();
              ref.read(authServiceProvider).logOut();
            },
          ),
        ],
      ),
    );
  }

  String _uid(WidgetRef ref) {
    final u = authUser ?? _currentUser(ref);
    return u.uid;
  }

  AuthUser _currentUser(WidgetRef ref) {
    final cached = ref.read(authStateProvider).valueOrNull;
    return cached ?? const AuthUser(uid: '', email: '', isEmailVerified: false);
  }

  String _initialOf(AuthUser user) {
    final name = user.displayName?.isNotEmpty == true ? user.displayName!.split(' ').first : user.email.split('@').first;
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
  }

  void _push(BuildContext context, Widget Function(BuildContext) builder) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }
}

Future<void> _showConsentDialog(BuildContext context, WidgetRef ref) async {
  final current = ref.read(consentStatusProvider).valueOrNull;
  final granting = current == true;
  final decision = await showNotelyDialog<bool>(
    context: context,
    title: granting ? 'Turn off usage analytics?' : 'Allow usage analytics?',
    message: 'Anonymous usage data helps improve Notely. It never includes your notes or anything you type.',
    actions: [
      NotelyDialogAction(
        label: granting ? 'Keep on' : 'No thanks',
        onPressed: () => Navigator.of(context).pop(!granting),
      ),
      NotelyDialogAction(
        label: granting ? 'Turn off' : 'Allow',
        isPrimary: true,
        onPressed: () => Navigator.of(context).pop(granting ? false : true),
      ),
    ],
  );
  if (decision == null) return;
  await ref.read(consentCoordinatorProvider).recordDecision(decision);
  ref.invalidate(consentStatusProvider);
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;
  final bool danger;
  final bool last;

  const _SheetRow({
    required this.icon,
    required this.label,
    this.detail,
    required this.onTap,
    this.danger = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    final color = danger ? notely.danger : notely.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: notely.border)),
        ),
        child: Row(children: [
          SizedBox(width: 20, child: Icon(icon, size: 18, color: danger ? notely.danger : notely.text2)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontFamily: 'Geist', fontSize: 15, color: color))),
          if (detail != null)
            Text(
              detail!,
              style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text3, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          if (!danger) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: notely.text3),
          ],
        ]),
      ),
    );
  }
}

class _JoinRequestsSection extends ConsumerWidget {
  final String uid;
  const _JoinRequestsSection({required this.uid});

  Future<void> _run(BuildContext context, Future<void> Function() action, String failure) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      messenger.showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notely = NotelyTheme.of(context);
    final requests = (ref.watch(ownerJoinRequestsProvider(uid)).valueOrNull ?? const [])
        .where((r) => r.status == 'pending')
        .toList();
    if (requests.isEmpty) return const SizedBox.shrink();
    // Titles are end-to-end encrypted, so resolve them from our own notes.
    final notes = ref.watch(notesProvider(uid)).valueOrNull ?? const [];
    String titleOf(String noteId) =>
        notes.where((n) => n.id == noteId).firstOrNull?.displayTitle ?? 'a note';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Join requests',
            style: TextStyle(fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.w500, color: notely.text2),
          ),
        ),
        ...requests.map(
          (request) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            decoration: BoxDecoration(
              color: notely.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: notely.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.recipientName.isEmpty ? request.recipientEmail : request.recipientName} wants to join',
                  style: TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w500, color: notely.text),
                ),
                const SizedBox(height: 2),
                Text(
                  titleOf(request.noteId),
                  style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: notely.text3),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _run(
                        context,
                        () => ref.read(shareServiceProvider).approveJoinRequest(
                              ownerUid: uid,
                              token: request.token,
                              recipientUid: request.recipientUid,
                            ),
                        "Couldn't approve the request.",
                      ),
                      child: const Text('Approve'),
                    ),
                    TextButton(
                      onPressed: () => _run(
                        context,
                        () => ref.read(shareServiceProvider).denyJoinRequest(
                              token: request.token,
                              recipientUid: request.recipientUid,
                            ),
                        "Couldn't decline the request.",
                      ),
                      style: TextButton.styleFrom(foregroundColor: notely.text2),
                      child: const Text('Decline'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
