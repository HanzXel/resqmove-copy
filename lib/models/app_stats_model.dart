// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — App Stats Model
//  lib/models/app_stats_model.dart
//
//  The live statistics shown on HomeScreen's stats bar:
//  Avg. Response / Availability / Lives Saved
// ─────────────────────────────────────────────────────────────────────────────

class AppStatsModel {
  final String avgResponseTime;   // e.g. "6 min" or "--"
  final int availableUnits;       // Number of online ambulance units
  final int livesSaved;           // Total completed trips / lives served

  const AppStatsModel({
    this.avgResponseTime = '--',
    this.availableUnits = 0,
    this.livesSaved = 0,
  });

  factory AppStatsModel.empty() => const AppStatsModel();

  factory AppStatsModel.fromJson(Map<String, dynamic> json) {
    return AppStatsModel(
      avgResponseTime: json['avg_response_time']?.toString() ?? '--',
      availableUnits: (json['available_units'] as num?)?.toInt() ?? 0,
      livesSaved: (json['lives_saved'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'avg_response_time': avgResponseTime,
        'available_units': availableUnits,
        'lives_saved': livesSaved,
      };
}
