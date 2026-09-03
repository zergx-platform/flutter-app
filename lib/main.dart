import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'i18n.dart';
import 'prefs.dart';
import 'store.dart';
import 'theme/app_theme.dart';
import 'widgets/create_menu.dart';
import 'screens/chat.dart';
import 'screens/browser.dart';
import 'screens/chat_sidebar.dart';
import 'screens/code.dart';
import 'screens/config.dart';
import 'screens/containers.dart';
import 'screens/packages.dart';

const defaultBaseUrl = 'https://platform.zergx.10.199.64.20.nip.io';

void main() {
  runApp(const ZergxApp());
}

class ZergxApp extends StatefulWidget {
  const ZergxApp({super.key});

  @override
  State<ZergxApp> createState() => _ZergxAppState();
}

class _ZergxAppState extends State<ZergxApp> {
  String? _baseUrl;
  String? _token;
  bool _dark = true;
  AppStore? _store;

  /// Root navigator key: lets root-level helpers (backend manager) show
  /// sheets with a context BELOW MaterialApp — the State's own context is
  /// above it and has no Navigator, which made the button do nothing.
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Load persisted locale before the first build.
    await I18n.load();
    await Prefs.loadAgentLocale();
    final prefs = await Prefs.load();
    final base = prefs.baseUrl?.isNotEmpty == true ? prefs.baseUrl! : defaultBaseUrl;
    if (mounted) {
      setState(() {
        _baseUrl = base;
        _token = prefs.token ?? '';
        _dark = prefs.darkMode;
      });
    }
  }

  void _setDarkMode(bool dark) {
    setState(() => _dark = dark);
    Prefs.saveDarkMode(dark);
  }

  Future<void> _logout() async {
    await Prefs.clearActive();
    if (mounted) {
      setState(() {
        _token = '';
        _store = null;
      });
    }
  }

  /// Switch to a saved backend: persist it as the active connection and
  /// rebuild the store (keeps everything else — locale, dark mode).
  Future<void> _switchBackend(BackendCfg b) async {
    await Prefs.save(b.baseUrl, b.token);
    if (mounted) {
      setState(() {
        _baseUrl = b.baseUrl;
        _token = b.token;
        _store = null;
      });
    }
  }

  /// Backend manager sheet: switch / delete saved backends, or add a new
  /// one (which lands on the setup screen). The active backend is marked.
  Future<void> _manageBackends() async {
    final backends = await Prefs.backends();
    final navCtx = _navKey.currentContext;
    if (navCtx == null || !navCtx.mounted) return;
    await showModalBottomSheet<void>(
      context: navCtx,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(ctx.l10n.backendsTitle,
                  style: textOf(ctx)
                      .meta
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
            Flexible(
              child: backends.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(ctx.l10n.noSavedBackends,
                          style: TextStyle(
                              color: colorsOf(ctx).mutedForeground)),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final b in backends)
                          ListTile(
                            leading: Icon(
                              _baseUrl == b.baseUrl
                                  ? Icons.radio_button_checked
                                  : Icons.dns_outlined,
                              color: _baseUrl == b.baseUrl
                                  ? colorsOf(ctx).primary
                                  : colorsOf(ctx).mutedForeground,
                            ),
                            title: Text(b.name.isNotEmpty ? b.name : b.baseUrl),
                            subtitle: Text(b.baseUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textOf(ctx)
                                    .micro
                                    .copyWith(
                                        color: colorsOf(ctx).mutedForeground)),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  size: 18,
                                  color: colorsOf(ctx).mutedForeground),
                              tooltip: ctx.l10n.deleteBackend,
                              onPressed: () async {
                                await Prefs.removeBackend(b.baseUrl);
                                if (ctx.mounted) Navigator.pop(ctx);
                                _manageBackends();
                              },
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              _switchBackend(b);
                            },
                          ),
                      ],
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(ctx.l10n.addBackend),
              onTap: () {
                Navigator.pop(ctx);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: I18n.notifier,
      builder: (context, locale, _) => MaterialApp(
        navigatorKey: _navKey,
        title: I18n.now.appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        locale: locale,
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _buildHome(),
      ),
    );
  }

  Widget _buildHome() {
    if (_baseUrl == null || _token == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_token!.isEmpty) {
      return _SetupScreen(
        initialBaseUrl: _baseUrl!,
        onSave: (base, token) async {
          await Prefs.save(base, token);
          await Prefs.upsertBackend(BackendCfg(
              name: BackendCfg.nameFor(base), baseUrl: base, token: token));
          setState(() {
            _baseUrl = base;
            _token = token;
            _store = null;
          });
        },
      );
    }
    if (_store != null) {
      return _Shell(
          store: _store!,
          darkMode: _dark,
          onDarkMode: _setDarkMode,
          onSwitchBackend: _manageBackends);
    }
    return FutureBuilder<AppStore>(
      future: _buildStore(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return _Shell(
            store: snap.data!,
            darkMode: _dark,
            onDarkMode: _setDarkMode,
            onSwitchBackend: _manageBackends);
      },
    );
  }

  Future<AppStore> _buildStore() async {
    final api = await ZergxApi.create(baseUrl: _baseUrl!, token: _token!);
    if (mounted) _store = AppStore(api);
    return _store!;
  }
}

