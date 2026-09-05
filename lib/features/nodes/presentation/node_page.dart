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

class _NodePageState extends ConsumerState<NodePage> with RouteAware {
  late final EditorSession _editorSession;
  bool _routeSubscribed = false;

  @override
  void initState() {
    super.initState();
    _editorSession = EditorSession();
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
  void dispose() {
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
    }
    _editorSession.dispose();
    super.dispose();
  }

  Future<void> _finishEditingForRouteChange() async {
    await _editorSession.endEditing();
    if (mounted) {
      ref
          .read(nodePageControllerProvider(widget.parentId).notifier)
          .endEditing();
    }
  }

  Future<void> _startEditing(Node node) async {
    ref
        .read(nodePageControllerProvider(widget.parentId).notifier)
        .startEditing(node.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editorSession.focus(node.id, cursor: node.content.length);
    });
  }

  Future<void> _commit(NodeId nodeId, String text) async {
    await ref.read(treeCommandServiceProvider).updateContent(nodeId, text);
  }

  Future<void> _handleEnter(Node node, int cursor, String text) async {
    await _editorSession.commitActive();
    final result = await ref
        .read(treeCommandServiceProvider)
        .splitNode(nodeId: node.id, cursorPosition: cursor, text: text);
    if (!mounted) return;

    ref
        .read(nodePageControllerProvider(widget.parentId).notifier)
        .startEditing(result.newNodeId);
    _editorSession.focus(result.newNodeId, cursor: result.cursorPosition);
  }

  Future<void> _handleBackspace(Node node, int cursor, String text) async {
    await _editorSession.commitActive();
    final result = await ref
        .read(treeCommandServiceProvider)
        .mergeWithPrevious(node.id);
    if (result == null || !mounted) return;

    ref
        .read(nodePageControllerProvider(widget.parentId).notifier)
        .startEditing(result.targetNodeId);
    _editorSession.focus(result.targetNodeId, cursor: result.cursorPosition);
  }

  Future<void> _openNode(Node node) async {
    await _finishEditingForRouteChange();
    if (!mounted) return;
    context.push('/node/${node.id}');
  }

  Future<void> _createNode() async {
    await _finishEditingForRouteChange();
    final node = await ref
        .read(treeCommandServiceProvider)
        .createNode(parentId: widget.parentId, content: '');
    if (!mounted) return;
    ref
        .read(nodePageControllerProvider(widget.parentId).notifier)
        .startEditing(node.id);
    _editorSession.focus(node.id, cursor: 0);
  }

  Future<void> _popPage() async {
    await _finishEditingForRouteChange();
    if (mounted && context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenProvider(widget.parentId));
    final pageState = ref.watch(nodePageControllerProvider(widget.parentId));
    final parent = widget.parentId == null
        ? null
        : ref.watch(nodeProvider(widget.parentId!)).value;

    return PopScope<void>(
      canPop: widget.parentId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.parentId != null) {
          unawaited(_popPage());
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
