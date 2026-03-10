// You have generated a new plugin project without specifying the `--platforms`
// flag. An FFI plugin project that supports no platforms is generated.
// To add platforms, run `flutter create -t plugin_ffi --platforms <platforms> .`
// in this directory. You can also find a detailed instruction on how to
// add platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'tsp_ffi_bindings_generated.dart';

const String _libName = 'tsp_ffi';

/// The dynamic library in which the symbols for [TspFfiBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final TspFfiBindings _bindings = TspFfiBindings(_dylib);

/// High-level TSP solver interface
class TspSolver {
  /// Solve a TSP problem with the given distance matrix.
  ///
  /// [distanceMatrix] should be a square matrix (as a flat list) of size numNodes x numNodes
  /// [numNodes] is the number of locations/nodes
  /// [numVehicles] is the number of vehicles (typically 1 for TSP)
  /// [depot] is the index of the depot/starting node (typically 0)
  /// [strategy] is the first solution strategy to use (default: pathCheapestArc)
  /// [metaheuristic] is the local search metaheuristic to use (default: guidedLocalSearch)
  /// [timeLimitSeconds] is the maximum time in seconds for the solver (default: 30 seconds, 0 = no limit)
  ///
  /// Returns a [TspResult] containing the solution, or throws an exception if solving fails.
  static TspResult solve({
    required List<int> distanceMatrix,
    required int numNodes,
    int numVehicles = 1,
    int depot = 0,
    FirstSolutionStrategy strategy = FirstSolutionStrategy.pathCheapestArc,
    LocalSearchMetaheuristic metaheuristic = LocalSearchMetaheuristic.guidedLocalSearch,
    int timeLimitSeconds = 30,
  }) {
    // Validate input
    if (distanceMatrix.length != numNodes * numNodes) {
      throw ArgumentError(
        'Distance matrix must be of size numNodes x numNodes (${numNodes * numNodes}), '
        'but got ${distanceMatrix.length}',
      );
    }

    // Convert distance matrix to native memory
    final distanceMatrixPtr = calloc<Int64>(distanceMatrix.length);
    try {
      for (int i = 0; i < distanceMatrix.length; i++) {
        distanceMatrixPtr[i] = distanceMatrix[i];
      }

      // Call the native function
      final solution = _bindings.tsp_solve_with_distance_matrix(
        distanceMatrixPtr,
        numNodes,
        numVehicles,
        depot,
        strategy.value,
        metaheuristic.value,
        timeLimitSeconds,
      );

      // Check if solving was successful (including partial success)
      if (solution.status != RoutingSearchStatus.success.value &&
          solution.status != RoutingSearchStatus.optimal.value &&
          solution.status != RoutingSearchStatus.partialSuccessLocalOptimumNotReached.value) {
        final solutionPtr = calloc<TspSolution>();
        solutionPtr.ref = solution;
        _bindings.tsp_solution_free(solutionPtr);
        calloc.free(solutionPtr);
        throw TspSolverException('Failed to solve TSP: status ${solution.status}');
      }

      return TspResult._(solution, numNodes);
    } finally {
      calloc.free(distanceMatrixPtr);
    }
  }

  /// Solve TSP asynchronously on a separate isolate to avoid blocking the UI.
  ///
  /// This is useful for larger problems that might take significant time to solve.
  static Future<TspResult> solveAsync({
    required List<int> distanceMatrix,
    required int numNodes,
    int numVehicles = 1,
    int depot = 0,
    FirstSolutionStrategy strategy = FirstSolutionStrategy.pathCheapestArc,
    LocalSearchMetaheuristic metaheuristic = LocalSearchMetaheuristic.guidedLocalSearch,
    int timeLimitSeconds = 30,
  }) async {
    final request = _TspSolveRequest(
      distanceMatrix: distanceMatrix,
      numNodes: numNodes,
      numVehicles: numVehicles,
      depot: depot,
      strategy: strategy,
      metaheuristic: metaheuristic,
      timeLimitSeconds: timeLimitSeconds,
    );

    return await Isolate.run(
      () => solve(
        distanceMatrix: request.distanceMatrix,
        numNodes: request.numNodes,
        numVehicles: request.numVehicles,
        depot: request.depot,
        strategy: request.strategy,
        metaheuristic: request.metaheuristic,
        timeLimitSeconds: request.timeLimitSeconds,
      ),
    );
  }
}

/// Result of solving a TSP problem
class TspResult {
  final TspSolution _solution;
  final int _numNodes;

  TspResult._(this._solution, this._numNodes);

  /// Get the status of the solution as a raw integer
  int get statusValue => _solution.status;

  /// Get the status of the solution as an enum
  RoutingSearchStatus get status {
    return RoutingSearchStatus.values.firstWhere((s) => s.value == _solution.status, orElse: () => RoutingSearchStatus.notSolved);
  }

  /// Check if the solution was successful
  bool get isSuccess => status == RoutingSearchStatus.success;

  /// Get the objective value (total distance)
  int get objectiveValue {
    return _bindings.assignment_objective_value(_solution.solution);
  }

  /// Get the route for a specific vehicle
  ///
  /// Returns a list of node indices representing the route in order
  List<int> getRoute(int vehicle) {
    final routePtr = calloc<Int>(_numNodes + 1);
    final solutionPtr = calloc<TspSolution>();
    try {
      solutionPtr.ref = _solution;
      final routeLength = _bindings.tsp_solution_get_route(solutionPtr, vehicle, routePtr, _numNodes + 1);

      return List<int>.generate(routeLength, (i) => routePtr[i]);
    } finally {
      calloc.free(routePtr);
      calloc.free(solutionPtr);
    }
  }

  /// Free the native resources associated with this solution
  void dispose() {
    final solutionPtr = calloc<TspSolution>();
    solutionPtr.ref = _solution;
    _bindings.tsp_solution_free(solutionPtr);
    calloc.free(solutionPtr);
  }
}

/// Exception thrown when TSP solving fails
class TspSolverException implements Exception {
  final String message;
  TspSolverException(this.message);

  @override
  String toString() => 'TspSolverException: $message';
}

/// Request for async TSP solving
class _TspSolveRequest {
  final List<int> distanceMatrix;
  final int numNodes;
  final int numVehicles;
  final int depot;
  final FirstSolutionStrategy strategy;
  final LocalSearchMetaheuristic metaheuristic;
  final int timeLimitSeconds;

  _TspSolveRequest({
    required this.distanceMatrix,
    required this.numNodes,
    required this.numVehicles,
    required this.depot,
    required this.strategy,
    required this.metaheuristic,
    required this.timeLimitSeconds,
  });
}

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
