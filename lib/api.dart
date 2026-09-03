import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'models.dart';
import 'net/http_client_factory.dart';

class StreamEvent {
  final String event;
  final Map<String, dynamic> params;
  StreamEvent(this.event, Map<String, dynamic>? params)
      : params = params ?? const {};
  dynamic get(String key) => params[key];
  String str(String key) => params[key] as String? ?? '';
}

class TaskLogLine {
  final String stream;
  final String line;
  TaskLogLine(this.stream, this.line);
}

/// Thin client over the zergx gateway, mirroring the api-*.ts modules.
class ZergxApi {
  final String baseUrl;
  final String token;
  final http.Client client;

  ZergxApi({required this.baseUrl, required this.token})
      : client = http.Client();
  ZergxApi.withClient(
      {required this.baseUrl, required this.token, required this.client});

  static Future<ZergxApi> create(
      {required String baseUrl, required String token}) async {
    return ZergxApi.withClient(
        baseUrl: baseUrl, token: token, client: await platformHttpClient());
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Uri _u(String path, [Map<String, dynamic>? query]) {
    final parsed = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return parsed;
    final orig = parsed.queryParameters;
    final merged = <String, String>{...orig};
    query.forEach((k, v) {
      if (v != null) merged[k] = '$v';
    });
    return parsed.replace(queryParameters: merged);
  }

  String _enc(String s) => Uri.encodeComponent(s);

  dynamic _decode(http.Response r) {
    if (r.statusCode >= 400) throw ApiException(r.statusCode, r.body);
    if (r.body.isEmpty) return const <String, dynamic>{};
    return jsonDecode(r.body);
  }

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async {
    final r = await client.get(_u(path, query), headers: _headers);
    return _decode(r);
  }

  Future<dynamic> _post(String path, [Object? body]) async {
    final r = await client.post(
      _u(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(r);
  }

  Future<dynamic> _patch(String path, Object? body) async {
    final r = await client.patch(
      _u(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(r);
  }

  Future<dynamic> _put(String path, Object? body) async {
    final r = await client.put(
      _u(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(r);
  }

  Future<dynamic> _del(String path) async {
    final r = await client.delete(_u(path), headers: _headers);
    return _decode(r);
  }

  List<T> _list<T>(dynamic j, T Function(Map<String, dynamic>) f,
      [String key = '']) {
    final src = key.isEmpty ? j : j[key];
    return ((src as List?) ?? [])
        .map((e) => f(e as Map<String, dynamic>))
        .toList();
  }

  // ---- sessions ----

  Future<List<Session>> listSessions() async {
    final j = await _get('/api/v1/sessions') as Map<String, dynamic>;
    return _list(j, Session.fromJson, 'sessions');
  }

  Future<Session> createSession(Map<String, dynamic> params) async {
    final j = await _post('/api/v1/sessions', params) as Map<String, dynamic>;
    return Session.fromJson(j['session'] as Map<String, dynamic>);
  }

  Future<Session> getSession(String id) async {
    final j = await _get('/api/v1/sessions/${_enc(id)}') as Map<String, dynamic>;
    return Session.fromJson(j['session'] as Map<String, dynamic>);
  }

  Future<void> deleteSession(String id) => _del('/api/v1/sessions/${_enc(id)}');

  Future<String> prompt(String id, String prompt, {List<String>? attachments}) async {
    final j = await _post('/api/v1/sessions/${_enc(id)}/prompt', {
          'prompt': prompt,
          if (attachments != null && attachments.isNotEmpty)
            'attachments': attachments.map((code) => {'code': code}).toList(),
        })
        as Map<String, dynamic>;
    return j['messageId'] as String? ?? '';
  }

  // ---- attachment upload (memory-extension /api/v1/files) ----

  /// Uploads a single file via multipart and resolves to [UploadedFile].
  /// The content is deduplicated by sha256: an identical prior upload returns
  /// the same [code], so the model sees a stable `file:<code>` reference.
  Future<UploadedFile> uploadFile(UploadedFileSource src) async {
    final req = http.MultipartRequest(
      'POST',
      _u('/api/v1/files'),
    );
    req.headers['Authorization'] = _headers['Authorization'] ?? '';
    req.files.add(await http.MultipartFile.fromPath(
      'file',
      src.path,
      filename: src.name,
      contentType: MediaType.parse(src.mimeType),
    ));
    final streamed = await client.send(req);
    final resp = await http.Response.fromStream(streamed);
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) throw ApiException(resp.statusCode, resp.body);
    return UploadedFile.fromJson(j);
  }

  /// Streams the bytes of a previously uploaded file for preview/download.
  /// Uses plain GET to the files endpoint (supports image thumbnails).
  Future<List<int>> fetchFileBytes(String code) async {
    final r = await client.get(
      _u('/api/v1/files/$code'),
      headers: {'Authorization': _headers['Authorization'] ?? ''},
    );
    if (r.statusCode != 200) throw ApiException(r.statusCode, r.body);
    return r.bodyBytes;
  }

  /// Platform-relative path of a stored file (for streaming download +
  /// save-to-Downloads).
  String filePath(String code) => '/api/v1/files/$code';

  Future<(List<Message>, bool)> messages(String id,
      {String? before, int limit = 30}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final j = await _get('/api/v1/sessions/${_enc(id)}/messages', query)
        as Map<String, dynamic>;
    final msgs = _list(j, Message.fromJson, 'messages');
    return (msgs, msgs.length >= limit);
  }

  Future<String> switchModel(String id, String model) async {
    final j =
        await _post('/api/v1/sessions/${_enc(id)}/model', {'model': model})
            as Map<String, dynamic>;
    return j['model'] as String? ?? '';
  }

  Future<Session> settings(String id, Map<String, dynamic> settings) async {
    final body = Map<String, dynamic>.from(settings);
    body.removeWhere((_, v) => v == null);
    final j = await _patch('/api/v1/sessions/${_enc(id)}/settings', body)
        as Map<String, dynamic>;
    return Session.fromJson(j['session'] as Map<String, dynamic>);
  }

  Future<Session> fork(String id, String branch) async {
    final j = await _post('/api/v1/sessions/${_enc(id)}/fork', {'branch': branch})
        as Map<String, dynamic>;
    return Session.fromJson(j['session'] as Map<String, dynamic>);
  }

  Future<void> revert(String id, String? messageId) =>
      _post('/api/v1/sessions/${_enc(id)}/undo', {'message_id': messageId});

  Future<bool> interrupt(String id) async {
    final j = await _post('/api/v1/sessions/${_enc(id)}/interrupt', null)
        as Map<String, dynamic>;
    return j['interrupted'] == true;
  }

  Future<bool> compact(String id) async {
    final j = await _post('/api/v1/sessions/${_enc(id)}/compact', null);
    return j is Map ? j['ok'] == true : true;
  }

  Future<void> markRead(String id) =>
      _post('/api/v1/sessions/${_enc(id)}/read', null);

  Future<(String, List<dynamic>)> state(String id) async {
    final j = await _get('/api/v1/sessions/${_enc(id)}/state') as Map<String, dynamic>;
    return (j['status'] as String? ?? 'idle', (j['parts'] as List?) ?? []);
  }

  Future<List<MailboxEntry>> mailbox(String id) async {
    final j = await _get('/api/v1/sessions/${_enc(id)}/mailbox') as Map<String, dynamic>;
    return _list(j, MailboxEntry.fromJson, 'entries');
  }

  Future<List<ChangeEntry>> changes(String id) async {
    final j = await _get('/api/v1/sessions/${_enc(id)}/changes') as Map<String, dynamic>;
    return _list(j, ChangeEntry.fromJson, 'changes');
  }

  Future<List<Todo>> todos(String id) async {
    final j = await _get('/api/v1/sessions/${_enc(id)}/todos') as Map<String, dynamic>;
    return _list(j, Todo.fromJson, 'todos');
  }

  // ---- stream (SSE) ----

  Stream<StreamEvent> streamEvents(String sessionId) {
    final req = http.Request('GET', _u('/api/v1/sessions/${_enc(sessionId)}/stream'))
      ..headers.addAll(_headers);

    final ctrl = StreamController<StreamEvent>();
    late final http.Client client;
    client = this.client;
    client.send(req).then((resp) {
      if (resp.statusCode != 200) {
        ctrl.addError(ApiException(resp.statusCode, 'stream ${resp.statusCode}'));
        return;
      }
      resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (!line.startsWith('data:')) return;
          final data = line.substring(5).trim();
          if (data.isEmpty) return;
          try {
            final j = jsonDecode(data);
            if (j is Map<String, dynamic>) {
              ctrl.add(StreamEvent(
                  j['event'] as String? ?? '',
                  (j['params'] as Map?)?.cast<String, dynamic>()));
            }
          } catch (_) {}
        },
        onError: ctrl.addError,
        onDone: ctrl.close,
        cancelOnError: false,
      );
    }).catchError((Object e) {
      ctrl.addError(e);
      ctrl.close();
    });
    return ctrl.stream;
  }

  /// SSE task log: POST returns `{ok, build_id}`; this streams
  /// `/api/v1/builds/{id}/stream` with `log`/`state`/`done` events.
  Stream<dynamic> taskStream(String buildId) {
    final req = http.Request('GET', _u('/api/v1/builds/${_enc(buildId)}/stream'))
      ..headers.addAll(_headers);
    final ctrl = StreamController<dynamic>();
    final client = this.client;
    client.send(req).then((resp) {
      if (resp.statusCode != 200) {
        ctrl.addError(ApiException(resp.statusCode, 'stream ${resp.statusCode}'));
        return;
      }
      resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (!line.startsWith('data:')) return;
          final data = line.substring(5).trim();
          if (data.isEmpty) return;
          try {
            ctrl.add(jsonDecode(data));
          } catch (_) {}
        },
        onError: ctrl.addError,
        onDone: ctrl.close,
        cancelOnError: false,
      );
    }).catchError((Object e) {
      ctrl.addError(e);
      ctrl.close();
    });
    return ctrl.stream;
  }

  // ---- repos ----

  Future<List<OrgNode>> repos() async {
    final j = await _get('/api/v1/repos') as Map<String, dynamic>;
    return _list(j, OrgNode.fromJson, 'orgs');
  }

  Future<List<FileEntry>> listFiles(String org, String repo, String dir,
      [String? branch]) async {
    final query = <String, dynamic>{
      'org': org,
      'repo': repo,
      'path': dir,
      'depth': '1',
      if (branch != null && branch.isNotEmpty) 'branch': branch,
    };
    final j = await _get('/api/v1/fs/list', query) as Map<String, dynamic>;
    return _list(j, FileEntry.fromJson, 'entries');
  }

  Future<String> readFile(String org, String repo, String filePath,
      [String? branch]) async {
    final query = <String, dynamic>{
      'org': org,
      'repo': repo,
      'path': filePath,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
    };
    final j = await _get('/api/v1/fs/read', query) as Map<String, dynamic>;
    return j['content'] as String? ?? '';
  }

  Future<Session> forkRepo(Map<String, dynamic> params) async {
    final j = await _post('/api/v1/repos/fork', params) as Map<String, dynamic>;
    return Session.fromJson(j['session'] as Map<String, dynamic>);
  }

  Future<String> adoptSession(String org, String repo, String bookmark) async {
    final j = await _post(
      '/api/v1/repos/${_enc(org)}/${_enc(repo)}/bookmarks/${_enc(bookmark)}/session',
      null,
    ) as Map<String, dynamic>;
    return j['session_name'] as String? ?? '';
  }

  Future<void> ensureOrg(String org) => _post('/api/v1/repos/ensure-org', {'org': org});

  Future<void> ensureRepo(String org, String repo) =>
      _post('/api/v1/repos/ensure', {'org': org, 'repo': repo});

  Future<void> cloneRepo(String org, String repo, String gitUrl,
          [String? token, String? rev]) =>
      _post('/api/v1/repos/clone', {
        'org': org,
        'repo': repo,
        'git_url': gitUrl,
        'token': ?token,
        'rev': ?rev,
      });

  Future<void> deleteBookmark(String org, String repo, String bookmark) =>
      _del('/api/v1/repos/${_enc(org)}/${_enc(repo)}/${_enc(bookmark)}');

  Future<void> deleteRepo(String org, String repo) =>
      _del('/api/v1/repos/${_enc(org)}/${_enc(repo)}');

  Future<void> deleteOrg(String org) => _del('/api/v1/repos/${_enc(org)}');

  Future<List<DiffFile>> diffChange(
      String org, String repo, String changeId) async {
    final j = await _get(
        '/api/v1/repos/${_enc(org)}/${_enc(repo)}/diff/${_enc(changeId)}')
        as Map<String, dynamic>;
    return _list(j, DiffFile.fromJson, 'files');
  }

  /// Unified-diff of a change, resolved change_id → current commit_id →
  /// `/commits/{id}/diff` (jj `show` semantics — rebase-safe, because the
  /// change_id always resolves to its current visible commit).
  ///
  /// Returns the raw unified diff string (parse with [parseDiff]).
  Future<String> changeDiff(String org, String repo, String changeId,
      {String branch = ''}) async {
    // 1) change_id -> commit_id via /changes?rev=<branch> (change-id dedup).
    final changes = await _get(
      '/api/v1/repos/${_enc(org)}/${_enc(repo)}/changes',
      branch.isEmpty ? null : {'rev': branch},
    ) as Map<String, dynamic>;
    String? commitId;
    for (final c in (changes['changes'] as List? ?? [])) {
      final m = c as Map<String, dynamic>;
      if (m['change_id'] == changeId) {
        final cid = m['commit_id'] as String?;
        // Prefer a non-empty real sha. This is the CURRENT commit of the
        // change (change chain collapse), so it is rebase-stable.
        if (cid != null && cid.isNotEmpty) {
          commitId = cid;
          break;
        }
      }
    }
    if (commitId == null) return '';
    // 2) commit_id -> unified diff (before/after of this change).
    final j = await _get(
      '/api/v1/repos/${_enc(org)}/${_enc(repo)}/commits/${_enc(commitId)}/diff',
    ) as Map<String, dynamic>;
    return j['diff'] as String? ?? '';
  }

  Future<String> fileAtChange(
      String org, String repo, String changeId, String filePath) async {
    final j = await _get(
      '/api/v1/repos/${_enc(org)}/${_enc(repo)}/file/${_enc(changeId)}',
      {'path': filePath},
    ) as Map<String, dynamic>;
    return j['content'] as String? ?? '';
  }

  Future<List<FileCommit>> fileLog(String org, String repo, String filePath,
      [String? branch, int? limit]) async {
    final query = <String, dynamic>{
      'path': filePath,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
      'limit': ?limit,
    };
    final j = await _get(
      '/api/v1/repos/${_enc(org)}/${_enc(repo)}/file-log',
      query,
    ) as Map<String, dynamic>;
    return _list(j, FileCommit.fromJson, 'commits');
  }

  Future<String> fileDiff(
      String org, String repo, String changeId, String filePath) async {
    final j = await _get(
      '/api/v1/repos/${_enc(org)}/${_enc(repo)}/file-diff/${_enc(changeId)}',
      {'path': filePath},
    ) as Map<String, dynamic>;
    return j['diff'] as String? ?? '';
  }

  Future<List<FileCommit>> log(String org, String repo,
      {String? rev, int? limit}) async {
    final query = <String, dynamic>{
      'rev': ?rev,
      'limit': ?limit,
    };
    final j = await _get('/api/v1/repos/${_enc(org)}/${_enc(repo)}/log', query)
        as Map<String, dynamic>;
    return _list(j, FileCommit.fromJson, 'commits');
  }

  /// Set an extension config knob by id (e.g. memory/vlm_model). Delivers the
  /// validated change to the extension so tools pick it up immediately.
  Future<void> setToolConfigValue(
          String extId, String name, Object? value) async =>
      _put('/api/v1/tool-config/${_enc(extId)}/${_enc(name)}',
          {'value': value});

  Future<List<GitTag>> tags(String org, String repo) async {
    final j = await _get('/api/v1/repos/${_enc(org)}/${_enc(repo)}/tags')
        as Map<String, dynamic>;
    return _list(j, GitTag.fromJson, 'tags');
  }

  Future<List<BranchInfo>> branches(String org, String repo) async {
    final j = await _get('/api/v1/repos/${_enc(org)}/${_enc(repo)}/branches')
        as Map<String, dynamic>;
    return _list(j, BranchInfo.fromJson, 'branches');
  }

  Future<List<Release>> releases(String org, String repo) async {
    final j = await _get('/api/v1/repos/${_enc(org)}/${_enc(repo)}/releases')
        as Map<String, dynamic>;
    return _list(j, Release.fromJson, 'releases');
  }

  /// Platform-relative path of a release asset download.
  String assetPath(String org, String repo, String tag, String name) =>
      '/api/v1/repos/${_enc(org)}/${_enc(repo)}/releases/${_enc(tag)}/assets/${_enc(name)}';

  /// Platform-relative path of a source tarball for a rev/tag.
  String archivePath(String org, String repo, String rev) =>
      '/api/v1/repos/${_enc(org)}/${_enc(repo)}/archive/tarball/${_enc(rev)}';

  /// Streams an authenticated GET [path] (relative to baseUrl) into [sink],
  /// reporting progress. Used for release assets and source tarballs.
  Future<int> streamTo(String path, IOSink sink,
      {void Function(int received, int total)? onProgress}) async {
    final req = http.Request('GET', _u(path));
    req.headers.addAll(_headers);
    final resp = await client.send(req).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, await resp.stream.bytesToString());
    }
    final total = resp.contentLength ?? 0;
    var received = 0;
    await for (final chunk in resp.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }
    await sink.flush();
    return received;
  }

