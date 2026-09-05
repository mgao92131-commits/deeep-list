import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../application/node_page_controller.dart';
import '../domain/node.dart';
import '../domain/node_id.dart';
import 'editor_session.dart';
import 'node_list.dart';

class NodePage extends ConsumerStatefulWidget {
  final NodeId? parentId;

  const NodePage({super.key, required this.parentId});

  @override
  ConsumerState<NodePage> createState() => _NodePageState();
}

class _NodePageState extends ConsumerState<NodePage>
    with RouteAware, WidgetsBindingObserver {
  static const _autosaveDelay = Duration(milliseconds: 400);

  late final EditorSession _editorSession;
  final _mutationQueue = _MutationQueue();
  final _structuralCommandsInFlight = <NodeId>{};
  Timer? _autosaveTimer;
  NodeId? _pendingAutosaveNodeId;
  String? _pendingAutosaveText;
  Future<bool>? _autosaveInFlight;
  bool _routeSubscribed = false;

  @override
  void initState() {
    super.initState();
    _editorSession = EditorSession();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      routeObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void didPushNext() {
    unawaited(_finishEditingForRouteChange());
  }

  @override
  void didPop() {
    unawaited(_finishEditingForRouteChange());
  }

  @override
  void didPopNext() {
    // Returning to a page must not reopen its previous editor or keyboard.
    unawaited(_finishEditingForRouteChange());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // This is best-effort for a process that is killed immediately, while
      // the debounce below protects ordinary backgrounding and navigation.
      unawaited(_flushPendingEdit(commitCurrent: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
    }
    _editorSession.dispose();
    super.dispose();
  }

  Future<bool> _finishEditingForRouteChange() async {
    final saved = await _flushPendingEdit(commitCurrent: true);
    if (mounted) {
      ref
          .read(nodePageControllerProvider(widget.parentId).notifier)
          .endEditing();
    }
    return saved;
  }

  Future<void> _startEditing(Node node) async {
    ref
        .read(nodePageControllerProvider(widget.parentId).notifier)
        .startEditing(node.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editorSession.focus(node.id, cursor: node.content.length);
    });
  }

  void _scheduleAutosave(NodeId nodeId, String text) {
    _pendingAutosaveNodeId = nodeId;
    _pendingAutosaveText = text;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, _startPendingAutosave);
  }

  void _startPendingAutosave() {
    _autosaveTimer = null;
    final nodeId = _pendingAutosaveNodeId;
    final text = _pendingAutosaveText;
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;
    if (nodeId == null || text == null) return;

    final save = _saveContent(nodeId, text);
    _autosaveInFlight = save;
    unawaited(
      save.then((_) {
        if (identical(_autosaveInFlight, save)) {
          _autosaveInFlight = null;
        }
      }),
    );
  }

  Future<bool> _saveContent(NodeId nodeId, String text) async {
    try {
      final commands = ref.read(treeCommandServiceProvider);
      await _mutationQueue.add(() => commands.updateContent(nodeId, text));
      return true;
    } catch (error) {
      _showMutationError(error);
      return false;
    }
  }

  Future<void> _commit(NodeId nodeId, String text) async {
    if (_pendingAutosaveNodeId == nodeId) {
      _autosaveTimer?.cancel();
      _autosaveTimer = null;
      _pendingAutosaveNodeId = null;
      _pendingAutosaveText = null;
    }
    await _saveContent(nodeId, text);
  }

  Future<T?> _runMutation<T>(Future<T> Function() mutation) async {
    try {
      return await _mutationQueue.add(mutation);
    } catch (error) {
      _showMutationError(error);
      return null;
    }
  }

  Future<void> _drainAutosaveForStructuralCommand() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    // Enter supplies the complete controller value directly to splitNode. A
    // pending debounced update must not write a partial value before it.
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;
    final inFlight = _autosaveInFlight;
    if (inFlight != null) await inFlight;
    await _mutationQueue.idle;
  }

  Future<bool> _flushPendingEdit({required bool commitCurrent}) async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    final pendingNodeId = _pendingAutosaveNodeId;
    final pendingText = _pendingAutosaveText;
    _pendingAutosaveNodeId = null;
    _pendingAutosaveText = null;

    var saved = true;
    if (commitCurrent && pendingNodeId != null && pendingText != null) {
      if (!await _saveContent(pendingNodeId, pendingText)) saved = false;
    }

    if (commitCurrent) {
      final activeNodeId = _editorSession.activeNodeId;
      final activeText = _editorSession.activeText;
      final pendingWasActive =
          pendingNodeId == activeNodeId && pendingText == activeText;
      if (activeNodeId != null && activeText != null && !pendingWasActive) {
        if (!await _saveContent(activeNodeId, activeText)) saved = false;
      }
    }

    final inFlight = _autosaveInFlight;
    if (inFlight != null && !await inFlight) saved = false;
    await _mutationQueue.idle;
    _editorSession.unfocus();
    return saved;
  }

  Future<void> _handleEnter(Node node, int cursor, String text) async {
    if (!_structuralCommandsInFlight.add(node.id)) return;
    _editorSession.suppressBlurCommit(node.id);
    try {
      await _drainAutosaveForStructuralCommand();
      final result = await _runMutation(
        () => ref
            .read(treeCommandServiceProvider)
            .splitNode(nodeId: node.id, cursorPosition: cursor, text: text),
      );
      if (result == null) {
        if (mounted) _scheduleAutosave(node.id, text);
        return;
      }
      if (!mounted) return;

      ref
          .read(nodePageControllerProvider(widget.parentId).notifier)
          .startEditing(result.newNodeId);
      _editorSession.focus(result.newNodeId, cursor: result.cursorPosition);
    } finally {
      _editorSession.allowBlurCommit(node.id);
      _structuralCommandsInFlight.remove(node.id);
    }
  }

  Future<void> _handleBackspace(Node node, int cursor, String text) async {
    if (!_structuralCommandsInFlight.add(node.id)) return;
    _editorSession.suppressBlurCommit(node.id);
    try {
      if (!await _flushPendingEdit(commitCurrent: true)) return;
      final result = await _runMutation(
        () => ref.read(treeCommandServiceProvider).mergeWithPrevious(node.id),
      );
      if (result == null || !mounted) return;

      ref
          .read(nodePageControllerProvider(widget.parentId).notifier)
          .startEditing(result.targetNodeId);
      _editorSession.focus(result.targetNodeId, cursor: result.cursorPosition);
    } finally {
      _editorSession.allowBlurCommit(node.id);
      _structuralCommandsInFlight.remove(node.id);
    }
  }

  Future<void> _openNode(Node node) async {
    if (!await _finishEditingForRouteChange()) return;
    if (!mounted) return;
    context.push('/node/${node.id}');
  }

  Future<void> _createNode() async {
    if (!await _finishEditingForRouteChange()) return;
    final node = await _runMutation(
      () => ref
          .read(treeCommandServiceProvider)
          .createNode(parentId: widget.parentId, content: ''),
    );
    if (node == null || !mounted) return;
    ref
        .read(nodePageControllerProvider(widget.parentId).notifier)
        .startEditing(node.id);
    _editorSession.focus(node.id, cursor: 0);
  }

  Future<void> _popPage() async {
    if (!await _finishEditingForRouteChange()) return;
    if (mounted && context.canPop()) {
      context.pop();
    }
  }

  void _showMutationError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not save that change: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenProvider(widget.parentId));
    final pageState = ref.watch(nodePageControllerProvider(widget.parentId));
    final parent = widget.parentId == null
        ? null
        : ref.watch(nodeProvider(widget.parentId!)).value;

    return PopScope<void>(
      // Keep the platform route available for Android predictive back and the
      // iOS edge-swipe. Autosave/lifecycle flushing is deliberately best-effort
      // after the platform has accepted the pop.
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(_flushPendingEdit(commitCurrent: true));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.parentId == null ? 'DeepList' : parent?.content ?? '',
          ),
          leading: widget.parentId == null
              ? null
              : IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => unawaited(_popPage()),
                ),
        ),
        body: children.when(
          data: (nodes) => NodeList(
            nodes: nodes,
            editingNodeId: pageState.editingNodeId,
            editorSession: _editorSession,
            onStartEditing: _startEditing,
            onCommit: _commit,
            onChanged: (node, text) => _scheduleAutosave(node.id, text),
            onEnter: _handleEnter,
            onBackspace: _handleBackspace,
            onNavigate: _openNode,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('Unable to load nodes: $error')),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Add node',
          onPressed: () => unawaited(_createNode()),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _MutationQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> add<T>(Future<T> Function() operation) {
    final result = _tail.then<T>((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<void> get idle => _tail;
}
