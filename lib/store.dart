import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';

enum SiderTab { chat, code, containers, packages, config }

enum SessionOverlay { timeline, files, mailbox, container, todos }

/// Mirrors stores.svelte.ts: app-wide state + repository/file-outlook caching.
class AppStore extends ChangeNotifier {
  AppStore(this.api);

  final ZergxApi api;

  SiderTab siderTab = SiderTab.chat;
  List<Session> sessions = [];
  String? activeSessionId;
  SessionOverlay? sessionOverlay;
  List<OrgNode> orgs = [];

  // timeline drill-in
  String? diffChangeId;

  // files overlay drill-in
  String? codeFilePath;

  String codeOrg = '';
  String codeRepo = '';
  String codeBranch = '';
  Map<String, List<FileEntry>> treeCache = {};
  Set<String> expandedDirs = {'',};
  String? selectedFilePath;
  String fileContent = '';
  bool codeLoading = false;

  // file history / diff
  List<FileCommit> fileHistory = [];
  bool fileHistoryLoading = false;
  bool showFileHistory = false;
  Set<String> expandedCommits = {};
  Map<String, String> fileDiffs = {};
  String? activeDiffChangeId;

  int sessionRevision = 0;

  Session? get activeSession {
    for (final s in sessions) {
      if (s.id == activeSessionId) return s;
    }
    return null;
  }

  bool get hasOverlay => diffChangeId != null || codeFilePath != null;

  Session? sessionById(String id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> refreshSessions() async {
    try {
      sessions = await api.listSessions();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshRepos() async {
    try {
      orgs = await api.repos();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadTreeDir(String dir) async {
    if (codeOrg.isEmpty || codeRepo.isEmpty) return;
    if (treeCache.containsKey(dir)) return;
    codeLoading = true;
    notifyListeners();
    try {
      final entries =
          await api.listFiles(codeOrg, codeRepo, dir, codeBranch.isEmpty ? null : codeBranch);
      treeCache[dir] = entries;
    } catch (_) {
      treeCache[dir] = [];
    }
    codeLoading = false;
    notifyListeners();
  }

  String defaultBranchOf(String org, String repo) {
    final bms =
        orgs
            .where((o) => o.org == org)
            .expand((o) => o.repos)
            .where((r) => r.repo == repo)
            .expand((r) => r.bookmarks)
            .map((b) => b.branch)
            .toList();
    for (final pref in ['main', 'master', 'dev']) {
      if (bms.contains(pref)) return pref;
    }
    return bms.isNotEmpty ? bms.first : '';
  }

  Future<void> toggleDir(String dir) async {
    if (expandedDirs.contains(dir)) {
      expandedDirs.remove(dir);
    } else {
      await loadTreeDir(dir);
      expandedDirs.add(dir);
    }
    notifyListeners();
  }

  Future<void> openRepo(String org, String repo, [String? branch]) async {
    codeOrg = org;
    codeRepo = repo;
    codeBranch = branch ?? defaultBranchOf(org, repo);
    selectedFilePath = null;
    fileContent = '';
    showFileHistory = false;
    fileHistory = [];
    treeCache = {};
    expandedDirs = {''};
    notifyListeners();
    await loadTreeDir('');
  }

  Future<void> refreshFileTree() async {
    if (codeOrg.isEmpty || codeRepo.isEmpty) return;
    treeCache = {};
    await loadTreeDir('');
  }

  Future<void> openFile(String path) async {
    selectedFilePath = path;
    showFileHistory = false;
    fileHistory = [];
    expandedCommits = {};
    fileDiffs = {};
    activeDiffChangeId = null;
    notifyListeners();
    try {
      fileContent = await api.readFile(
          codeOrg, codeRepo, path, codeBranch.isEmpty ? null : codeBranch);
    } catch (_) {
      fileContent = '';
    }
    notifyListeners();
  }

  Future<String> _loadFileDiff(String changeId) async {
    if (fileDiffs.containsKey(changeId) || selectedFilePath == null) {
      return fileDiffs[changeId] ?? '';
    }
    try {
      final d = await api.fileDiff(codeOrg, codeRepo, changeId, selectedFilePath!);
      fileDiffs[changeId] = d;
      notifyListeners();
      return d;
    } catch (_) {
      return '';
    }
  }

  Future<void> loadFileHistory() async {
    if (selectedFilePath == null) return;
    fileHistoryLoading = true;
    showFileHistory = true;
    notifyListeners();
    try {
      fileHistory = await api.fileLog(codeOrg, codeRepo, selectedFilePath!,
          codeBranch.isEmpty ? null : codeBranch);
    } catch (_) {
      fileHistory = [];
    }
    fileHistoryLoading = false;
    notifyListeners();
  }

  Future<void> toggleCommitDiff(String changeId) async {
    activeDiffChangeId = changeId;
    await _loadFileDiff(changeId);
    notifyListeners();
  }

  void stepFileBack() {
    if (activeDiffChangeId != null) {
      activeDiffChangeId = null;
    } else if (showFileHistory) {
      showFileHistory = false;
    } else {
      selectedFilePath = null;
      fileContent = '';
    }
    notifyListeners();
  }

  List<String> get existingBookmarks =>
      sessions.map((s) => s.branch).toList();

  Future<void> deleteSession(String id) async {
    await api.deleteSession(id);
    if (activeSessionId == id) activeSessionId = null;
    await refreshSessions();
  }

  Future<void> deleteBookmark(String org, String repo, String bm) async {
    await api.deleteBookmark(org, repo, bm);
    await refreshSessions();
  }

  Future<void> deleteRepo(String org, String repo) async {
    await api.deleteRepo(org, repo);
    await refreshSessions();
    await refreshRepos();
  }

  Future<void> deleteOrg(String org) async {
    await api.deleteOrg(org);
    await refreshSessions();
    await refreshRepos();
  }

  Future<bool> forkSession(String branch) async {
    final id = sessionById(activeSessionId ?? '')?.id;
    if (id == null) return false;
    try {
      final s = await api.fork(id, branch);
      activeSessionId = s.id;
      await refreshSessions();
      await refreshRepos();
      return true;
    } catch (_) {
      return false;
    }
  }

  void pickSession(String id) {
    activeSessionId = id;
    sessionOverlay = null;
    diffChangeId = null;
    notifyListeners();
    api.markRead(id).catchError((_) {});
  }

  void openOverlay(SessionOverlay v) {
    if (activeSessionId == null) return;
    sessionOverlay = v;
    notifyListeners();
  }

  void openChange(String changeId) {
    sessionOverlay = SessionOverlay.timeline;
    diffChangeId = changeId;
    notifyListeners();
  }

  void closeOverlay() {
    sessionOverlay = null;
    diffChangeId = null;
    notifyListeners();
  }

  void closeSession() {
    activeSessionId = null;
    sessionOverlay = null;
    diffChangeId = null;
    notifyListeners();
  }

  void bumpSessionRevision() {
    sessionRevision += 1;
    notifyListeners();
  }

  void switchTab(SiderTab tab) {
    siderTab = tab;
    notifyListeners();
  }

  /// Public wrapper so screens can trigger a rebuild after mutating lists.
  void notifyObservers() => notifyListeners();
}