import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'i18n.dart';
import 'models.dart';

/// Mirrors hooks/useMessages.svelte.ts + message-utils.ts.
class MessagesController extends ChangeNotifier {
  MessagesController({required this.api, required this.getSessionId});

  final ZergxApi api;
  final String Function() getSessionId;

  List<ChatMessage> messages = [];
  bool sending = false;
  bool loading = false;
  bool hasMore = false;

  StreamSubscription<StreamEvent>? _sub;
  String? _streamingId;
  int _nextSeq = 1000000;
  final List<void Function(String event, Map<String, dynamic> params)>
      _sessionListeners = [];

  List<ChatMessage> get sorted {
    final m = [...messages];
    m.sort(compareMessages);
    return m;
  }

  void Function() onSessionEvent(
      void Function(String event, Map<String, dynamic> params) cb) {
    _sessionListeners.add(cb);
    return () => _sessionListeners.remove(cb);
  }

  int _allocSeq() => _nextSeq++;

  void _bumpSeqAfter(List<ChatMessage> history) {
    var maxSeq = -1;
    for (final m in history) {
      final s = m.seq;
      if (s != null && s < _nextSeq && s > maxSeq) maxSeq = s;
    }
    if (maxSeq >= 0) _nextSeq = maxSeq + 1;
  }