  Future<List<String>> blame(
      String org, String repo, String rev, String filePath) async {
    final j = await _get('/api/v1/git-blame/${_enc(org)}/${_enc(repo)}',
        {'rev': rev, 'path': filePath}) as Map<String, dynamic>;
    return ((j['blame'] as List?) ?? []).map((e) => e.toString()).toList();
  }

  Future<Map<String, dynamic>> mirrorSync(
      String org, String repo, String kind, Map<String, dynamic> body) async {
    return await _post(
            '/api/v1/repos/${_enc(org)}/${_enc(repo)}/$kind', body)
        as Map<String, dynamic>;
  }

  Future<MirrorCfg> getMirror(String org, String repo) async {
    final j = await _get(
            '/api/v1/repos/${_enc(org)}/${_enc(repo)}/mirror')
        as Map<String, dynamic>;
    return MirrorCfg(
      pullUrl: j['pull_url'] as String? ?? '',
      pushUrl: j['push_url'] as String? ?? '',
      pushSecretSet: j['push_secret_set'] as bool? ?? false,
    );
  }

  Future<void> setMirror(String org, String repo,
      {String pullUrl = '',
      String pushUrl = '',
      String? pushSecret}) async {
    await _put('/api/v1/repos/${_enc(org)}/${_enc(repo)}/mirror', {
      if (pullUrl.isNotEmpty) 'pull_url': pullUrl,
      if (pushUrl.isNotEmpty) 'push_url': pushUrl,
      if (pushSecret != null && pushSecret.isNotEmpty)
        'push_secret': pushSecret,
    });
  }

