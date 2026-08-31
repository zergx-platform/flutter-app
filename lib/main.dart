import 'package:flutter/material.dart';

import '../api.dart';
import '../prefs.dart';
import '../store.dart';
import '../screens/chat.dart';
import '../screens/chat_sidebar.dart';
import '../screens/code.dart';
import '../screens/config.dart';
import '../screens/containers.dart';
import '../screens/packages.dart';

const defaultBaseUrl = 'https://gateway.zergx.10.199.64.20.nip.io';

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
  AppStore? _store;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await Prefs.load();
    final base = prefs.baseUrl?.isNotEmpty == true ? prefs.baseUrl! : defaultBaseUrl;
    if (mounted) {
      setState(() {
        _baseUrl = base;
        _token = prefs.token ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZergX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: _buildHome(),
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
          setState(() {
            _baseUrl = base;
            _token = token;
            _store = null;
          });
        },
      );
    }
    _store ??= AppStore(ZergxApi(baseUrl: _baseUrl!, token: _token!));
    return _Shell(store: _store!);
  }
}

class _Shell extends StatelessWidget {
  final AppStore store;
  const _Shell({required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tab = store.siderTab;
        Widget body;
        switch (tab) {
          case SiderTab.chat:
            body = store.activeSessionId == null
                ? _SessionsHome(store: store)
                : ChatScreen(store: store);
            break;
          case SiderTab.code:
            body = CodeScreen(store: store);
            break;
          case SiderTab.config:
            body = ConfigScreen(store: store);
            break;
          case SiderTab.containers:
            body = ContainersScreen(store: store);
            break;
          case SiderTab.packages:
            body = PackagesScreen(store: store);
            break;
        }
        return Scaffold(
          body: Row(
            children: [
              _NavRail(tab: tab, onTap: (t) => store.switchTab(t)),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class _NavRail extends StatelessWidget {
  final SiderTab tab;
  final void Function(SiderTab) onTap;
  const _NavRail({required this.tab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = <(SiderTab, IconData, String)>[
      (SiderTab.chat, Icons.chat_bubble_outline, 'Chat'),
      (SiderTab.code, Icons.folder_copy_outlined, 'Code'),
      (SiderTab.containers, Icons.inventory_2_outlined, 'Containers'),
      (SiderTab.packages, Icons.all_inbox_outlined, 'Packages'),
      (SiderTab.config, Icons.settings_outlined, 'Config'),
    ];
    return NavigationRail(
      selectedIndex: tab.index,
      labelType: MediaQuery.of(context).size.width < 900
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      onDestinationSelected: (i) => onTap(SiderTab.values[i]),
      destinations: [
        for (final (_, icon, label) in items)
          NavigationRailDestination(
              icon: Icon(icon), label: Text(label)),
      ],
    );
  }
}

class _SessionsHome extends StatelessWidget {
  final AppStore store;
  const _SessionsHome({required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sessions')),
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
  late final TextEditingController _token =
      TextEditingController(text: '5H7q_K940ySbgXng7H3nNWTTweGcjhGmFSJwJnTAQRw');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('ZergX', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _base,
                    decoration: const InputDecoration(
                        labelText: 'Gateway URL', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _token,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Token', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      if (_base.text.isNotEmpty && _token.text.isNotEmpty) {
                        widget.onSave(_base.text.trim(), _token.text.trim());
                      }
                    },
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}