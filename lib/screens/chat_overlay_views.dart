import 'package:flutter/material.dart';

import '../navigation.dart';
import '../store.dart';
import 'chat.dart';
import 'timeline_diff_page.dart';
import 'container_overlay.dart';
import 'files_overlay.dart';
import 'overlays.dart';

/// The body of a session sub-page, switching on the overlay type. Lives
/// separately so `chat_overlay_page.dart` (a nav page) can build it without an
/// import cycle, and because the individual overlay widgets are large.
class ChatOverlayViews extends StatelessWidget {
  final AppStore store;
  final SessionOverlay overlay;
  const ChatOverlayViews({super.key, required this.store, required this.overlay});

  @override
  Widget build(BuildContext context) {
    switch (overlay) {
      case SessionOverlay.timeline:
        if (store.diffChangeId != null) {
          return TimelineDiffScreen(store: store, changeId: store.diffChangeId!);
        }
        return TimelineOverlay(store: store, onSelectDiff: (id) => store.openChange(id));
      case SessionOverlay.files:
        return FilesOverlay(store: store);
      case SessionOverlay.mailbox:
        return MailboxOverlay(store: store);
      case SessionOverlay.container:
        return ContainerOverlay(store: store);
      case SessionOverlay.todos:
        return TodosOverlay(store: store);
    }
  }
}
