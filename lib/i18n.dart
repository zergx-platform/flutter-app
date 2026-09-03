import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight in-app i18n. Only two locales (zh, en) are shipped; the app
/// defaults to zh. The selected locale is persisted. Changing it notifies
/// [notifier] so the root `MaterialApp` rebuilds the whole tree.
class I18n {
  static const _kLocale = 'locale';
  static const Locale fallback = Locale('zh');
  static final ValueNotifier<Locale> notifier = ValueNotifier(fallback);

  static Locale get locale => notifier.value;
  static bool get isZh => locale.languageCode == 'zh';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final code = p.getString(_kLocale);
      if (code == 'zh' || code == 'en') {
        notifier.value = Locale(code!);
      }
    } catch (_) {}
  }

  static Future<void> save(Locale l) async {
    notifier.value = l;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kLocale, l.languageCode);
    } catch (_) {}
  }
}

/// Map key -> {zh, en}. Missing keys fall back to en then the raw key.
class Texts {
  static const Map<String, ({String zh, String en})> _m = {
    // App / shell
    'appTitle': (zh: 'ZergX', en: 'ZergX'),
    'gatewayUrl': (zh: '网关地址', en: 'Gateway URL'),
    'tokenLabel': (zh: '令牌', en: 'Token'),
    'connect': (zh: '连接', en: 'Connect'),
    'connecting': (zh: '连接中…', en: 'Connecting...'),
    'search': (zh: '搜索', en: 'Search'),
    'searchHint': (zh: '搜索会话 / org / repo / 分支',
        en: 'Search sessions / org / repo / branch'),
    'createNewOrg': (zh: '新建组织', en: 'New organization'),
    'createNewRepo': (zh: '新建仓库…', en: 'New repo…'),
    'createCloneRepo': (zh: '克隆仓库…', en: 'Clone repo…'),
    'chooseOrg': (zh: '选择组织', en: 'Choose organization'),
    'createOrgFirst': (zh: '请先创建组织', en: 'Create an organization first'),
    'recent': (zh: '最近', en: 'Recent'),
    'allRepos': (zh: '所有仓库', en: 'All repositories'),
    'noRepos': (zh: '暂无仓库，先创建一个会话吧。',
        en: 'No repositories. Create a session first.'),
    'me': (zh: '我', en: 'me'),

    // Nav tabs
    'tabChat': (zh: '会话', en: 'Chat'),
    'tabCode': (zh: '代码', en: 'Code'),
    'tabContainers': (zh: '容器', en: 'Containers'),
    'tabPackages': (zh: '包', en: 'Packages'),
    'tabConfig': (zh: '设置', en: 'Config'),

    // Session list
    'contextTokens': (zh: '上下文', en: 'Context'),
    'loadError': (zh: '加载失败：\$1', en: 'Load failed: \$1'),
    'markRead': (zh: '标记已读', en: 'Mark as read'),

    // Chat screen
    'typeMessage': (zh: '输入消息…', en: 'Type a message...'),
    'chatTitle': (zh: '会话', en: 'Chat'),
    'thinkLabel': (zh: '思考', en: 'Thinking'),
    'compactedLabel': (zh: '历史已压缩 · 查看摘要', en: 'History compacted · view summary'),
    'copied': (zh: '已复制', en: 'Copied'),
    'copy': (zh: '复制', en: 'Copy'),
    'error': (zh: '错误', en: 'Error'),
    'undo': (zh: '撤销', en: 'Undo'),
    'undoTitle': (zh: '撤销此消息？', en: 'Undo this message?'),
    'undoBody': (zh: '将删除该消息，并撤销之后的所有消息。',
        en: 'This deletes the message and everything after it.'),
    'cancel': (zh: '取消', en: 'Cancel'),
    'confirm': (zh: '确定', en: 'Confirm'),
    'apply': (zh: '应用', en: 'Apply'),
    'delete': (zh: '删除', en: 'Delete'),
    'loading': (zh: '加载中…', en: 'Loading...'),
    'loadEarlier': (zh: '加载更早的消息', en: 'Load earlier'),
    'noChanges': (zh: '无变更', en: 'No changes'),
    'thinking': (zh: '思考中…', en: 'thinking...'),
    'running': (zh: '运行中…', en: 'running...'),
    'sendFailed': (zh: '发送失败: \$1', en: 'Send failed: \$1'),
    'attach': (zh: '添加附件', en: 'Attach file'),
    'image': (zh: '图片', en: 'image'),
    'takePhoto': (zh: '拍照', en: 'Take photo'),
    'chooseImage': (zh: '从相册选图', en: 'Choose from gallery'),
    'chooseFile': (zh: '选择文件', en: 'Choose file'),
    'waitUpload': (zh: '附件仍在上传中，请稍候', en: 'Attachment is still uploading'),
    'downloaded': (zh: '已下载到', en: 'Downloaded to'),

    // Chat topbar menu
    'sessionSettings': (zh: '会话设置', en: 'Session settings'),
    'compactHistory': (zh: '压缩历史', en: 'Compact history'),
    'timeline': (zh: '时间线', en: 'Timeline'),
    'files': (zh: '文件', en: 'Files'),
    'mailbox': (zh: '收件箱', en: 'Mailbox'),
    'container': (zh: '容器', en: 'Container'),
    'todos': (zh: '待办', en: 'Todos'),
    'deleteSession': (zh: '删除会话', en: 'Delete session'),
    'historyCompacted': (zh: '历史已压缩', en: 'History compacted'),
    'nothingToCompact': (zh: '历史太短，无需压缩', en: 'Nothing to compact — history is short'),
    'back': (zh: '返回', en: 'Back'),
    'refresh': (zh: '刷新', en: 'Refresh'),
    'viewOutput': (zh: '查看实时输出', en: 'View live output'),
    'taskProgress': (zh: '任务进度', en: 'Task progress'),
    'taskDone': (zh: '已完成', en: 'Done'),
    'taskFailed': (zh: '已失败', en: 'Failed'),
    'viewChange': (zh: '查看变更', en: 'View change'),
    'changeDiff': (zh: '变更对比', en: 'Change diff'),
    'you': (zh: '我', en: 'me'),

    // Settings dialog
    'settingsTitle': (zh: '会话设置', en: 'Session Settings'),
    'modelLabel': (zh: '模型', en: 'Model'),
    'presetLabel': (zh: '预设', en: 'Preset'),
    'maxTurnsLabel': (zh: '最大轮数', en: 'Max Turns'),
    'sysPromptLabel': (zh: '系统提示（留空继承）', en: 'System Prompt (blank = inherit)'),

    // Delete dialog
    'deleteSessionTitle': (zh: '删除会话', en: 'Delete session'),
    'deleteSessionBody': (zh: '删除会话"\$1"？', en: 'Delete session "\$1"?'),

    // Session sidebar dialogs
    'newOrg': (zh: '新建组织', en: 'New organization'),
    'orgNameLabel': (zh: '组织名称', en: 'Organization name'),
    'newRepoIn': (zh: '在 \$1 新建仓库', en: 'New repo in \$1'),
    'repoNameLabel': (zh: '仓库名称', en: 'Repo name'),
    'cloneInto': (zh: '克隆到 \$1', en: 'Clone into \$1'),
    'gitUrlLabel': (zh: 'Git 地址', en: 'Git URL'),
    'repoName2': (zh: '仓库名称', en: 'Repo name'),
    'accessTokenOpt': (zh: '访问令牌（可选）', en: 'Access token (optional)'),
    'revOpt': (zh: '分支 / 标签 / 提交（可选）', en: 'Branch / tag / commit (optional)'),
    'clone': (zh: '克隆', en: 'Clone'),
    'deleteOrgTitle': (zh: '删除组织', en: 'Delete organization'),
    'deleteRepoTitle': (zh: '删除仓库', en: 'Delete repo'),
    'deleteOrgBody': (zh: '删除组织 \$1？将移除其所有仓库和会话。',
        en: 'Delete organization \$1? This removes all its repos and sessions.'),
    'deleteRepoBody': (zh: '删除仓库 \$1/\$2？将移除其所有会话。',
        en: 'Delete repo \$1/\$2? This removes all its sessions.'),
    'fork': (zh: '分叉', en: 'Fork'),
    'forkBranchLabel': (zh: '分支名称', en: 'Branch name'),
    'branchExists': (zh: '分支已存在', en: 'Branch already exists'),
    'adoptFailed': (zh: '接管失败: \$1', en: 'Adopt failed: \$1'),
    'cloneFailed': (zh: '克隆失败: \$1', en: 'Clone failed: \$1'),
    'failed': (zh: '失败: \$1', en: 'Failed: \$1'),

    // Config screen
    'settings': (zh: '设置', en: 'Settings'),
    'appearance': (zh: '外观', en: 'Appearance'),
    'darkMode': (zh: '深色模式', en: 'Dark mode'),
    'darkModeSub': (zh: '切换深/浅色外观', en: 'Toggle light/dark appearance'),
    'llm': (zh: '语言模型', en: 'LLM'),
    'llmProviders': (zh: '供应商', en: 'Providers'),
    'presets': (zh: '预设', en: 'Presets'),
    'workspace': (zh: '工作区', en: 'Workspace'),
    'tools': (zh: '工具', en: 'Tools'),
    'language': (zh: '语言 / Language', en: 'Language'),
    'logout': (zh: '退出登录', en: 'Log out'),
    'logoutBody': (zh: '将清除已保存的网关地址与令牌，并返回登录页。',
        en: 'This clears the saved gateway URL and token and returns to the login screen.'),
    'switchBackend': (zh: '切换后端', en: 'Switch backend'),
    'backendsTitle': (zh: '后端', en: 'Backends'),
    'noSavedBackends': (zh: '暂无已保存的后端。', en: 'No saved backends yet.'),
    'addBackend': (zh: '添加新后端', en: 'Add new backend'),
    'deleteBackend': (zh: '移除后端', en: 'Remove backend'),
    'backendSection': (zh: '后端', en: 'Backend'),

    // Provider templates (models.dev)
    'providerTemplate': (zh: '模板（models.dev）', en: 'Template (models.dev)'),
    'providerTemplateHint': (zh: '选择服务商自动填充', en: 'Pick a provider to prefill'),
    'searchModels': (zh: '搜索模型…', en: 'Search models...'),
    'modelsSelected': (zh: '已选 \$1 / \$2', en: '\$1 of \$2 selected'),

    // Providers detail
    'noProviders': (zh: '暂无供应商，添加一个开始使用。',
        en: 'No providers. Add one to get started.'),
    'addProvider': (zh: '添加供应商', en: 'Add Provider'),
    'deleteProvider': (zh: '删除供应商', en: 'Delete Provider'),
    'deleteProviderBody': (zh: '删除供应商 \$1？', en: 'Delete Provider \$1?'),
    'modelsCount': (zh: '\$1 个模型', en: '\$1 models'),
    'providerId': (zh: '供应商 ID', en: 'Provider ID'),
    'providerTitle': (zh: '供应商：\$1（\$2）', en: 'Provider: \$1 (\$2)'),
    'providerIdReq': (zh: '供应商 ID（必填）', en: 'Provider ID (required)'),
    'providerIdLabel': (zh: '供应商 ID', en: 'Provider ID'),
    'apiType': (zh: 'API 类型', en: 'API Type'),
    'apiTypeOpenai': (zh: 'OpenAI', en: 'OpenAI'),
    'apiTypeAnthropic': (zh: 'Anthropic', en: 'Anthropic'),
    'apiTypeGemini': (zh: 'Gemini', en: 'Gemini'),
    'baseUrl': (zh: '基础地址', en: 'Base URL'),
    'apiKey': (zh: 'API 密钥', en: 'API Key'),
    'modelsCsv': (zh: '模型（逗号分隔 ID）', en: 'Models (comma-separated IDs)'),
    'test': (zh: '测试', en: 'Test'),
    'testing': (zh: '测试中…', en: 'Testing...'),
    'register': (zh: '注册', en: 'Register'),
    'registering': (zh: '注册中…', en: 'Registering...'),
    'saved': (zh: '已保存', en: 'Saved'),
    'noConfig': (zh: '无配置', en: 'no config'),
    'configured': (zh: '已配置', en: 'configured'),
    'needsConfig': (zh: '需配置', en: 'needs config'),

    // Presets detail
    'newPreset': (zh: '新建预设', en: 'New preset'),
    'presetId': (zh: '预设 ID…', en: 'Preset id...'),
    'create': (zh: '创建', en: 'Create'),
    'noPresets': (zh: '暂无预设。', en: 'No presets.'),
    'deletePreset': (zh: '删除预设', en: 'Delete preset'),
    'deletePresetBody': (zh: '删除预设 \$1？', en: 'Delete preset \$1?'),
    'presetSummary': (zh: '最大 \$1 轮 · \$2 个工具', en: '\$1 turns · \$2 tools'),
    'systemPrompt': (zh: '系统提示', en: 'System Prompt'),
    'maxTurns': (zh: '最大轮数', en: 'Max turns'),

    // Containers
    'containersTitle': (zh: '容器', en: 'Containers'),
    'deployments': (zh: '部署', en: 'Deployments'),
    'noDeployments': (zh: '暂无部署。', en: 'No deployments yet.'),
    'sandboxes': (zh: '沙箱', en: 'Sandboxes'),
    'noContainers': (zh: '没有运行中的容器。', en: 'No containers running.'),
    'deployService': (zh: '部署服务', en: 'Deploy service'),
    'terminal': (zh: '终端', en: 'Terminal'),
    'ready': (zh: '\$1/\$2 就绪', en: '\$1/\$2 ready'),
    'deleteDeploymentTitle': (zh: '删除部署', en: 'Delete deployment'),
    'deleteDeploymentBody': (zh: '删除部署 \$1？', en: 'Delete deployment \$1?'),
    'deleteSandboxTitle': (zh: '删除沙箱', en: 'Delete sandbox'),
    'deleteSandboxBody': (zh: '删除沙箱 \$1？其中运行的任务将被终止。',
        en: 'Delete sandbox \$1? Its running jobs will be killed.'),

    // Container workspace
    'terminalTab': (zh: '终端', en: 'Terminal'),
    'jobsTab': (zh: '任务', en: 'Jobs'),
    'commandHint': (zh: '输入命令…', en: 'command...'),
    'close': (zh: '关闭', en: 'Close'),
    'noOutput': (zh: '无输出', en: 'No output'),
    'noSession': (zh: '无会话', en: 'No session'),
    'noJobs': (zh: '暂无任务', en: 'No jobs'),
    'noWorker': (zh: '还没有 worker 容器 — agent 运行 bash 等工具时自动创建。',
        en: 'No worker container yet — it starts automatically when the agent runs bash.'),
    'createContainerNow': (zh: '立即创建容器', en: 'Create container now'),
    'backgrounded': (zh: '[\$1] 已转入后台（见任务页）',
        en: '[\$1] backgrounded (see Jobs)'),

    // Packages
    'packagesTitle': (zh: '包', en: 'Packages'),
    'registries': (zh: '注册表', en: 'Registries'),
    'packagesTab': (zh: '包', en: 'Packages'),
    'filterEcosystems': (zh: '过滤生态…', en: 'Filter ecosystems...'),
    'proxyRegistries': (zh: '代理注册表（\$1）', en: 'Proxy Registries (\$1)'),
    'endpointCopied': (zh: '端点已复制', en: 'Endpoint copied'),
    'ociCatalog': (zh: 'OCI 镜像目录（\$1）', en: 'OCI Image Catalog (\$1)'),
    'noImages': (zh: '暂无镜像。', en: 'No images stored.'),
    'searchPackages': (zh: '搜索包…', en: 'Search packages...'),
    'typeLabel': (zh: '类型', en: 'Type'),
    'prev': (zh: '上一页', en: 'Prev'),
    'next': (zh: '下一页', en: 'Next'),
    'deletePackage': (zh: '删除包', en: 'Delete package'),
    'deletePackageBody': (zh: '删除包 \$1（\$2）？', en: 'Delete package \$1 (\$2)?'),
    'noVersions': (zh: '暂无版本。', en: 'No versions found.'),
    'downloads': (zh: '\$1 次下载', en: '\$1 downloads'),
    'noPackagesYet': (zh: '暂无已发布的包。', en: 'No packages registered yet.'),
    'versionsCount': (zh: '\$1 个版本', en: '\$1 versions'),
    'cachedPackages': (zh: '\$1 个包', en: '\$1 packages'),
    'noUpstreamLocal': (zh: '无上游（仅本地）', en: 'no upstream (local only)'),

    // Deploy dialog
    'nameLabel': (zh: '名称', en: 'Name'),
    'imageLabel': (zh: '镜像', en: 'Image'),
    'replicasLabel': (zh: '副本数', en: 'Replicas'),
    'portLabel': (zh: '端口', en: 'Port'),
    'sessionOptLabel': (zh: '会话（可选）', en: 'Session (optional)'),

    // Code / files
    'repositories': (zh: '仓库', en: 'Repositories'),
    'history': (zh: '历史', en: 'History'),
    'none': (zh: '无', en: 'None'),
    'download': (zh: '下载', en: 'Download'),
    'selectFile': (zh: '选择一个文件查看', en: 'Select a file to view'),
    'selectBranch': (zh: '选择分支浏览文件', en: 'Select a branch to browse files'),
    'noCommits': (zh: '暂无提交', en: 'No commits'),
    'noHistory': (zh: '该文件暂无历史。', en: 'No history for this file.'),
    'noChangesYet': (zh: '暂无变更', en: 'No changes yet'),
    'noMessages': (zh: '暂无消息', en: 'No messages'),
    'noTodosYet': (zh: '暂无待办 — agent 通过 todowrite 在此跟踪计划。',
        en: 'No todos yet — the agent tracks its plan here via todowrite.'),
    'noDescription': (zh: '（无描述）', en: '(no description)'),

    // Mailbox
    'consumed': (zh: '已消费', en: 'consumed'),
    'pending': (zh: '待处理', en: 'pending'),

    // Browser / org / repo detail
    'browserTitle': (zh: '浏览', en: 'Browse'),
    'bookmarksSection': (zh: '书签', en: 'Bookmarks'),
    'reposCount': (zh: '\$1 个仓库', en: '\$1 repos'),
    'overview': (zh: '概要', en: 'Overview'),
    'releasesTab': (zh: '发布', en: 'Releases'),
    'branchesTab': (zh: '分支', en: 'Branches'),
    'defaultBranch': (zh: '默认分支', en: 'Default branch'),
    'recentCommits': (zh: '最近提交', en: 'Recent commits'),
    'noBranches': (zh: '暂无分支', en: 'No branches'),
    'noReleases': (zh: '暂无发布。', en: 'No releases yet.'),
    'assetsCount': (zh: '\$1 个附件', en: '\$1 assets'),
    'draftBadge': (zh: '草稿', en: 'draft'),
    'prereleaseBadge': (zh: '预发布', en: 'pre-release'),
    'downloadSource': (zh: '下载源码 (tar.gz)', en: 'Download source (tar.gz)'),
    'downloading': (zh: '下载中', en: 'Downloading'),
    'savedToDownloads': (zh: '已保存到「下载」：\$1', en: 'Saved to Downloads: \$1'),
    'savedToAppDir': (zh: '已保存：\$1', en: 'Saved: \$1'),
    'downloadFailed': (zh: '下载失败：\$1', en: 'Download failed: \$1'),
    'newRepoInOrg': (zh: '在此组织新建仓库', en: 'New repo in this org'),

    // Code tab mobile picker
    'pickRepo': (zh: '选择仓库', en: 'Pick a repository'),
    'pickBranch': (zh: '选择分支', en: 'Pick a branch'),
    'pickOrg': (zh: '选择组织', en: 'Pick an organization'),
    'codeEmptyHint': (zh: '先选一个 org / repo / 分支开始浏览代码', en: 'Pick an org / repo / branch to browse code'),
    'backToList': (zh: '返回列表', en: 'Back to list'),

    // Time
    'timeJustNow': (zh: '刚刚', en: 'just now'),
    'timeMinAgo': (zh: '\$1 分钟前', en: '\$1 min ago'),
    'timeHour': (zh: '\$1 小时前', en: '\$1 h ago'),
    'timeDay': (zh: '\$1 天前', en: '\$1 d ago'),
  };

  static String t(BuildContext context, String key, [List<String>? args]) =>
      tr(key, args);

  /// Context-free lookup for non-widget code (controllers, helpers).
  static String tr(String key, [List<String>? args]) {
    final e = _m[key];
    if (e == null) return key;
    final isZh = I18n.isZh;
    var s = isZh ? e.zh : e.en;
    if (args != null) {
      for (var i = 0; i < args.length; i++) {
        s = s.replaceAll('\$${i + 1}', args[i]);
      }
    }
    return s;
  }
}

/// Convenience top-level accessor: `t(context, 'key')`.
String t(BuildContext context, String key, [List<String>? args]) {
  return Texts.t(context, key, args);
}