/// App shell. Phones get a bottom navigation bar (IM-app style); tablets and
/// desktop get a compact navigation rail.
class _Shell extends StatelessWidget {
  final AppStore store;
  final bool darkMode;
  final ValueChanged<bool> onDarkMode;
  final VoidCallback? onSwitchBackend;
  const _Shell({
      required this.store,
      required this.darkMode,
      required this.onDarkMode,
      this.onSwitchBackend});

  static const _navItems = <(SiderTab, IconData, String)>[
    (SiderTab.chat, Icons.chat_bubble_outline, 'tabChat'),
    (SiderTab.code, Icons.folder_copy_outlined, 'tabCode'),
    (SiderTab.containers, Icons.inventory_2_outlined, 'tabContainers'),
    (SiderTab.packages, Icons.all_inbox_outlined, 'tabPackages'),
    (SiderTab.config, Icons.settings_outlined, 'tabConfig'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tab = store.siderTab;
        final compact = MediaQuery.sizeOf(context).width < 900;
        // Inside a conversation the bottom bar is hidden — the chat screen
        // owns the full height, like a native IM app.
        final hideTabBar = tab == SiderTab.chat && store.activeSessionId != null;
        Widget body = switch (tab) {
          SiderTab.chat => store.activeSessionId == null
              ? _SessionsHome(store: store)
              : ChatScreen(store: store),
          SiderTab.code => CodeScreen(store: store),
          SiderTab.config => ConfigScreen(
              store: store,
              darkMode: darkMode,
              onDarkMode: onDarkMode,
              onSwitchBackend: onSwitchBackend,
            ),
          SiderTab.containers => ContainersScreen(store: store),
          SiderTab.packages => PackagesScreen(store: store),
        };
        return Scaffold(
          body: compact
              ? body
              : Row(
                  children: [
                    _NavRail(
                      tab: tab,
                      items: _navItems,
                      onTap: (tb) => store.switchTab(tb),
                    ),
                    Expanded(child: body),
                  ],
                ),
          bottomNavigationBar: compact && !hideTabBar
              ? _BottomBar(
                  tab: tab,
                  items: _navItems,
                  onTap: (tb) => store.switchTab(tb),
                )
              : null,
        );
      },
    );
  }
}

class _NavRail extends StatelessWidget {
  final SiderTab tab;
  final List<(SiderTab, IconData, String)> items;
  final void Function(SiderTab) onTap;
  const _NavRail(
      {required this.tab, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          right: BorderSide(color: colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          for (final (tb, icon, labelKey) in items)
            _RailItem(
              icon: icon,
              label: l10nString(labelKey),
              selected: tab == tb,
              onTap: () => onTap(tb),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RailItem({
      required this.icon,
      required this.label,
      required this.selected,
      required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rSm,
        child: SizedBox(
          width: 48,
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? colors.primary : colors.mutedForeground),
              const SizedBox(height: 2),
              Text(
                label,
                style: text.micro.copyWith(
                  color:
                      selected ? colors.primary : colors.mutedForeground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final SiderTab tab;
  final List<(SiderTab, IconData, String)> items;
  final void Function(SiderTab) onTap;
  const _BottomBar(
      {required this.tab, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (final (tb, icon, labelKey) in items)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(tb),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon,
                            size: 22,
                            color: selected(tb, tab)
                                ? colors.primary
                                : colors.mutedForeground),
                        const SizedBox(height: 2),
                        Text(
                          l10nString(labelKey),
                          style: text.micro.copyWith(
                            color: selected(tb, tab)
                                ? colors.primary
                                : colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static bool selected(SiderTab tb, SiderTab current) => tb == current;
}

/// Sessions list home — shown when no conversation is open. WeChat-style:
/// AppBar title, a search icon button, a "+" create menu, then the chat list.
class _SessionsHome extends StatelessWidget {
  final AppStore store;
  const _SessionsHome({required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZergX'),
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
      ),
      body: ChatSidebar(store: store),
    );
  }
}

class _SetupScreen extends StatefulWidget {
  final String initialBaseUrl;
  final Future<void> Function(String base, String token) onSave;
  const _SetupScreen({required this.initialBaseUrl, required this.onSave});

  @override
  State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  late final TextEditingController _base =
      TextEditingController(text: widget.initialBaseUrl);
  late final TextEditingController _token = TextEditingController();

  bool _busy = false;
  bool _showToken = false;

  @override
  void dispose() {
    _base.dispose();
    _token.dispose();
    super.dispose();
  }

  bool get _canConnect =>
      _base.text.trim().isNotEmpty && _token.text.trim().isNotEmpty && !_busy;

  /// Verify the gateway + token before saving so a typo can't land the user
  /// in a silently-empty app.
  Future<void> _connect() async {
    final base = _base.text.trim();
    final token = _token.text.trim();
    if (base.isEmpty || token.isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = await ZergxApi.create(baseUrl: base, token: token);
      await api.listSessions();
      if (!mounted) return;
      await widget.onSave(base, token);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(I18n.now.loadError('$e'))));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('ZergX',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xl),
                    TextField(
                      controller: _base,
                      enabled: !_busy,
                      decoration: InputDecoration(
                          labelText: context.l10n.gatewayUrl),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _token,
                      obscureText: !_showToken,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: context.l10n.tokenLabel,
                        suffixIcon: IconButton(
                          icon: Icon(_showToken
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () =>
                              setState(() => _showToken = !_showToken),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _canConnect ? _connect : null,
                      child: Text(_busy
                          ? context.l10n.connecting
                          : context.l10n.connect),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
