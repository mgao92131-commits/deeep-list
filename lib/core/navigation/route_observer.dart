import 'package:flutter/widgets.dart';

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