  Future<void> delMirror(String org, String repo) =>
      _del('/api/v1/repos/${_enc(org)}/${_enc(repo)}/mirror');

  // ---- config / providers / models / presets / tools ----

  Future<Map<String, String>> config() async {
    final j = await _get('/api/v1/config') as Map<String, dynamic>;
    return j.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<void> setConfig(Map<String, String> entries) =>
      _put('/api/v1/config', entries);

  Future<Map<String, ProviderInfo>> providers() async {
    final j = await _get('/api/v1/providers') as Map<String, dynamic>;
    final m = (j['providers'] as Map?)?.cast<String, dynamic>() ?? {};
    return m.map((k, v) =>
        MapEntry(k, ProviderInfo.fromJson(v as Map<String, dynamic>)));
  }

  Future<void> registerProvider(ProviderInfo p) =>
      _post('/api/v1/providers', p.toJson());

  Future<void> deleteProvider(String pid) =>
      _del('/api/v1/providers/${_enc(pid)}');

  Future<Map<String, dynamic>> testProvider(
          {required String apiType,
          required String baseUrl,
          required String apiKey}) async =>
      await _post('/api/v1/providers/test', {
        'api_type': apiType,
        'base_url': baseUrl,
        'api_key': apiKey,
      }) as Map<String, dynamic>;

  Future<List<ModelInfo>> models() async {
    final j = await _get('/api/v1/models') as Map<String, dynamic>;
    return _list(j, ModelInfo.fromJson, 'models');
  }

  Future<List<Preset>> presets() async {
    final j = await _get('/api/v1/presets') as List;
    return j.map((e) => Preset.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> savePreset(Preset p) => _post('/api/v1/presets', p.toJson());

  Future<void> deletePreset(String id) => _del('/api/v1/presets/${_enc(id)}');

  Future<List<ToolInfo>> tools({String? locale}) async {
    final query = <String, dynamic>{if (locale != null && locale.isNotEmpty) 'locale': locale};
    final j = await _get('/api/v1/tools', query.isEmpty ? null : query)
        as Map<String, dynamic>;
    return _list(j, ToolInfo.fromJson, 'tools');
  }

  /// Set a single agent config key (e.g. locale) via `PUT /api/v1/config`.
  Future<void> setConfigKey(String key, String value) =>
      _put('/api/v1/config', {'key': key, 'value': value});

  /// Per-session language override (`PATCH /sessions/{id}/settings`).
  Future<Session> sessionLocale(String id, String locale) =>
      settings(id, {'locale': locale});

  Future<Map<String, dynamic>> toolConfig() async =>
      await _get('/api/v1/tool-config') as Map<String, dynamic>;

  Future<Map<String, dynamic>> setToolConfig(Map<String, dynamic> cfg) async {
    final j = await _put('/api/v1/tool-config', cfg) as Map<String, dynamic>;
    return (j['config'] as Map?)?.cast<String, dynamic>() ?? cfg;
  }

  // ---- infra ----

  Future<Map<String, dynamic>> k8sConfig() async =>
      await _get('/api/v1/infra/k8s/config') as Map<String, dynamic>;

  // ---- containers / ops ----

  Future<List<Sandbox>> sandboxes() async {
    final j = await _get('/api/v1/sandboxes') as Map<String, dynamic>;
    return _list(j, Sandbox.fromJson, 'sandboxes');
  }

  Future<List<Deployment>> deployments() async {
    final j = await _get('/api/v1/deployments') as Map<String, dynamic>;
    return _list(j, Deployment.fromJson, 'deployments');
  }

  Future<List<DeploymentPod>> deploymentPods(String name) async {
    final j = await _get('/api/v1/deployments/${_enc(name)}/pods')
        as Map<String, dynamic>;
    return _list(j, DeploymentPod.fromJson, 'pods');
  }

  Future<List<DeploymentEvent>> deploymentEvents(String name) async {
    final j = await _get('/api/v1/deployments/${_enc(name)}/events')
        as Map<String, dynamic>;
    return _list(j, DeploymentEvent.fromJson, 'events');
  }

  Future<void> restartDeployment(String name) =>
      _post('/api/v1/deployments/${_enc(name)}/restart', null);

  Future<Map<String, dynamic>> deploymentStatus(String name) async =>
      await _get('/api/v1/deployments/${_enc(name)}/status')
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> deploy(Map<String, dynamic> body) async =>
      await _post('/api/v1/deployments', body) as Map<String, dynamic>;

  Future<void> destroySandbox(String session) =>
      _del('/api/v1/sandboxes/${_enc(session)}');

  Future<void> destroyDeployment(String name) =>
      _del('/api/v1/deployments/${_enc(name)}');

  Future<OpsStatus> status() async {
    final j = await _get('/api/v1/status') as Map<String, dynamic>;
    return OpsStatus.fromJson(j);
  }

  Future<List<ContainerfileTemplate>> containerfileTemplates() async {
    final j = await _get('/api/v1/containerfile-templates')
        as Map<String, dynamic>;
    return _list(j, ContainerfileTemplate.fromJson, 'templates');
  }

  Future<Map<String, dynamic>> buildImage(Map<String, dynamic> body) async =>
      await _post('/api/v1/images/build', body) as Map<String, dynamic>;

  Future<List<PublishSpec>> publishSpecs() async {
    final j = await _get('/api/v1/publish-specs') as Map<String, dynamic>;
    return _list(j, PublishSpec.fromJson, 'specs');
  }

  Future<Map<String, dynamic>> publishPackage(Map<String, dynamic> body) async =>
      await _post('/api/v1/packages/publish', body) as Map<String, dynamic>;

  Future<List<JobInfo>> jobs(String session) async {
    final j = await _get('/api/v1/sandboxes/${_enc(session)}/jobs')
        as Map<String, dynamic>;
    final jobsMap = j['jobs'];
    if (jobsMap is Map && jobsMap['jobs'] is List) {
      return ((jobsMap['jobs']) as List)
          .map((e) => JobInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  Future<ExecResult> exec(String session, String command) async {
    final j = await _post('/api/v1/sandboxes/${_enc(session)}/exec', {
      'command': command,
    }) as Map<String, dynamic>;
    return ExecResult.fromJson(j);
  }

  Future<void> kill(String session, String jobId) =>
      _post('/api/v1/sandboxes/${_enc(session)}/jobs/${_enc(jobId)}/kill', null);

  Future<Map<String, dynamic>> jobOutput(
      String session, String jobId, String stream, int start, int end) async {
    final j = await _get(
      '/api/v1/sandboxes/${_enc(session)}/jobs/${_enc(jobId)}/output',
      {'stream': stream, 'start': start, 'end': end},
    ) as Map<String, dynamic>;
    return j;
  }

  // ---- packages ----

  Future<List<PackageTypeEntry>> listPackageTypes() async {
    final j = await _get('/api/v1/packages') as Map<String, dynamic>;
    return _list(j, PackageTypeEntry.fromJson, 'types');
  }

  Future<Map<String, dynamic>> listAllPackages(
      {String? type, String? q, int? limit, int? offset}) async {
    final query = <String, dynamic>{
      if (type != null && type.isNotEmpty) 'type': type,
      if (q != null && q.isNotEmpty) 'q': q,
      'limit': ?limit,
      'offset': ?offset,
    };
    return await _get('/api/v1/packages/list', query) as Map<String, dynamic>;
  }

  Future<PackageInfo2> packageVersions(String type, String name) async {
    final j = await _get(
            '/api/v1/packages/${_enc(type)}/${_enc(name)}/versions')
        as Map<String, dynamic>;
    final data = (j['data'] as Map?)?.cast<String, dynamic>() ?? {};
    return PackageInfo2(
      name: data['name'] as String? ?? name,
      type: data['type'] as String? ?? type,
      versions: ((data['versions'] as List?) ?? [])
          .map((e) => PackageVersion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> deletePackage(String type, String name) =>
      _del('/api/v1/packages/${_enc(type)}/${_enc(name)}');

  Future<void> deletePackageVersion(
          String type, String name, String version) =>
      _del('/api/v1/packages/${_enc(type)}/${_enc(name)}/${_enc(version)}');

  Future<List<String>> ociCatalog() async {
    final j = await client.get(
      Uri.parse('$baseUrl/v2/_catalog'),
      headers: _headers,
    );
    final body = _decode(j) as Map<String, dynamic>;
    return ((body['repositories'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
  }
}

class PackageInfo2 {
  final String name;
  final String type;
  final List<PackageVersion> versions;
  PackageInfo2(
      {required this.name, required this.type, required this.versions});
}

class ApiException implements Exception {
  final int status;
  final String body;
  ApiException(this.status, this.body);
  @override
  String toString() =>
      'HTTP $status: ${body.length > 300 ? body.substring(0, 300) : body}';
}