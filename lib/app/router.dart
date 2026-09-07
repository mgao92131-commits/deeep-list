import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/nodes/presentation/node_page.dart';
import '../features/nodes/presentation/providers/smart_nodes_provider.dart';
import '../features/nodes/presentation/smart_node_page.dart';

part 'router.g.dart';

class AppRouteObserver extends RouteObserver<ModalRoute<void>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PopupRoute) {
      super.didPush(route, previousRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PopupRoute) {
      super.didPop(route, previousRoute);
    }
  }
}

final routeObserver = AppRouteObserver();

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(
    observers: [routeObserver],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const NodePage(parentId: null),
        routes: [
          GoRoute(
            path: 'node/:nodeId',
            builder: (context, state) {
              return NodePage(parentId: state.pathParameters['nodeId']!);
            },
          ),
          GoRoute(
            path: 'today',
            builder: (context, state) =>
                const SmartNodePage(type: SmartListType.today),
          ),
          GoRoute(
            path: 'favorites',
            builder: (context, state) =>
                const SmartNodePage(type: SmartListType.favorites),
          ),
          GoRoute(
            path: 'due-dates',
            builder: (context, state) =>
                const SmartNodePage(type: SmartListType.dueDates),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
