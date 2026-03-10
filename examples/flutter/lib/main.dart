import 'dart:math';

import 'package:flutter/material.dart';

import 'package:tsp_ffi/tsp_ffi.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  TspResult? _tspResult;
  List<int>? _route;
  int? _distance;
  String _status = 'Not solved yet';

  List<List<int>> _generateLocations() {
    List<List<int>> locations = [];
    for (int i = 0; i < 30; i++) {
      locations.add([Random().nextInt(100), Random().nextInt(100)]);
    }
    return locations;
  }

  @override
  void initState() {
    super.initState();
    _solveTsp();
  }

  @override
  void dispose() {
    _tspResult?.dispose();
    super.dispose();
  }

  void _solveTsp() {
    final locations = _generateLocations();

    // Generate Manhattan distance matrix
    final numNodes = locations.length;
    final distanceMatrix = List<int>.filled(numNodes * numNodes, 0);

    for (int i = 0; i < numNodes; i++) {
      for (int j = 0; j < numNodes; j++) {
        if (i != j) {
          final dx = (locations[i][0] - locations[j][0]).abs();
          final dy = (locations[i][1] - locations[j][1]).abs();
          distanceMatrix[i * numNodes + j] = (dx + dy); // Scale up for demo
        }
      }
    }

    // Solve TSP asynchronously
    final result = TspSolver.solve(
      distanceMatrix: distanceMatrix,
      numNodes: numNodes,
      numVehicles: 1,
      depot: 0,
      strategy: FirstSolutionStrategy.pathCheapestArc,
    );

    if (mounted) {
      setState(() {
        _tspResult = result;
        _route = result.getRoute(0);
        _distance = result.objectiveValue;

        if (result.status == RoutingSearchStatus.success) {
          _status = 'Success!';
        } else if (result.status == RoutingSearchStatus.optimal) {
          _status = 'Optimal solution found!';
        } else {
          _status = 'Solving failed with status: ${result.status}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 20);
    const headerStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
    const spacerSmall = SizedBox(height: 10);
    const spacerMedium = SizedBox(height: 20);

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('TSP Solver Example'), backgroundColor: Colors.blue),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Traveling Salesman Problem', style: headerStyle, textAlign: TextAlign.center),
                spacerMedium,
                const Text('This example solves a 30-city TSP using OR-Tools via FFI.', style: textStyle),
                spacerMedium,
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: $_status',
                          style: textStyle.copyWith(
                            color: _status.contains('Success') || _status.contains('Optimal')
                                ? Colors.green
                                : _status.contains('Error')
                                ? Colors.red
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        spacerSmall,
                        if (_distance != null) Text('Total Distance: $_distance', style: textStyle),
                        spacerSmall,
                        if (_route != null) ...[
                          const Text('Route:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          spacerSmall,
                          Text(
                            _route!.join(' → '),
                            style: textStyle.copyWith(color: Colors.blue, fontFamily: 'monospace'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                spacerMedium,
                const Card(
                  color: Colors.blue,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Problem Details',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '• 5 cities\n'
                          '• Manhattan distance metric\n'
                          '• Starting from depot (city 0)\n'
                          '• Using PATH_CHEAPEST_ARC strategy',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                spacerMedium,
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _tspResult?.dispose();
                        _tspResult = null;
                        _route = null;
                        _distance = null;
                        _status = 'Solving...';
                        _solveTsp();
                      });
                    },
                    child: const Text('Solve Again'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
