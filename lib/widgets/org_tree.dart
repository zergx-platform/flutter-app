import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import 'chat_avatar.dart';

/// Persistent org → repo → bookmark tree used on the left of the Code tab.
/// The selected bookmark drives `store.openRepo`. Unlike the old bottom-sheet
/// picker, this stays inline (useful on tablets and as the phone's first
/// column), with each level expanding/collapsing in place.
class OrgTree extends StatefulWidget {
  final AppStore store;
  const OrgTree({super.key, required this.store});

  @override
  State<OrgTree> createState() => _OrgTreeState();
}

class _OrgTreeState extends State<OrgTree> {
  AppStore get store => widget.store;
  final Set<String> _openRepos = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (store.orgs.isEmpty) store.refreshRepos();
    });
  }

  String _keyRepo(OrgNode o, RepoNode r) => '${o.org}/${r.repo}';

  void _toggleRepo(OrgNode o, RepoNode r) {
    setState(() {
      final k = _keyRepo(o, r);
      if (_openRepos.contains(k)) {
        _openRepos.remove(k);
      } else {
        _openRepos.add(k);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    if (store.orgs.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => store.refreshRepos(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(context.l10n.noRepos,
                    style: TextStyle(color: colors.mutedForeground)),
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      children: [
        for (final o in store.orgs) _org(o, colors),
      ],
    );
  }

  Widget _org(OrgNode o, AppColors colors) {
    final text = textOf(context);
    return InkWell(
      onTap: () {
        // A repo with a single bookmark auto-opens; 0/#m is filtered so a
        // bare click on an org does nothing destructive.
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChatAvatar(org: o.org, repo: '', bookmark: o.org,
                    radius: 14, level: AvatarLevel.org),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(o.org,
                      style: text.meta.copyWith(fontWeight: FontWeight.w700)),
                ),
                Text('${o.repos.length}',
                    style: text.micro.copyWith(color: colors.mutedForeground)),
              ],
            ),
            for (final r in o.repos) _repo(o, r, colors),
          ],
        ),
      ),
    );
  }

  Widget _repo(OrgNode o, RepoNode r, AppColors colors) {
    final text = textOf(context);
    final k = _keyRepo(o, r);
    final open = _openRepos.contains(k);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _toggleRepo(o, r),
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _toggleRepo(o, r),
                  child: Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16, color: colors.mutedForeground),
                ),
                Icon(Icons.folder_rounded, size: 15, color: colors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(r.repo,
                      overflow: TextOverflow.ellipsis, style: text.meta),
                ),
                if (r.bookmarks.isEmpty)
                  Text('0',
                      style: text.micro.copyWith(color: colors.mutedForeground)),
              ],
            ),
          ),
        ),
        if (open) ...[
          for (final b in r.bookmarks)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: _bookmark(o, r, b, colors),
            ),
        ],
      ],
    );
  }

  Widget _bookmark(OrgNode o, RepoNode r, BookmarkNode b, AppColors colors) {
    final text = textOf(context);
    final hasSession = b.session != null;
    final selected = store.codeRepo == r.repo && store.codeOrg == o.org;
    return InkWell(
      onTap: () {
        store.openRepo(o.org, r.repo, b.bookmark);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          children: [
            const SizedBox(width: 16),
            ChatAvatar(org: o.org, repo: r.repo, bookmark: b.bookmark, radius: 12),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                b.bookmark,
                overflow: TextOverflow.ellipsis,
                style: text.meta.copyWith(
                    color: selected ? colors.primary : null,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
            if (hasSession)
              Icon(Icons.radio_button_checked_rounded,
                  size: 12, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
