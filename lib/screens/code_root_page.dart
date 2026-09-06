import 'package:flutter/material.dart';

import '../i18n.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/org_tree.dart';

/// Code tab stack-bottom page: the org → repo → bookmark tree. This is the
/// root of the code stack; selecting a bookmark pushes a [CodeRepoPage].
class CodeRootPageWidget extends StatelessWidget {
  final AppStore store;
  const CodeRootPageWidget({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final text = textOf(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: AppBars.height,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: Alignment.centerLeft,
            child: Text(context.l10n.tabCode,
                style: text.meta.copyWith(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          Expanded(child: OrgTree(store: store)),
        ],
      ),
    );
  }
}
