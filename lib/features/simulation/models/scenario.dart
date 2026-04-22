import 'package:debt_free_app/features/simulation/models/scenario_change.dart';

enum RepaymentStrategy {
  minimum,
  avalanche,
  snowball,
  custom,
}

class Scenario {
  const Scenario({
    required this.id,
    required this.name,
    required this.strategy,
    required this.changes,
  });

  final String id;
  final String name;
  final RepaymentStrategy strategy;
  final List<ScenarioChange> changes;
}
