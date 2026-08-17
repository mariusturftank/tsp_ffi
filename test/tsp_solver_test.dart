// Functional tests for the TSP solver over the real native library.
//
// These load libtsp_ffi.so through dart:ffi, so the loader must be able to find
// it. On Linux the host build lives in src/build, with its shared OR-Tools
// dependencies in src/build/lib:
//
//   LD_LIBRARY_PATH=src/build:src/build/lib fvm flutter test
//
// Optimal tour lengths below are hand-computed, so a solver regression shows up
// as a wrong objective rather than merely a different-looking route.

import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_ffi/tsp_ffi.dart';

/// Statuses that represent a usable solution. The solver may return `optimal`
/// or stop at a local optimum, so asserting `success` alone is too strict.
const _solved = {
  RoutingSearchStatus.success,
  RoutingSearchStatus.optimal,
  RoutingSearchStatus.partialSuccessLocalOptimumNotReached,
};

/// Total cost of walking [route] through [matrix], for verifying that the
/// reported objective matches the route actually returned.
int _routeCost(List<int> route, List<int> matrix, int numNodes) {
  var cost = 0;
  for (var i = 0; i < route.length - 1; i++) {
    cost += matrix[route[i] * numNodes + route[i + 1]];
  }
  return cost;
}

void main() {
  group('TspSolver.solve', () {
    test('finds the perimeter tour of a square', () {
      // Four corners of a square: side 10, diagonal 14. The only optimal tour
      // is the perimeter (40); any tour using a diagonal costs at least 48.
      const matrix = [
        0, 10, 14, 10, //
        10, 0, 10, 14, //
        14, 10, 0, 10, //
        10, 14, 10, 0, //
      ];

      final result = TspSolver.solve(
        distanceMatrix: matrix,
        numNodes: 4,
        timeLimitSeconds: 1,
      );
      addTearDown(result.dispose);

      expect(_solved, contains(result.status));
      expect(result.objectiveValue, 40);
    });

    test('returns a closed tour visiting every node exactly once', () {
      const matrix = [
        0, 10, 14, 10, //
        10, 0, 10, 14, //
        14, 10, 0, 10, //
        10, 14, 10, 0, //
      ];

      final result = TspSolver.solve(
        distanceMatrix: matrix,
        numNodes: 4,
        timeLimitSeconds: 1,
      );
      addTearDown(result.dispose);

      final route = result.getRoute(0);

      // numNodes hops plus the return to the depot.
      expect(route, hasLength(5));
      expect(route.first, 0);
      expect(route.last, 0);
      expect(route.take(4).toSet(), {0, 1, 2, 3});
    });

    test('objective value matches the cost of the returned route', () {
      // Asymmetric costs, no known closed form — instead assert the solver is
      // self-consistent: the objective must equal the route it handed back.
      const numNodes = 6;
      const matrix = [
        0, 4, 9, 5, 8, 7, //
        6, 0, 3, 7, 9, 4, //
        9, 2, 0, 6, 4, 8, //
        5, 8, 6, 0, 3, 9, //
        7, 9, 5, 2, 0, 6, //
        8, 5, 7, 9, 6, 0, //
      ];

      final result = TspSolver.solve(
        distanceMatrix: matrix,
        numNodes: numNodes,
        timeLimitSeconds: 1,
      );
      addTearDown(result.dispose);

      final route = result.getRoute(0);
      expect(route.take(numNodes).toSet(), {0, 1, 2, 3, 4, 5});
      expect(result.objectiveValue, _routeCost(route, matrix, numNodes));
    });

    test('the only tour of a 3-node instance costs the sum of its edges', () {
      // With three nodes there is exactly one tour (either direction).
      const matrix = [
        0, 1, 2, //
        1, 0, 3, //
        2, 3, 0, //
      ];

      final result = TspSolver.solve(
        distanceMatrix: matrix,
        numNodes: 3,
        timeLimitSeconds: 1,
      );
      addTearDown(result.dispose);

      expect(result.objectiveValue, 1 + 3 + 2);
    });

    test('honours a non-zero depot', () {
      const matrix = [
        0, 10, 14, 10, //
        10, 0, 10, 14, //
        14, 10, 0, 10, //
        10, 14, 10, 0, //
      ];

      final result = TspSolver.solve(
        distanceMatrix: matrix,
        numNodes: 4,
        depot: 2,
        timeLimitSeconds: 1,
      );
      addTearDown(result.dispose);

      final route = result.getRoute(0);
      expect(route.first, 2);
      expect(route.last, 2);
      expect(result.objectiveValue, 40);
    });

    test('rejects a distance matrix that is not numNodes x numNodes', () {
      expect(
        () => TspSolver.solve(distanceMatrix: [0, 1, 1, 0], numNodes: 3),
        throwsArgumentError,
      );
    });

    test('accepts every first solution strategy', () {
      // Guards the enum values against drift from the C header, where a wrong
      // integer would surface as a solver failure rather than a compile error.
      const matrix = [
        0, 10, 14, 10, //
        10, 0, 10, 14, //
        14, 10, 0, 10, //
        10, 14, 10, 0, //
      ];

      for (final strategy in [
        FirstSolutionStrategy.automatic,
        FirstSolutionStrategy.pathCheapestArc,
        FirstSolutionStrategy.savings,
        FirstSolutionStrategy.christofides,
        FirstSolutionStrategy.globalCheapestArc,
      ]) {
        final result = TspSolver.solve(
          distanceMatrix: matrix,
          numNodes: 4,
          strategy: strategy,
          timeLimitSeconds: 1,
        );
        expect(_solved, contains(result.status), reason: 'strategy $strategy');
        expect(result.objectiveValue, 40, reason: 'strategy $strategy');
        result.dispose();
      }
    });
  });

  group('TspSolver.solveAsync', () {
    test('solves on an isolate and agrees with the synchronous result', () async {
      const matrix = [
        0, 10, 14, 10, //
        10, 0, 10, 14, //
        14, 10, 0, 10, //
        10, 14, 10, 0, //
      ];

      final result = await TspSolver.solveAsync(
        distanceMatrix: matrix,
        numNodes: 4,
        timeLimitSeconds: 1,
      );
      addTearDown(result.dispose);

      expect(result.objectiveValue, 40);
    });
  });
}