  void init() {
    final sid = getSessionId();
    if (sid.isEmpty) return;
    _fetchMessages();
    _recover();
    _connect(sid);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  Future<void> _fetchMessages([String? before]) async {
    loading = true;
    notifyListeners();
    try {
      final sid = getSessionId();
      final (msgs, more) =
          await api.messages(sid, before: before, limit: 50);
      final chat = mapMessagesToChat(msgs);
      _bumpSeqAfter(chat);
      if (before != null) {
        final existing = messages.map((m) => m.id).toSet();
        messages = [...chat.where((m) => !existing.contains(m.id)), ...messages];
      } else {
        final pending =
            messages.where((m) => m.status == 'pending').toList();
        messages = [...pending, ...chat];
      }
      hasMore = more;
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  Future<void> _recover() async {
    try {
      final (status, _) = await api.state(getSessionId());
      if (status == 'busy' || status == 'running') {
        sending = true;
        _streamingId = 'recover-${DateTime.now().microsecondsSinceEpoch}';
        messages = [
          ...messages,
          ChatMessage(
              id: _streamingId!,
              role: 'assistant',
              status: 'streaming',
              parts: [],
              createdAt: DateTime.now().toIso8601String(),
              seq: _allocSeq()),
        ];
        notifyListeners();
      }
    } catch (_) {}
  }

  void _connect(String sid) {
    _sub?.cancel();
    _sub = api.streamEvents(sid).listen(_handleEvent,
        onError: (_) {}, onDone: () {});
  }

  void _handleEvent(StreamEvent ev) {
    for (final cb in _sessionListeners) {
      try {
        cb(ev.event, ev.params);
      } catch (_) {}
    }
        final event = ev.event;
        final params = ev.params;
        // A worksheet proposal surfaces as a system notification in the chat
        // stream (approve/reject lives in the Worksheets tab).
        if (event == 'worksheet-proposed') {
          _addSystem(I18n.now.worksheetProposed(
            (params['action'] ?? params['title'] ?? '').toString(),
            (params['title'] ?? '').toString(),
          ));
        }
        switch (event) {
      case 'step-start':
      case 'text-start':
      case 'reasoning-start':
      case 'tool-input-start':
        final current = _streamingId != null
            ? messages.where((m) => m.id == _streamingId).firstOrNull
            : null;
        final hasToolPart =
            current?.parts.any((p) => p.type == 'tool') ?? false;
        final sid = _ensureStreamingMsg(
            event == 'step-start' || (event == 'text-start' && hasToolPart));
        if (event == 'text-start' && params['id'] != null) {
          _ensurePart(sid, params['id'] as String, 'text');
        } else if (event == 'reasoning-start' && params['id'] != null) {
          _ensurePart(sid, 'r${params['id']}', 'reasoning');
        }
        break;
      case 'text-delta':
        if (params['id'] != null && params['text'] != null) {
          final sid = _ensureStreamingMsg(false);
          _appendDelta(sid, params['id'] as String,
              params['text'] as String? ?? '', false);
        }
        break;
      case 'reasoning-delta':
        if (params['id'] != null && params['text'] != null) {
          final sid = _ensureStreamingMsg(false);
          _appendDelta(
              sid, 'r${params['id']}', params['text'] as String? ?? '', true);
        }
        break;
      case 'tool-call':
        final sid = _ensureStreamingMsg(false);
        final tcId = (params['toolCallId'] ?? params['id']) as String?;
        if (tcId != null) {
          _addToolPart(sid, tcId,
              (params['toolName'] ?? params['name'] ?? 'tool') as String,
              params['input']);
        }
        break;
      case 'tool-result':
        final tcId = (params['toolCallId'] ?? params['id']) as String?;
        if (tcId == null) break;
        _updateToolResult(tcId,
            params['formatted'] ?? params['output'] ?? params['result'],
            changeId: params['change_id'] as String?,
            diff: params['diff'] as String?,
            additions: params['additions'] as int?,
            deletions: params['deletions'] as int?);
        break;
      case 'tool-error':
        final tcId = (params['toolCallId'] ?? params['id']) as String?;
        final errObj = params['error'];
        final errMsg = errObj is String
            ? errObj
            : (errObj is Map
                ? (errObj['message'] ?? params['message'] ?? 'tool error')
                : (params['message'] ?? 'tool error')) as String;
        if (tcId != null) _updateToolResult(tcId, null, errorMsg: errMsg);
        break;
      case 'turn-complete':
        _finishStreaming();
        break;
      case 'status':
        final stype = params['type'];
        if (stype == 'busy' || stype == 'running') {
          sending = true;
          notifyListeners();
        } else {
          _finishStreaming();
        }
        break;
      case 'error':
      case 'provider-error':
        final errObj = params['error'];
        final content = errObj is String
            ? errObj
            : (errObj is Map
                ? (errObj['message'] ?? params['message'] ?? 'Unknown error')
                : (params['message'] ?? 'Unknown error')) as String;
        _addError(content);
        sending = false;
        notifyListeners();
        break;
      default:
        break;
    }
  }

  String _ensureStreamingMsg(bool forceNew) {
    if (!forceNew && _streamingId != null) {
      if (messages.any((m) => m.id == _streamingId)) return _streamingId!;
    }
    final id = 'm${DateTime.now().microsecondsSinceEpoch}';
    _streamingId = id;
    messages = [
      ...messages,
      ChatMessage(
          id: id,
          role: 'assistant',
          status: 'streaming',
          parts: [],
          createdAt: DateTime.now().toIso8601String(),
          seq: _allocSeq()),
    ];
    return id;
  }

  void _ensurePart(String msgId, String partId, String type) {
    final idx = messages.indexWhere((m) => m.id == msgId);
    if (idx < 0) return;
    if (messages[idx].parts.any((p) => p.id == partId)) return;
    final next = [...messages];
    next[idx] = messages[idx]
        .copyWith(parts: [...messages[idx].parts, ChatPart(id: partId, type: type)]);
    messages = next;
  }

  void _appendDelta(String msgId, String partId, String delta, bool reasoning) {
    final idx = messages.indexWhere((m) => m.id == msgId);
    if (idx < 0) return;
    final parts = [...messages[idx].parts];
    final pidx = parts.indexWhere((p) => p.id == partId);
    if (pidx >= 0) {
      parts[pidx] =
          parts[pidx].copyWith(text: (parts[pidx].text) + delta);
    } else {
      parts.add(ChatPart(id: partId, type: reasoning ? 'reasoning' : 'text', text: delta));
    }
    final next = [...messages];
    next[idx] = messages[idx].copyWith(parts: parts);
    messages = next;
    notifyListeners();
  }

  void _addToolPart(String msgId, String partId, String name, Object? input) {
    final idx = messages.indexWhere((m) => m.id == msgId);
    if (idx < 0) return;
    final parts = [...messages[idx].parts];
    final pidx = parts.indexWhere((p) => p.id == partId);
    if (pidx >= 0) {
      parts[pidx] = ChatPart(
          id: partId,
          type: 'tool',
          tool: name,
          state: ToolState(
              status: 'running', title: name, input: _asMap(input)));
    } else {
      parts.add(ChatPart(
          id: partId,
          type: 'tool',
          tool: name,
          state: ToolState(
              status: 'running', title: name, input: _asMap(input))));
    }
    final next = [...messages];
    next[idx] = messages[idx].copyWith(parts: parts);
    messages = next;
    notifyListeners();
  }

  void _updateToolResult(String partId, Object? result,
      {String? errorMsg, String? changeId, String? diff, int? additions, int? deletions}) {
    final sid = _streamingId;
    if (sid == null) return;
    final idx = messages.indexWhere((m) => m.id == sid);
    if (idx < 0) return;
    final parts = messages[idx].parts.map((p) {
      if (p.id != partId) return p;
      final old = p.state ?? ToolState();
      final output = result is String
          ? result
          : (result == null ? null : _pretty(result));
      return ChatPart(
        id: p.id,
        type: 'tool',
        tool: p.tool,
        state: ToolState(
          status: errorMsg != null ? 'error' : 'complete',
          title: old.title,
          error: errorMsg ?? old.error,
          input: old.input,
          output: output ?? old.output,
          changeId: changeId ?? old.changeId,
          diff: diff ?? old.diff,
          additions: additions ?? old.additions,
          deletions: deletions ?? old.deletions,
        ),
      );
    }).toList();
    final next = [...messages];
    next[idx] = messages[idx].copyWith(parts: parts);
    messages = next;
    notifyListeners();
  }

  void _finishStreaming() {
    if (_streamingId != null) {
      final idx = messages.indexWhere((m) => m.id == _streamingId);
      if (idx >= 0) {
        final next = [...messages];
        next[idx] = messages[idx].copyWith(status: 'complete');
        messages = next;
      }
    }
    _streamingId = null;
    sending = false;
    notifyListeners();
  }

  void _addError(String text) {
    messages = [
      ...messages.where((m) => m.status != 'streaming'),
      ChatMessage(
          id: 'err${DateTime.now().microsecondsSinceEpoch}',
          role: 'error',
          status: 'error',
          parts: [ChatPart(id: 'p${DateTime.now().microsecondsSinceEpoch}', type: 'text', text: text)],
          createdAt: DateTime.now().toIso8601String(),
          seq: _allocSeq()),
    ];
    _streamingId = null;
  }

  /// A system notification message (e.g. a worksheet proposal), rendered as
  /// a centered system bubble.
  void _addSystem(String text) {
    messages = [
      ...messages,
      ChatMessage(
          id: 'sys${DateTime.now().microsecondsSinceEpoch}',
          role: 'system',
          status: 'complete',
          parts: [ChatPart(id: 'p${DateTime.now().microsecondsSinceEpoch}', type: 'text', text: text)],
          createdAt: DateTime.now().toIso8601String(),
          seq: _allocSeq()),
    ];
    notifyListeners();
  }

  Future<void> send(String text, [List<UploadedFile> attachments = const []]) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && attachments.isEmpty) || sending) return;
    sending = true;
    // The platform splices attachment codes into `[附件 …file:<code>…]`
    // references; the client only sends the codes, never the rendered text.
    final codes = attachments.map((a) => a.code).toList();
    messages = [
      ...messages.where((m) => m.status != 'streaming'),
      ChatMessage(
          id: 'u${DateTime.now().microsecondsSinceEpoch}',
          role: 'user',
          status: 'pending',
          parts: [
            ChatPart(
                id: 'p${DateTime.now().microsecondsSinceEpoch}',
                type: 'text',
                text: trimmed)
          ],
          createdAt: DateTime.now().toIso8601String(),
          seq: _allocSeq()),
    ];
    final _ = _ensureStreamingMsg(true);
    notifyListeners();
    try {
      final messageId =
          await api.prompt(getSessionId(), trimmed, attachments: codes);
      if (messageId.isNotEmpty) {
        messages = messages.map((m) {
          if (m.status == 'pending' && m.role == 'user') {
            return m.copyWith(id: messageId, status: 'complete');
          }
          return m;
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      _addError(e is ApiException
          ? e.toString()
          : I18n.now.sendFailed('$e'));
      sending = false;
      notifyListeners();
    }
  }

  void stop() {
    api.interrupt(getSessionId()).then((_) => _finishStreaming());
  }

  Future<void> revert(String messageId) async {
    final current = sorted;
    if (sending) {
      await api.interrupt(getSessionId());
    }
    await api.revert(getSessionId(), messageId);
    final idx = current.indexWhere((m) => m.id == messageId);
    final keep = idx >= 0 ? current.sublist(0, idx) : current;
    messages = keep
        .map((m) =>
            m.status == 'streaming' ? m.copyWith(status: 'complete') : m)
        .toList();
    _streamingId = null;
    sending = false;
    notifyListeners();
    await _fetchMessages();
  }

  Future<void> loadMore() async {
    if (!hasMore || loading) return;
    final first = sorted.firstOrNull;
    if (first == null) return;
    await _fetchMessages(first.id);
  }

  static Map<String, dynamic>? _asMap(Object? o) {
    if (o is Map) return o.cast<String, dynamic>();
    return null;
  }

  static String _pretty(Object o) {
    if (o is Map || o is List) {
      const enc = JsonEncoder.withIndent('  ');
      return enc.convert(o);
    }
    return o.toString();
  }
}

extension on List<ChatMessage> {
  ChatMessage? get firstOrNull => isEmpty ? null : first;
}

int compareMessages(ChatMessage a, ChatMessage b) {
  final at = a.seq ?? 1 << 60;
  final bt = b.seq ?? 1 << 60;
  if (at != bt) return at - bt;
  final apt = DateTime.tryParse(a.createdAt)?.millisecondsSinceEpoch ?? 0;
  final bpt = DateTime.tryParse(b.createdAt)?.millisecondsSinceEpoch ?? 0;
  if (apt != 0 && bpt != 0 && apt != bpt) return apt - bpt;
  return a.id.compareTo(b.id);
}

List<ChatMessage> mapMessagesToChat(List<Message> msgs) {
  return [for (var i = 0; i < msgs.length; i++) _toChat(msgs[i], i)];
}

ChatMessage _toChat(Message m, int i) {
  return ChatMessage(
    id: m.id,
    role: m.role,
    status: 'complete',
    createdAt: m.createdAt ?? '',
    seq: i,
    parts: [
      for (final p in m.parts)
        ChatPart(
          id: p.id.isNotEmpty ? p.id : 'p${DateTime.now().microsecondsSinceEpoch}$i',
          type: p.type,
          text: p.text ?? '',
          tool: p.tool ?? '',
          state: p.state,
        ),
    ],
  );
}

