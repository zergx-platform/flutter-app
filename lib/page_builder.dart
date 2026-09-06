import 'package:flutter/material.dart';

import 'store.dart';
import 'navigation.dart';
import 'screens/session_list_page.dart';
import 'screens/chat.dart';
import 'screens/chat_overlay_page.dart';
import 'screens/code_root_page.dart';
import 'screens/code_repo_page.dart';
import 'screens/code_file_page.dart';
import 'screens/containers.dart';
import 'screens/worksheets.dart';

/// Build the widget for a single [AppPage]. [isTablet] lets a page render its
/// own back affordance only when it is the *current* (top) page of the last-two
/// table split; the preceding page is context and shows no back.
Widget buildPage(AppStore store, AppPage page, {required bool isTablet}) {
  switch (page) {
    case ChatListPage():
      return SessionListPage(store: store);
    case ChatSessionPage():
      return ChatSessionPageWidget(store: store);
    case ChatOverlayPage(:final overlay):
      return ChatOverlayPageWidget(store: store, overlay: overlay);
    case CodeRootPage():
      return CodeRootPageWidget(store: store);
    case CodeRepoPage(:final org, :final repo, :final bookmark):
      return CodeRepoPageWidget(store: store, org: org, repo: repo, bookmark: bookmark);
    case CodeFilePage(:final path):
      return CodeFilePageWidget(store: store, path: path);
    case ContainersRootPage():
      return ContainersScreen(store: store);
    case WorksheetsRootPage():
      return WorksheetsScreen(store: store);
  }
}

/// Build the widgets for the [lastCount] newest pages of [stack], oldest→newest.
/// Phone uses 1 (the top); tablets use the last two (context + current).
List<Widget> buildStackPages(AppStore store, List<AppPage> stack,
    {required int lastCount}) {
  final n = stack.length;
  final start = n - lastCount;
  if (start < 0) return const [];
  final pages = stack.sublist(start);
  return [
    for (var i = 0; i < pages.length; i++)
      buildPage(store, pages[i], isTablet: i == pages.length - 1),
  ];
}
