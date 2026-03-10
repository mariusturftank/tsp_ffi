#include "tsp_ffi.h"
#include "ortools/constraint_solver/constraint_solver.h"
#include "ortools/constraint_solver/routing.h"
#include "ortools/constraint_solver/routing_enums.pb.h"
#include "ortools/constraint_solver/routing_index_manager.h"
#include "ortools/constraint_solver/routing_parameters.h"

using namespace operations_research;

// Wrapper struct for callback
struct CallbackWrapper {
    TransitCallback callback;
    void* user_data;
};

// RoutingIndexManager functions
extern "C" {

RoutingIndexManagerHandle routing_index_manager_create(
    int num_nodes,
    int num_vehicles,
    int depot) {
    return new RoutingIndexManager(
        num_nodes,
        num_vehicles,
        RoutingIndexManager::NodeIndex(depot));
}

void routing_index_manager_delete(RoutingIndexManagerHandle manager) {
    delete static_cast<RoutingIndexManager*>(manager);
}

int routing_index_manager_index_to_node(RoutingIndexManagerHandle manager, int64_t index) {
    auto* mgr = static_cast<RoutingIndexManager*>(manager);
    return mgr->IndexToNode(index).value();
}

// RoutingModel functions
RoutingModelHandle routing_model_create(RoutingIndexManagerHandle manager) {
    auto* mgr = static_cast<RoutingIndexManager*>(manager);
    return new RoutingModel(*mgr);
}

void routing_model_delete(RoutingModelHandle model) {
    delete static_cast<RoutingModel*>(model);
}

int routing_model_register_transit_callback(
    RoutingModelHandle model,
    TransitCallback callback,
    void* user_data) {
    auto* routing = static_cast<RoutingModel*>(model);
    
    // Create a wrapper that will be captured by the lambda
    auto* wrapper = new CallbackWrapper{callback, user_data};
    
    // Register the callback
    int callback_index = routing->RegisterTransitCallback(
        [wrapper](int64_t from_index, int64_t to_index) -> int64_t {
            return wrapper->callback(from_index, to_index, wrapper->user_data);
        });
    
    return callback_index;
}

void routing_model_set_arc_cost_evaluator_of_all_vehicles(
    RoutingModelHandle model,
    int evaluator_index) {
    auto* routing = static_cast<RoutingModel*>(model);
    routing->SetArcCostEvaluatorOfAllVehicles(evaluator_index);
}

AssignmentHandle routing_model_solve_with_parameters(
    RoutingModelHandle model,
    RoutingSearchParametersHandle parameters) {
    auto* routing = static_cast<RoutingModel*>(model);
    auto* params = static_cast<RoutingSearchParameters*>(parameters);
    
    const Assignment* solution = routing->SolveWithParameters(*params);
    
    // Return a non-const pointer (caller must not delete the original)
    // In practice, you might want to clone the assignment
    return const_cast<Assignment*>(solution);
}

int64_t routing_model_start(RoutingModelHandle model, int vehicle) {
    auto* routing = static_cast<RoutingModel*>(model);
    return routing->Start(vehicle);
}

int routing_model_is_end(RoutingModelHandle model, int64_t index) {
    auto* routing = static_cast<RoutingModel*>(model);
    return routing->IsEnd(index) ? 1 : 0;
}

int64_t routing_model_get_arc_cost_for_vehicle(
    RoutingModelHandle model,
    int64_t from_index,
    int64_t to_index,
    int64_t vehicle) {
    auto* routing = static_cast<RoutingModel*>(model);
    return routing->GetArcCostForVehicle(from_index, to_index, vehicle);
}

int routing_model_status(RoutingModelHandle model) {
    auto* routing = static_cast<RoutingModel*>(model);
    return static_cast<int>(routing->status());
}

int64_t routing_model_next_var(RoutingModelHandle model, int64_t index) {
    auto* routing = static_cast<RoutingModel*>(model);
    return routing->NextVar(index)->index();
}

// RoutingSearchParameters functions
RoutingSearchParametersHandle routing_search_parameters_create_default() {
    RoutingSearchParameters* params = new RoutingSearchParameters();
    *params = DefaultRoutingSearchParameters();
    return params;
}

void routing_search_parameters_delete(RoutingSearchParametersHandle parameters) {
    delete static_cast<RoutingSearchParameters*>(parameters);
}

void routing_search_parameters_set_first_solution_strategy(
    RoutingSearchParametersHandle parameters,
    int strategy) {
    auto* params = static_cast<RoutingSearchParameters*>(parameters);
    params->set_first_solution_strategy(
        static_cast<FirstSolutionStrategy::Value>(strategy));
}

void routing_search_parameters_set_local_search_metaheuristic(
    RoutingSearchParametersHandle parameters,
    int metaheuristic) {
    auto* params = static_cast<RoutingSearchParameters*>(parameters);
    params->set_local_search_metaheuristic(
        static_cast<LocalSearchMetaheuristic::Value>(metaheuristic));
}

void routing_search_parameters_set_time_limit_seconds(
    RoutingSearchParametersHandle parameters,
    int64_t time_limit_seconds) {
    auto* params = static_cast<RoutingSearchParameters*>(parameters);
    params->mutable_time_limit()->set_seconds(time_limit_seconds);
}

// Assignment functions
void assignment_delete(AssignmentHandle assignment) {
    // Note: The Assignment returned by SolveWithParameters is owned by RoutingModel
    // So we should NOT delete it here. This function is provided for API completeness
    // but should be called cautiously or not at all.
    // In a production system, you might want to handle ownership differently.
}

int64_t assignment_objective_value(AssignmentHandle assignment) {
    auto* assign = static_cast<Assignment*>(assignment);
    return assign->ObjectiveValue();
}

// High-level convenience function
TSPSolution tsp_solve_with_distance_matrix(
    const int64_t* distance_matrix,
    int num_nodes,
    int num_vehicles,
    int depot,
    int first_solution_strategy,
    int local_search_metaheuristic,
    int64_t time_limit_seconds) {
    
    TSPSolution result = {nullptr, nullptr, nullptr, nullptr, ROUTING_NOT_SOLVED};
    
    // Create routing index manager
    result.manager = routing_index_manager_create(num_nodes, num_vehicles, depot);
    if (!result.manager) {
        return result;
    }
    
    // Create routing model
    result.model = routing_model_create(result.manager);
    if (!result.model) {
        routing_index_manager_delete(result.manager);
        result.manager = nullptr;
        return result;
    }
    
    auto* routing = static_cast<RoutingModel*>(result.model);
    auto* manager = static_cast<RoutingIndexManager*>(result.manager);
    
    // Register transit callback with distance matrix
    const int transit_callback_index = routing->RegisterTransitCallback(
        [distance_matrix, manager, num_nodes](int64_t from_index, int64_t to_index) -> int64_t {
            // Convert from routing variable Index to distance matrix NodeIndex
            const int from_node = manager->IndexToNode(from_index).value();
            const int to_node = manager->IndexToNode(to_index).value();
            return distance_matrix[from_node * num_nodes + to_node];
        });
    
    // Set arc cost evaluator for all vehicles
    routing->SetArcCostEvaluatorOfAllVehicles(transit_callback_index);
    
    // Create and configure search parameters
    result.parameters = routing_search_parameters_create_default();
    routing_search_parameters_set_first_solution_strategy(
        result.parameters,
        first_solution_strategy);
    routing_search_parameters_set_local_search_metaheuristic(
        result.parameters,
        local_search_metaheuristic);
    if (time_limit_seconds > 0) {
        routing_search_parameters_set_time_limit_seconds(
            result.parameters,
            time_limit_seconds);
    }
    
    // Solve the problem
    result.solution = routing_model_solve_with_parameters(result.model, result.parameters);
    result.status = routing_model_status(result.model);
    
    return result;
}

void tsp_solution_free(TSPSolution* solution) {
    if (!solution) return;
    
    // Note: assignment is owned by RoutingModel, so don't delete it separately
    solution->solution = nullptr;
    
    if (solution->parameters) {
        routing_search_parameters_delete(solution->parameters);
        solution->parameters = nullptr;
    }
    
    if (solution->model) {
        routing_model_delete(solution->model);
        solution->model = nullptr;
    }
    
    if (solution->manager) {
        routing_index_manager_delete(solution->manager);
        solution->manager = nullptr;
    }
    
    solution->status = ROUTING_NOT_SOLVED;
}

int tsp_solution_get_route(
    TSPSolution* solution,
    int vehicle,
    int* route,
    int max_route_length) {
    
    if (!solution || !solution->solution || !solution->model || !route) {
        return 0;
    }
    
    auto* routing = static_cast<RoutingModel*>(solution->model);
    auto* manager = static_cast<RoutingIndexManager*>(solution->manager);
    auto* assignment = static_cast<Assignment*>(solution->solution);
    
    int route_length = 0;
    int64_t index = routing->Start(vehicle);
    
    while (!routing->IsEnd(index) && route_length < max_route_length) {
        route[route_length++] = manager->IndexToNode(index).value();
        index = assignment->Value(routing->NextVar(index));
    }
    
    // Add the final node (end depot)
    if (route_length < max_route_length) {
        route[route_length++] = manager->IndexToNode(index).value();
    }
    
    return route_length;
}

} // extern "C"
