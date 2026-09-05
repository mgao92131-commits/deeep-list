import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/nodes/presentation/node_page.dart';

part 'router.g.dart';

final routeObserver = RouteObserver<ModalRoute<void>>();

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
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
