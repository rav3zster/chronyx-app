import 'package:chronyx/features/project_planner/domain/entities/project.dart';

/// Result of parsing the raw AI blueprint response into structured data.
///
/// This is a domain-level representation. The actual parsing logic
/// lives in the data layer (blueprint parser).
///
/// Re-exports [ParsedBlueprint], [DayPlan], and [BlueprintTask] from
/// project.dart for convenience when working with parsed results.
typedef ParsedBlueprintResult = ParsedBlueprint;
typedef DayPlanResult = DayPlan;
typedef BlueprintTaskResult = BlueprintTask;
