// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clipboard_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ClipboardController)
const clipboardControllerProvider = ClipboardControllerProvider._();

final class ClipboardControllerProvider
    extends $NotifierProvider<ClipboardController, NodeId?> {
  const ClipboardControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipboardControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipboardControllerHash();

  @$internal
  @override
  ClipboardController create() => ClipboardController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NodeId? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NodeId?>(value),
    );
  }
}

String _$clipboardControllerHash() =>
    r'9b8bbece735adbd95f7b011fef7698022c8d46d5';

abstract class _$ClipboardController extends $Notifier<NodeId?> {
  NodeId? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<NodeId?, NodeId?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NodeId?, NodeId?>,
              NodeId?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
