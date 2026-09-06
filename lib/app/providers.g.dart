// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(database)
const databaseProvider = DatabaseProvider._();

final class DatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  const DatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return database(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$databaseHash() => r'dd3a24de1631730545e1b0efe8be81b12b9d76d9';

@ProviderFor(nodeRepository)
const nodeRepositoryProvider = NodeRepositoryProvider._();

final class NodeRepositoryProvider
    extends $FunctionalProvider<NodeRepository, NodeRepository, NodeRepository>
    with $Provider<NodeRepository> {
  const NodeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nodeRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nodeRepositoryHash();

  @$internal
  @override
  $ProviderElement<NodeRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NodeRepository create(Ref ref) {
    return nodeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NodeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NodeRepository>(value),
    );
  }
}

String _$nodeRepositoryHash() => r'07cc544263fb9b00d9b7210e16137b6e70996a09';

@ProviderFor(treeCommandService)
const treeCommandServiceProvider = TreeCommandServiceProvider._();

final class TreeCommandServiceProvider
    extends
        $FunctionalProvider<
          TreeCommandService,
          TreeCommandService,
          TreeCommandService
        >
    with $Provider<TreeCommandService> {
  const TreeCommandServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'treeCommandServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$treeCommandServiceHash();

  @$internal
  @override
  $ProviderElement<TreeCommandService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TreeCommandService create(Ref ref) {
    return treeCommandService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TreeCommandService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TreeCommandService>(value),
    );
  }
}

String _$treeCommandServiceHash() =>
    r'e917ec9c513633ab69893869d28c125f424bd972';

@ProviderFor(node)
const nodeProvider = NodeFamily._();

final class NodeProvider
    extends $FunctionalProvider<AsyncValue<Node?>, Node?, Stream<Node?>>
    with $FutureModifier<Node?>, $StreamProvider<Node?> {
  const NodeProvider._({
    required NodeFamily super.from,
    required NodeId super.argument,
  }) : super(
         retry: null,
         name: r'nodeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nodeHash();

  @override
  String toString() {
    return r'nodeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Node?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Node?> create(Ref ref) {
    final argument = this.argument as NodeId;
    return node(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NodeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nodeHash() => r'be3dc54010f3418e89e832606de9caeafb9bf1c2';

final class NodeFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Node?>, NodeId> {
  const NodeFamily._()
    : super(
        retry: null,
        name: r'nodeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NodeProvider call(NodeId nodeId) =>
      NodeProvider._(argument: nodeId, from: this);

  @override
  String toString() => r'nodeProvider';
}

@ProviderFor(children)
const childrenProvider = ChildrenFamily._();

final class ChildrenProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Node>>,
          List<Node>,
          Stream<List<Node>>
        >
    with $FutureModifier<List<Node>>, $StreamProvider<List<Node>> {
  const ChildrenProvider._({
    required ChildrenFamily super.from,
    required NodeId? super.argument,
  }) : super(
         retry: null,
         name: r'childrenProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$childrenHash();

  @override
  String toString() {
    return r'childrenProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Node>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Node>> create(Ref ref) {
    final argument = this.argument as NodeId?;
    return children(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChildrenProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$childrenHash() => r'9af4e3c067bfbdd1a59a10437bffb2ea63a149f4';

final class ChildrenFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Node>>, NodeId?> {
  const ChildrenFamily._()
    : super(
        retry: null,
        name: r'childrenProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ChildrenProvider call(NodeId? parentId) =>
      ChildrenProvider._(argument: parentId, from: this);

  @override
  String toString() => r'childrenProvider';
}

@ProviderFor(childCounts)
const childCountsProvider = ChildCountsProvider._();

final class ChildCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<NodeId, int>>,
          Map<NodeId, int>,
          Stream<Map<NodeId, int>>
        >
    with $FutureModifier<Map<NodeId, int>>, $StreamProvider<Map<NodeId, int>> {
  const ChildCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'childCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$childCountsHash();

  @$internal
  @override
  $StreamProviderElement<Map<NodeId, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<NodeId, int>> create(Ref ref) {
    return childCounts(ref);
  }
}

String _$childCountsHash() => r'a07fe53848e2dd8c77bbc4f2525a089581aba9a7';
