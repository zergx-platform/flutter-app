import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import 'chat_avatar.dart';

/// WeChat-style relative timestamp (locale-aware).
String wechatTime(BuildContext context, String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) return I18n.isZh ? '' : context.l10n.timeJustNow;
  if (d.inMinutes < 60) {
    return context.l10n.timeMinAgo('${d.inMinutes}');
  }
  if (d.inHours < 24) return context.l10n.timeHour('${d.inHours}');
  if (d.inDays < 7) return context.l10n.timeDay('${d.inDays}');
  return '${dt.month}/${dt.day}';
}

/// WeChat-style chat-list row: avatar | name + relative time | preview +
/// unread badge. Reused by the home session list and the search results.
class SessionRow extends StatelessWidget {
  final Session session;
  final bool isActive;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const SessionRow({
    super.key,
    required this.session,
    required this.isActive,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final s = session;
    final unread = s.unreadCount ?? 0;
    final stamp =
        wechatTime(context, s.lastMessageAt.isNotEmpty ? s.lastMessageAt : s.updatedAt);
    return Material(
      color: isActive ? colors.primary.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              ChatAvatar(org: s.org, repo: s.repo, branch: s.branch, radius: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.org.isNotEmpty
                                ? '${s.org}/${s.repo}'
                                    '${s.branch.isNotEmpty ? '/${s.branch}' : ''}'
                                : s.id,
                            overflow: TextOverflow.ellipsis,
                            style: text.meta.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isActive ? colors.primary : null),
                          ),
                        ),
                        if (stamp.isNotEmpty)
                          Text(stamp,
                              style: text.micro
                                  .copyWith(color: colors.mutedForeground)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(subtitle,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: text.micro
                                  .copyWith(color: colors.mutedForeground)),
                        ),
                        if (unread > 0 && !isActive) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            constraints: const BoxConstraints(minWidth: 16),
                            decoration: BoxDecoration(
                              color: colors.destructive,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text('$unread',
                                style: text.micro.copyWith(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
