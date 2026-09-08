// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(nodeRepository)
const nodeRepositoryProvider = NodeRepositoryProvider._();

final class NodeRepositoryProvider
    extends
        $FunctionalProvider<
          TreeMutationRepository,
          TreeMutationRepository,
          TreeMutationRepository
        >
    with $Provider<TreeMutationRepository> {
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
  $ProviderElement<TreeMutationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TreeMutationRepository create(Ref ref) {
    return nodeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TreeMutationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TreeMutationRepository>(value),
    );
  }
}

String _$nodeRepositoryHash() => r'4ce0a8eed5509e87289d11f88510c9eba47b283b';

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
    r'c335e80b44655825e3aa68d7c9466ecc686bed02';

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
