import 'dart:math';

import 'package:tsp_ffi/tsp_ffi.dart';

const String version = '0.0.1';

List<List<int>> _generateLocations() {
  List<List<int>> locations = [];
  for (int i = 0; i < 30; i++) {
    for (int j = 0; j < 30; j++) {
      locations.add([Random().nextInt(100), Random().nextInt(100)]);
    }
  }
  return locations;
}

void main(List<String> arguments) {
  List<List<int>> locations = _generateLocations();
  final numNodes = locations.length;
  final distanceMatrix = List<int>.filled(numNodes * numNodes, 0);

  for (int i = 0; i < numNodes; i++) {
    for (int j = 0; j < numNodes; j++) {
      if (i != j) {
        final dx = (locations[i][0] - locations[j][0]).abs();
        final dy = (locations[i][1] - locations[j][1]).abs();
        distanceMatrix[i * numNodes + j] = (dx + dy);
      }
    }
  }

  print('Solving TSP...');
  final result = TspSolver.solve(
    distanceMatrix: distanceMatrix,
    numNodes: numNodes,
    numVehicles: 1,
    depot: 0,
    strategy: FirstSolutionStrategy.pathCheapestArc,
    metaheuristic: LocalSearchMetaheuristic.guidedLocalSearch,
  );

  print('Status: ${result.status}');
  print('Objective value (total distance): ${result.objectiveValue}');
  print('Route: ${result.getRoute(0)}');

  result.dispose();
}
