import 'package:flutter/material.dart';
import '../../data/spot_import.dart';

class ImportEnergyFields extends StatelessWidget {
  const ImportEnergyFields({
    super.key,
    required this.energyText,
    required this.powerW,
    required this.onChanged,
  });
  final String energyText;
  final int powerW;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final target = parseImportWh(energyText);
    final quarters = importQuarterCount(target ?? 0, powerW);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: energyText,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Energy to import (kWh)',
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        if (target != null && target > 0 && powerW > 0)
          Text(
            '$quarters × 15 minutes • ${(quarters * powerW / 4000).toStringAsFixed(3)} kWh nominal',
          ),
        const Text(
          'Charging is enabled in the cheapest quarters. Other quarters only peak shave. Actual import depends on the inverter and battery.',
        ),
      ],
    );
  }
}
