import '../editor_session.dart';

/// Interprets IME metrics without saving, deleting or changing editing state.
class EditorKeyboardPolicy {
  final EditorSession editorSession;
  final bool Function() isHandlingEnter;
  double lastBottomInset = 0;
  int? keyboardSessionGeneration;
  EditorKeyboardPolicy(this.editorSession, this.isHandlingEnter);
  void initBottomInset(double inset) {
    lastBottomInset = inset;
    if (inset > 0) {
      keyboardSessionGeneration = editorSession.focusGeneration;
    }
  }

  bool shouldFinishEditing({
    required double bottomInset,
    required bool isCurrentlyEditing,
  }) {
    final keyboardWasVisible = lastBottomInset > 0;
    final keyboardIsVisible = bottomInset > 0;

    if (keyboardIsVisible) {
      keyboardSessionGeneration = editorSession.focusGeneration;
    }

    if (editorSession.hasPendingFocus || editorSession.isSelectingDueDate) {
      lastBottomInset = bottomInset;
      return false;
    }

    if (keyboardWasVisible && !keyboardIsVisible) {
      if (editorSession.isHandingOver || isHandlingEnter()) {
        lastBottomInset = bottomInset;
        return false;
      }

      final editingId = editorSession.activeNodeId;
      final isSameGeneration =
          keyboardSessionGeneration == null ||
          keyboardSessionGeneration == editorSession.focusGeneration;

      final shouldFinish =
          !isHandlingEnter() &&
          !editorSession.isHandingOver &&
          !editorSession.hasPendingFocus &&
          editingId != null &&
          !editorSession.isFocused(editingId) &&
          isSameGeneration;

      if (shouldFinish && isCurrentlyEditing) {
        lastBottomInset = bottomInset;
        return true;
      }
    }

    lastBottomInset = bottomInset;
    return false;
  }
}
