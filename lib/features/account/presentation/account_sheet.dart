import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/analytics/consent_providers.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/providers/theme_mode_provider.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/theme/widgets/notely_avatar.dart';
import 'package:mynotes/core/theme/widgets/notely_sheet.dart';
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
    final due = ref.watch(dueCountProvider(_uid(ref))).valueOrNull ?? 0;
    final archivedCount = ref.watch(notesProvider(_uid(ref))).valueOrNull?.where((n) => n.isArchived).length ?? 0;
    final consent = ref.watch(consentStatusProvider).valueOrNull;
    final user = authUser ?? _currentUser(ref);

    String consentDetail() => switch (consent) {
          null => 'Not asked',
          true => 'Analytics on',
          false => 'Analytics off',
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
              NotelyAvatar(size: 48, initial: _initialOf(user)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName?.isNotEmpty == true ? user.displayName! : user.email.split('@').first, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: notely.text)),
                    const SizedBox(height: 1),
                    Text(user.email, style: TextStyle(fontSize: 13, color: notely.text3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: notely.surface2, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.cloud_done_outlined, size: 15, color: const Color(0xFF059669)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Synced to Firestore', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: notely.text)),
                  const SizedBox(height: 1),
                  Text('Last sync · just now', style: TextStyle(fontSize: 11.5, color: notely.text3)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _JoinRequestsSection(uid: _uid(ref)),
          _SheetRow(
            icon: Icons.brightness_6_outlined,
            label: 'Appearance',
            detail: appearanceLabel(),
            onTap: () {
              final next = themeMode == ThemeMode.light ? ThemeMode.dark : (themeMode == ThemeMode.dark ? ThemeMode.system : ThemeMode.light);
              ref.read(themeModeProvider.notifier).set(next);
            },
          ),
          _SheetRow(
            icon: Icons.school_outlined,
            label: 'Study cards',
            detail: '$due',
            onTap: () => _push(context, (c) => ReviewView(authUser: user)),
          ),
          _SheetRow(
            icon: Icons.archive_outlined,
            label: 'Archive',
            detail: '$archivedCount',
            onTap: () => _push(context, (c) => const ArchivedNotesView()),
          ),
          _SheetRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Analytics & privacy',
            detail: consentDetail(),
            onTap: () => _showConsentDialog(context, ref),
          ),
          _SheetRow(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            danger: true,
            onTap: () {
              Navigator.of(context).pop();
              ref.read(authServiceProvider).logOut();
            },
          ),
        ],
      ),
    );
  }

  String _uid(WidgetRef ref) {
    final u = _currentUser(ref);
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
  final decision = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(granting ? 'Turn off analytics?' : 'Allow analytics?'),
      content: const Text(
        'Allow anonymous usage data to help improve Notely? '
        'This never includes your notes or anything you type.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(!granting),
          child: Text(granting ? 'Keep on' : 'No thanks'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(granting),
          child: Text(granting ? 'Turn off' : 'Allow'),
        ),
      ],
    ),
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

  const _SheetRow({required this.icon, required this.label, this.detail, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: notely.border))),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: danger ? const Color(0xFFDC2626).withValues(alpha: 0.1) : notely.violetSoft, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: danger ? const Color(0xFFDC2626) : notely.violetInk),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, letterSpacing: -0.2, color: danger ? const Color(0xFFDC2626) : notely.text))),
          if (detail != null) Text(detail!, style: TextStyle(fontSize: 13, color: notely.text3)),
          Icon(Icons.chevron_right, size: 14, color: notely.text4),
        ]),
      ),
    );
  }
}

class _JoinRequestsSection extends ConsumerWidget {
  final String uid;
  const _JoinRequestsSection({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notely = NotelyTheme.of(context);
    final requests = ref.watch(ownerJoinRequestsProvider(uid)).valueOrNull ?? const [];
    if (requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Join requests',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: notely.text3,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        ...requests.map(
          (request) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: notely.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.recipientName.isEmpty ? request.recipientEmail : request.recipientName} wants to join',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '"${request.noteTitle}"',
                  style: TextStyle(fontSize: 12, color: notely.text3),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await ref.read(shareServiceProvider).approveJoinRequest(
                              ownerUid: uid,
                              token: request.token,
                              recipientUid: request.recipientUid,
                            );
                      },
                      child: const Text('Approve'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(shareServiceProvider).denyJoinRequest(
                              token: request.token,
                              recipientUid: request.recipientUid,
                            );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text('Deny'),
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
