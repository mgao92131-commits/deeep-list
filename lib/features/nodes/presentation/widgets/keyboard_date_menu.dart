import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

/// A popup whose layout is constrained to the area above the keyboard.
class KeyboardDateMenu extends StatelessWidget {
  final String tooltip;
  final Widget icon;
  final VoidCallback onOpened;
  final VoidCallback onCanceled;
  final ValueChanged<String> onSelected;
  final List<PopupMenuEntry<String>> Function(BuildContext) itemBuilder;

  const KeyboardDateMenu({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onOpened,
    required this.onCanceled,
    required this.onSelected,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: icon,
      onPressed: () async {
        final button = context.findRenderObject()! as RenderBox;
        final navigator = Navigator.of(context);
        final overlay =
            navigator.overlay!.context.findRenderObject()! as RenderBox;
        final items = itemBuilder(context);
        final themes = InheritedTheme.capture(
          from: context,
          to: navigator.context,
        );
        var anchor =
            button.localToGlobal(Offset.zero, ancestor: overlay) & button.size;
        onOpened();
        final result = await showGeneralDialog<String>(
          context: context,
          useRootNavigator: false,
          requestFocus: false,
          barrierDismissible: true,
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          barrierColor: Colors.transparent,
          pageBuilder: (context, animation, secondaryAnimation) {
            final media = MediaQuery.of(context);
            return LayoutBuilder(
              builder: (context, constraints) {
                if (button.attached) {
                  anchor =
                      button.localToGlobal(Offset.zero, ancestor: overlay) &
                      button.size;
                }
                return CustomSingleChildLayout(
                  delegate: _DateMenuLayout(
                    anchor: anchor,
                    safeTop: media.padding.top + 8,
                    bottomInset: media.viewInsets.bottom + 8,
                    leftInset: media.padding.left + 8,
                    rightInset: media.padding.right + 8,
                  ),
                  child: themes.wrap(
                    Material(
                      key: const ValueKey('keyboard-date-menu-surface'),
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: Semantics(
                        role: SemanticsRole.menu,
                        scopesRoute: true,
                        namesRoute: true,
                        label: tooltip,
                        explicitChildNodes: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: items,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
        if (result == null || !context.mounted) {
          onCanceled();
        } else {
          onSelected(result);
        }
      },
    );
  }
}

class _DateMenuLayout extends SingleChildLayoutDelegate {
  final Rect anchor;
  final double safeTop;
  final double bottomInset;
  final double leftInset;
  final double rightInset;

  _DateMenuLayout({
    required this.anchor,
    required this.safeTop,
    required this.bottomInset,
    required this.leftInset,
    required this.rightInset,
  });

  double _bottom(Size size) => (anchor.top - 8).clamp(
    safeTop,
    (size.height - bottomInset).clamp(safeTop, double.infinity),
  );

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = (constraints.maxWidth - leftInset - rightInset).clamp(
      0.0,
      260.0,
    );
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: (_bottom(constraints.biggest) - safeTop).clamp(
        0.0,
        double.infinity,
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    anchor.left.clamp(
      leftInset,
      (size.width - rightInset - childSize.width).clamp(
        leftInset,
        double.infinity,
      ),
    ),
    _bottom(size) - childSize.height,
  );

  @override
  bool shouldRelayout(_DateMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      safeTop != oldDelegate.safeTop ||
      bottomInset != oldDelegate.bottomInset ||
      leftInset != oldDelegate.leftInset ||
      rightInset != oldDelegate.rightInset;
}
