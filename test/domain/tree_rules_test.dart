import 'package:flutter_test/flutter_test.dart';

import 'package:deep_list/features/nodes/domain/tree_rules.dart';

void main() {
  test('rejects a node as its own parent', () {
    expect(
      () => TreeRules.validateMove(
        nodeId: 'a',
        newParentId: 'a',
        targetAndAncestorIds: const ['a'],
      ),
      throwsA(
        isA<TreeRuleViolation>().having(
          (error) => error.code,
          'code',
          TreeRuleCode.selfParent,
        ),
      ),
    );
  });

  test('rejects a target in the node subtree', () {
    expect(
      () => TreeRules.validateMove(
        nodeId: 'a',
        newParentId: 'c',
        targetAndAncestorIds: const ['c', 'b', 'a'],
      ),
      throwsA(
        isA<TreeRuleViolation>().having(
          (error) => error.code,
          'code',
          TreeRuleCode.cycle,
        ),
      ),
    );
  });

  test('allows a move when the target is outside the subtree', () {
    expect(
      () => TreeRules.validateMove(
        nodeId: 'c',
        newParentId: 'a',
        targetAndAncestorIds: const ['a'],
      ),
      returnsNormally,
    );
  });

  test('requires reorder IDs to be a complete set without duplicates', () {
    expect(
      () => TreeRules.validateReorder(
        orderedIds: const ['a', 'a'],
        activeSiblingIds: const ['a', 'b'],
      ),
      throwsA(
        isA<TreeRuleViolation>().having(
          (error) => error.code,
          'code',
          TreeRuleCode.duplicateOrderId,
        ),
      ),
    );

    expect(
      () => TreeRules.validateReorder(
        orderedIds: const ['a'],
        activeSiblingIds: const ['a', 'b'],
      ),
      throwsA(
        isA<TreeRuleViolation>().having(
          (error) => error.code,
          'code',
          TreeRuleCode.incompleteOrderIds,
        ),
      ),
    );
  });

  test('positions must be contiguous and zero-based', () {
    expect(() => TreeRules.validatePositions(const [0, 1, 2]), returnsNormally);
    expect(
      () => TreeRules.validatePositions(const [0, 2]),
      throwsA(
        isA<TreeRuleViolation>().having(
          (error) => error.code,
          'code',
          TreeRuleCode.invalidPosition,
        ),
      ),
    );
  });
}
