/// The knobs and outcomes of a solver run, and nothing that needs the native library.
///
/// Kept apart from `tsp_ffi.dart` so that code which only configures a solve, or passes a
/// configuration around, can import it on any platform. `tsp_ffi.dart` re-exports all of it, so
/// importing that instead is equivalent wherever `dart:ffi` is available.
library;

/// Exception thrown when TSP solving fails
class TspSolverException implements Exception {
  final String message;
  TspSolverException(this.message);

  @override
  String toString() => 'TspSolverException: $message';
}

/// The strategy the solver builds its first solution with, which it then improves on.
///
/// The values are OR-Tools' `FirstSolutionStrategy` values, and are passed to it as they are.
enum FirstSolutionStrategy {
  unset(0),
  automatic(15),
  pathCheapestArc(3),
  pathMostConstrainedArc(4),
  evaluatorStrategy(5),
  savings(10),
  parallelSavings(17),
  sweep(11),
  christofides(13),
  allUnperformed(6),
  bestInsertion(7),
  parallelCheapestInsertion(8),
  sequentialCheapestInsertion(14),
  localCheapestInsertion(9),
  localCheapestCostInsertion(16),
  globalCheapestArc(1),
  localCheapestArc(2),
  firstUnboundMinValue(12);

  const FirstSolutionStrategy(this.value);
  final int value;
}

/// How a solve ended.
///
/// The values are OR-Tools' `RoutingSearchStatus` values.
enum RoutingSearchStatus {
  notSolved(0),
  success(1),
  partialSuccessLocalOptimumNotReached(2),
  fail(3),
  failTimeout(4),
  invalid(5),
  infeasible(6),
  optimal(7);

  const RoutingSearchStatus(this.value);
  final int value;
}

/// Local search metaheuristic for improving solutions
///
/// The values are OR-Tools' `LocalSearchMetaheuristic` values.
enum LocalSearchMetaheuristic {
  unset(0),
  greedyDescent(1),
  guidedLocalSearch(2),
  simulatedAnnealing(3),
  tabuSearch(4),
  automatic(6);

  const LocalSearchMetaheuristic(this.value);
  final int value;
}
