import 'package:flutter/material.dart';

import '../store.dart';
import 'chat_sidebar.dart';
import '../widgets/session_list_header.dart';

/// Chat tab stack-bottom page: the sessions list (AppBar "会话" + search + "+"
/// + the IM-style recent-sessions list). This is the root of the chat stack;
/// tapping a session pushes a [ChatSessionPage].
class SessionListPage extends StatelessWidget {
  final AppStore store;
  const SessionListPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SessionListHeader(store: store),
      body: ChatSidebar(store: store),
    );
  }
}
