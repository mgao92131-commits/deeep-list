import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../repositories/node_repository.dart';
import '../viewmodels/node_viewmodel.dart';
import '../widgets/node_tile.dart';
import '../models/node_item.dart';

class NodeScreen extends StatefulWidget {
  final int nodeId;

  const NodeScreen({super.key, required this.nodeId});

  @override
  State<NodeScreen> createState() => _NodeScreenState();
}

class _NodeScreenState extends State<NodeScreen> {
  late NodeViewModel _viewModel;
  int? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    _viewModel = NodeViewModel(context.read<NodeRepository>(), widget.nodeId);
  }

  @override
  Widget build(BuildContext context) {
    final nodeState = _viewModel.node.watch(context);
    final parent = nodeState.value;
    final childrenIds = List<int>.from(parent?.children ?? const []);

    return Scaffold(
      appBar: AppBar(
        title: Text(nodeState.value?.content ?? 'DeepList'),
        leading: widget.nodeId == kRootNodeId
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: Builder(
        builder: (context) {
          if (nodeState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (nodeState.hasError) {
            return Center(child: Text('Error: ${nodeState.error}'));
          }
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: childrenIds.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final itemId = childrenIds.removeAt(oldIndex);
              childrenIds.insert(newIndex, itemId);
              _viewModel.reorder(childrenIds);
            },
            itemBuilder: (context, index) {
              final itemId = childrenIds[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(itemId),
                index: index,
                child: StreamBuilder<NodeItem?>(
                  stream: _viewModel.watchById(itemId),
                  builder: (context, snapshot) {
                    final item = snapshot.data;
                    if (item == null) return const SizedBox.shrink();

                    return NodeTile(
                      item: item,
                      isSelected: _selectedNodeId == item.id,
                      onToggleSelect: () {
                        setState(() {
                          _selectedNodeId =
                              (_selectedNodeId == item.id) ? null : item.id;
                        });
                      },
                      onTap: () {
                        if (_selectedNodeId != item.id) {
                          setState(() => _selectedNodeId = item.id);
                        }
                      },
                      onNavigate: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NodeScreen(nodeId: item.id),
                          ),
                        );
                      },
                      onContentChanged: (val) {
                        item.content = val;
                        _viewModel.updateNode(item);
                      },
                      onToggleDone: () => _viewModel.toggleDone(item),
                      onToggleFavorite: () => _viewModel.toggleFavorite(item),
                      onArchive: () => _viewModel.archive(item),
                      onDelete: () => _viewModel.delete(item.id),
                      focusRequests: _viewModel.focusRequests,
                      onEnter: (item, cursor, text) =>
                          _viewModel.handleEnter(item, cursor, text),
                      onBackspace: (item, cursor, text) =>
                          _viewModel.handleBackspace(item, cursor, text),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _viewModel.addNode('');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
