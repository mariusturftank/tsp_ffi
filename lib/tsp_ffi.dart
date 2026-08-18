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
import 'dart:math';

import 'package:ffi/ffi.dart';

import 'search_parameters.dart';
import 'tsp_ffi_bindings_generated.dart';

/// The solver's knobs and outcomes, which can also be imported on their own, from
/// `package:tsp_ffi/search_parameters.dart`, by code that has to build on platforms this library
/// does not support.
export 'search_parameters.dart';

const String _libName = 'tsp_ffi';

/// The dynamic library in which the symbols for [TspFfiBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    try {
      return DynamicLibrary.open('lib$_libName.so');
    } catch (e) {
      // The plugin ships an arm64-v8a binary only, so the most likely cause on
      // Android is an x86_64 emulator or an armeabi-v7a device. Say so, rather
      // than surfacing a bare "failed to load dynamic library".
      if (Platform.isAndroid) {
        throw UnsupportedError(
          'Failed to load lib$_libName.so. This plugin supports arm64-v8a only, '
          'so it does not run on x86_64 emulators or armeabi-v7a devices. Use an '
          'arm64 device or an arm64 system image. Original error: $e',
        );
      }
      rethrow;
    }
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

  /// The order to visit the nodes in, as node indices.
  ///
  /// Solves the same problem as [solve], but hands back just the tour and takes care of the
  /// bookkeeping around it: the closing return to [depot] is dropped, so every node appears exactly
  /// once and [depot] comes first, and the native solution is released before returning.
  ///
  /// [costMatrix] is a flattened [nodeCount] x [nodeCount] matrix, where the entry at
  /// `from * nodeCount + to` is what going from node `from` to node `to` costs.
  ///
  /// [timeLimit] is how long the solver may look for a better tour. It is rounded down to whole
  /// seconds, the resolution the solver works in, and never to zero, which would let it run without
  /// a limit at all.
  ///
  /// Throws [ArgumentError] if the matrix does not match [nodeCount], and [TspSolverException] if
  /// the solver found no tour through every node.
  static List<int> order({
    required List<int> costMatrix,
    required int nodeCount,
    int depot = 0,
    FirstSolutionStrategy strategy = FirstSolutionStrategy.automatic,
    LocalSearchMetaheuristic metaheuristic = LocalSearchMetaheuristic.automatic,
    Duration timeLimit = const Duration(seconds: 3),
  }) {
    if (nodeCount < 3) {
      // A tour of two nodes or fewer is whatever order they are already in.
      return List<int>.generate(nodeCount, (i) => i);
    }

    final result = solve(
      distanceMatrix: costMatrix,
      numNodes: nodeCount,
      depot: depot,
      strategy: strategy,
      metaheuristic: metaheuristic,
      timeLimitSeconds: max(1, timeLimit.inSeconds),
    );

    try {
      final route = result.getRoute(0);
      // The route is a closed tour, so it ends back at the depot it started from.
      final order = route.isNotEmpty && route.last == depot
          ? route.sublist(0, route.length - 1)
          : route;
      if (order.length != nodeCount || order.toSet().length != nodeCount) {
        throw TspSolverException(
          'Solver returned ${order.length} of $nodeCount nodes to visit',
        );
      }

      return order;
    } finally {
      result.dispose();
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
