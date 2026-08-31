import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'container_overlay.dart';

/// Recreates ContainersPage.svelte (sandboxes + deployments; terminal
/// drill-in reuses the container workspace UI).
class ContainersScreen extends StatefulWidget {
  final AppStore store;
  const ContainersScreen({super.key, required this.store});

  @override
  State<ContainersScreen> createState() => _ContainersScreenState();
}

class _ContainersScreenState extends State<ContainersScreen> {
  AppStore get store => widget.store;
  List<Sandbox> _sandboxes = [];
  List<Deployment> _deployments = [];
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      _sandboxes = await store.api.sandboxes();
    } catch (_) {}
    try {
      _deployments = await store.api.deployments();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _destroySandbox(Sandbox s) async {
    try {
      await store.api.destroySandbox(s.session);
    } catch (e) {
      _error = '$e';
      setState(() {});
    }
    await _load();
  }

  Future<void> _destroyDeployment(Deployment d) async {
    try {
      await store.api.destroyDeployment(d.name);
    } catch (e) {
      _error = '$e';
      setState(() {});
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Containers'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
              icon: const Icon(Icons.public),
              tooltip: 'Deploy service',
              onPressed: () => _deployDialog()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error.isNotEmpty)
                  Text(_error,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                Text('Deployments',
                    style: Theme.of(context).textTheme.titleSmall),
                if (_deployments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No deployments yet.'),
                  )
                else
                  for (final d in _deployments) _deploymentCard(d),
                const SizedBox(height: 16),
                Text('Sandboxes',
                    style: Theme.of(context).textTheme.titleSmall),
                if (_sandboxes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No containers running.'),
                  )
                else
                  for (final s in _sandboxes) _sandboxCard(s),
              ],
            ),
    );
  }

  Widget _deploymentCard(Deployment d) {
    return Card(
      child: ListTile(
        title: Text(d.name, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        subtitle: Text(d.image, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text('${d.ready}/${d.replicas} ready',
                  style: TextStyle(
                      fontSize: 10,
                      color: d.ready > 0 ? Colors.green : Colors.red)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => _destroyDeployment(d),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sandboxCard(Sandbox s) {
    return Card(
      child: ListTile(
        title: Text(s.podName, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        subtitle: Text(s.session, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.status == 'running'
                    ? Colors.green
                    : s.status == 'starting'
                        ? Colors.amber
                        : Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: s.status != 'running' ? null : () => _openTerminal(s),
              child: const Text('Terminal'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => _destroySandbox(s),
            ),
          ],
        ),
      ),
    );
  }

  void _openTerminal(Sandbox s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(s.session, style: const TextStyle(fontFamily: 'monospace'))),
        body: ContainerWorkspace(store: store, session: s.session),
      ),
    ));
  }

  Future<void> _deployDialog() async {
    final name = TextEditingController();
    final image = TextEditingController();
    final replicas = TextEditingController(text: '1');
    final port = TextEditingController(text: '8080');
    final session = TextEditingController();
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deploy Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: image, decoration: const InputDecoration(labelText: 'Image')),
              TextField(controller: replicas, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Replicas')),
              TextField(controller: port, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Port')),
              TextField(controller: session, decoration: const InputDecoration(labelText: 'Session (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deploy')),
        ],
      ),
    );
    if (r == true && name.text.trim().isNotEmpty && image.text.trim().isNotEmpty) {
      try {
        await store.api.deploy({
          'name': name.text.trim(),
          'image': image.text.trim(),
          'replicas': int.tryParse(replicas.text) ?? 1,
          'port': int.tryParse(port.text) ?? 8080,
          if (session.text.trim().isNotEmpty) 'session': session.text.trim(),
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
      await _load();
    }
  }
}