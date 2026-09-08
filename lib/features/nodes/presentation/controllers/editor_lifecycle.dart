import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../../core/navigation/route_observer.dart';
import 'node_editing_coordinator.dart';

/// Translates platform and route notifications into editor commands.
class EditorLifecycle extends WidgetsBindingObserver with RouteAware {
  final NodeEditingCoordinator editor;
  bool _subscribed = false;
  EditorLifecycle(this.editor) {
    WidgetsBinding.instance.addObserver(this);
  }

  void attach(BuildContext context) {
    final view = View.maybeOf(context);
    if (view != null) {
      editor.initBottomInset(view.viewInsets.bottom / view.devicePixelRatio);
    }
    if (_subscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      routeObserver.subscribe(this, route);
      _subscribed = true;
    }
  }

  @override
  void didPushNext() => unawaited(editor.finishActiveEditing());
  @override
  void didPop() => unawaited(editor.finishActiveEditing());
  @override
  void didPopNext() => unawaited(editor.finishActiveEditing());
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) editor.handleLifecyclePause();
  }

  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view == null) return;
    editor.handleMetricsChange(
      bottomInset: view.viewInsets.bottom / view.devicePixelRatio,
      isCurrentlyEditing: editor.editing.value.isEditing,
    );
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_subscribed) routeObserver.unsubscribe(this);
  }
}
