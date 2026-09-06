/// Navigation types: per-tab page stacks and the page descriptors.
///
/// This file defines only the data model (enums + [AppPage]) and the stack root
/// factory. The widget-to-page dispatch lives in `page_builder.dart` so there is
/// no import cycle with `store.dart` (which consumes these types) or the page
/// widget files.
library;

import 'enums.dart';

export 'enums.dart' show SessionOverlay, SiderTab;

/// One view in a tab's navigation stack. An [AppPage] describes *which* view
/// to show; the widget itself reads live state (active session, selected repo,
/// file path…) from [AppStore]. The stack is per-tab: switching tabs keeps each
/// tab's depth, and pop returns to the previous view in that tab. The [key]
/// makes [AppStore.pushPage] replace an entry in place (no unbounded growth).
///
/// Tabs without multi-pane layouts (config uses its own internal sub-page
/// stack, so it is rendered directly by the shell) use a single root page.
sealed class AppPage {
  final String? key;
  const AppPage([this.key]);
}

/// Chat tab — bottom of the stack (sessions list).
class ChatListPage extends AppPage {
  const ChatListPage() : super('chat_list');
}

/// Chat tab — a conversation is open.
class ChatSessionPage extends AppPage {
  const ChatSessionPage() : super('chat_session');
}

/// Chat tab — a session sub-page (timeline / files / mailbox / container /
/// todos). [overlay] selects which.
class ChatOverlayPage extends AppPage {
  final SessionOverlay overlay;
  const ChatOverlayPage(this.overlay) : super('chat_overlay');
}

/// Code tab — bottom of the stack (org → repo → bookmark tree).
class CodeRootPage extends AppPage {
  const CodeRootPage() : super('code_root');
}

/// Code tab — a repo is open; shows its file list (tree/commits).
class CodeRepoPage extends AppPage {
  final String org;
  final String repo;
  final String bookmark;
  const CodeRepoPage(this.org, this.repo, this.bookmark)
      : super('code_repo_$org/$repo@$bookmark');
}

/// Code tab — a file's content (highlighted, with history/diff).
class CodeFilePage extends AppPage {
  final String path;
  const CodeFilePage(this.path) : super('code_file_$path');
}

/// Containers tab — bottom of the stack (single page).
class ContainersRootPage extends AppPage {
  const ContainersRootPage() : super('containers_root');
}

/// Worksheets tab — bottom of the stack (single page).
class WorksheetsRootPage extends AppPage {
  const WorksheetsRootPage() : super('worksheets_root');
}

/// Config tab — bottom of the stack (settings list).
class ConfigRootPage extends AppPage {
  const ConfigRootPage() : super('config_root');
}

/// Config tab — a drill-in sub page (providers / presets / tools / …).
class ConfigSubPage extends AppPage {
  final String id;
  const ConfigSubPage(this.id) : super('config_sub_$id');
}

/// The stack-bottom page for a given tab.
AppPage rootPageFor(SiderTab tab) => switch (tab) {
      SiderTab.chat => const ChatListPage(),
      SiderTab.code => const CodeRootPage(),
      SiderTab.containers => const ContainersRootPage(),
      SiderTab.worksheets => const WorksheetsRootPage(),
      SiderTab.config => const ConfigRootPage(),
    };
