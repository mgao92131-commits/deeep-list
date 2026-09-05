// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'node_page_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NodePageController)
const nodePageControllerProvider = NodePageControllerFamily._();

final class NodePageControllerProvider
    extends $NotifierProvider<NodePageController, NodePageState> {
  const NodePageControllerProvider._({
    required NodePageControllerFamily super.from,
    required NodeId? super.argument,
  }) : super(
         retry: null,
         name: r'nodePageControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nodePageControllerHash();

  @override
  String toString() {
    return r'nodePageControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  NodePageController create() => NodePageController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NodePageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NodePageState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NodePageControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nodePageControllerHash() =>
    r'da2d72e4bae5b29831eca0bfb82ad9242679d8f9';

final class NodePageControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          NodePageController,
          NodePageState,
          NodePageState,
          NodePageState,
          NodeId?
        > {
  const NodePageControllerFamily._()
    : super(
        retry: null,
        name: r'nodePageControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NodePageControllerProvider call(NodeId? parentId) =>
      NodePageControllerProvider._(argument: parentId, from: this);

  @override
  String toString() => r'nodePageControllerProvider';
}

abstract class _$NodePageController extends $Notifier<NodePageState> {
  late final _$args = ref.$arg as NodeId?;
  NodeId? get parentId => _$args;

  NodePageState build(NodeId? parentId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<NodePageState, NodePageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NodePageState, NodePageState>,
              NodePageState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
