import 'package:flutter/material.dart';

import '../i18n.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../screens/browser.dart';
import 'create_menu.dart';

/// The app bar for the session list: title (tabChat) + search (→ BrowserPage)
/// + the create ("+") menu. Shared by the sessions home (phone) and the
/// tablet/desktop chat sidebar so the "会话 / 🔍 / ➕" header is identical in
/// both places instead of disappearing when a conversation is opened.
class SessionListHeader extends StatelessWidget implements PreferredSizeWidget {
  final AppStore store;
  const SessionListHeader({super.key, required this.store});

  /// Use the same height as the app's standard app bar so it sits flush with
  /// the themed AppBar of the other tabs.
  @override
  Size get preferredSize => const Size.fromHeight(AppBars.height);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Never show a back arrow here: this header is also embedded in the
      // tablet chat column where the route may be inherently pop-able (and the
      // conversation already has its own back button in the right panel).
      automaticallyImplyLeading: false,
      title: Text(context.l10n.tabChat),
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: colorsOf(context).primary),
          tooltip: context.l10n.search,
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BrowserPage(store: store),
            ));
          },
        ),
        CreateMenu(store: store, iconColor: colorsOf(context).primary),
      ],
    );
  }
}
