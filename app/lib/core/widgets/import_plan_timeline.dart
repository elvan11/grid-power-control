import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../data/import_plans_provider.dart';

class ImportPlanTimeline extends StatelessWidget {
  const ImportPlanTimeline({
    super.key,
    required this.plans,
    required this.timeZone,
    this.overrideActive = false,
  });
  final List<ImportPlan> plans;
  final String timeZone;
  final bool overrideActive;
  static bool _initialized = false;
  String _time(DateTime value) {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
    final local = tz.TZDateTime.from(value, tz.getLocation(timeZone));
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} ${local.timeZoneName}';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (plans.isNotEmpty) ...[
        const Text(
          'Spot-price import plan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (overrideActive)
          const Text(
            'Manual override takes priority. Blocked charging quarters will not be replaced.',
          ),
        const Text(
          'Nominal energy only. Interrupted or missed quarters are not replaced; actual imported energy may be lower.',
        ),
      ],
      for (final plan in plans) ...[
        const SizedBox(height: 8),
        Text(
          '${(plan.targetWh / 1000).toStringAsFixed(3)} kWh target • ${plan.powerW} W maximum',
        ),
        Text(
          plan.status == 'pending_prices'
              ? 'Waiting for prices — peak shaving only'
              : plan.status == 'insufficient_capacity'
              ? 'Insufficient remaining capacity — ${(plan.nominalWh / 1000).toStringAsFixed(3)} kWh nominal planned'
              : '${(plan.nominalWh / 1000).toStringAsFixed(3)} kWh nominal planned',
        ),
        for (final slot in plan.slots)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              '${_time(slot.start)} – ${_time(slot.end)} • ${slot.selected ? 'Import enabled' : 'Peak shaving only'}',
            ),
          ),
      ],
    ],
  );
}
