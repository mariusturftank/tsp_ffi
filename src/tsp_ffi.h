#ifndef TSP_FFI_H
#define TSP_FFI_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handles for C++ objects
typedef void* RoutingIndexManagerHandle;
typedef void* RoutingModelHandle;
typedef void* RoutingSearchParametersHandle;
typedef void* AssignmentHandle;

// Callback function type for transit evaluator
typedef int64_t (*TransitCallback)(int64_t from_index, int64_t to_index, void* user_data);

// RoutingIndexManager functions
RoutingIndexManagerHandle routing_index_manager_create(
    int num_nodes,
    int num_vehicles,
    int depot);

void routing_index_manager_delete(RoutingIndexManagerHandle manager);

int routing_index_manager_index_to_node(RoutingIndexManagerHandle manager, int64_t index);

// RoutingModel functions
RoutingModelHandle routing_model_create(RoutingIndexManagerHandle manager);

void routing_model_delete(RoutingModelHandle model);

int routing_model_register_transit_callback(
    RoutingModelHandle model,
    TransitCallback callback,
    void* user_data);

void routing_model_set_arc_cost_evaluator_of_all_vehicles(
    RoutingModelHandle model,
    int evaluator_index);

AssignmentHandle routing_model_solve_with_parameters(
    RoutingModelHandle model,
    RoutingSearchParametersHandle parameters);

int64_t routing_model_start(RoutingModelHandle model, int vehicle);

int routing_model_is_end(RoutingModelHandle model, int64_t index);

int64_t routing_model_get_arc_cost_for_vehicle(
    RoutingModelHandle model,
    int64_t from_index,
    int64_t to_index,
    int64_t vehicle);

int routing_model_status(RoutingModelHandle model);

int64_t routing_model_next_var(RoutingModelHandle model, int64_t index);

// RoutingSearchParameters functions
RoutingSearchParametersHandle routing_search_parameters_create_default();

void routing_search_parameters_delete(RoutingSearchParametersHandle parameters);

void routing_search_parameters_set_first_solution_strategy(
    RoutingSearchParametersHandle parameters,
    int strategy);

void routing_search_parameters_set_local_search_metaheuristic(
    RoutingSearchParametersHandle parameters,
    int metaheuristic);

void routing_search_parameters_set_time_limit_seconds(
    RoutingSearchParametersHandle parameters,
    int64_t time_limit_seconds);

// Assignment functions
void assignment_delete(AssignmentHandle assignment);

int64_t assignment_objective_value(AssignmentHandle assignment);

// High-level convenience function for solving TSP with distance matrix
// This combines all the steps: create manager, model, register callback, set parameters, and solve
typedef struct {
    AssignmentHandle solution;
    RoutingIndexManagerHandle manager;
    RoutingModelHandle model;
    RoutingSearchParametersHandle parameters;
    int status;
} TSPSolution;

// Solve TSP with a distance matrix
// distance_matrix should be a flattened 2D array of size num_nodes * num_nodes
// time_limit_seconds: maximum time in seconds for the solver (0 = no limit)
// Returns a TSPSolution struct that contains all handles and the solution
// Caller must free the solution using tsp_solution_free()
TSPSolution tsp_solve_with_distance_matrix(
    const int64_t* distance_matrix,
    int num_nodes,
    int num_vehicles,
    int depot,
    int first_solution_strategy,
    int local_search_metaheuristic,
    int64_t time_limit_seconds);

// Free all resources associated with a TSP solution
void tsp_solution_free(TSPSolution* solution);

// Helper function to extract the route from a solution
// route should be pre-allocated array of size at least num_nodes + 1
// Returns the actual route length
int tsp_solution_get_route(
    TSPSolution* solution,
    int vehicle,
    int* route,
    int max_route_length);

// FirstSolutionStrategy enum values
enum {
    FIRST_SOLUTION_UNSET = 0,
    FIRST_SOLUTION_AUTOMATIC = 15,
    FIRST_SOLUTION_PATH_CHEAPEST_ARC = 3,
    FIRST_SOLUTION_PATH_MOST_CONSTRAINED_ARC = 4,
    FIRST_SOLUTION_EVALUATOR_STRATEGY = 5,
    FIRST_SOLUTION_SAVINGS = 10,
    FIRST_SOLUTION_SWEEP = 11,
    FIRST_SOLUTION_CHRISTOFIDES = 13,
    FIRST_SOLUTION_ALL_UNPERFORMED = 6,
    FIRST_SOLUTION_BEST_INSERTION = 7,
    FIRST_SOLUTION_PARALLEL_CHEAPEST_INSERTION = 8,
    FIRST_SOLUTION_SEQUENTIAL_CHEAPEST_INSERTION = 14,
    FIRST_SOLUTION_LOCAL_CHEAPEST_INSERTION = 9,
    FIRST_SOLUTION_LOCAL_CHEAPEST_COST_INSERTION = 16,
    FIRST_SOLUTION_GLOBAL_CHEAPEST_ARC = 1,
    FIRST_SOLUTION_LOCAL_CHEAPEST_ARC = 2,
    FIRST_SOLUTION_FIRST_UNBOUND_MIN_VALUE = 12
};

// RoutingSearchStatus enum values
enum {
    ROUTING_NOT_SOLVED = 0,
    ROUTING_SUCCESS = 1,
    ROUTING_PARTIAL_SUCCESS_LOCAL_OPTIMUM_NOT_REACHED = 2,
    ROUTING_FAIL = 3,
    ROUTING_FAIL_TIMEOUT = 4,
    ROUTING_INVALID = 5,
    ROUTING_INFEASIBLE = 6,
    ROUTING_OPTIMAL = 7
};

// LocalSearchMetaheuristic enum values
enum {
    LOCAL_SEARCH_METAHEURISTIC_UNSET = 0,
    LOCAL_SEARCH_METAHEURISTIC_GREEDY_DESCENT = 1,
    LOCAL_SEARCH_METAHEURISTIC_GUIDED_LOCAL_SEARCH = 2,
    LOCAL_SEARCH_METAHEURISTIC_SIMULATED_ANNEALING = 3,
    LOCAL_SEARCH_METAHEURISTIC_TABU_SEARCH = 4,
    LOCAL_SEARCH_METAHEURISTIC_AUTOMATIC = 6
};

#ifdef __cplusplus
}
#endif

#endif // TSP_FFI_H
