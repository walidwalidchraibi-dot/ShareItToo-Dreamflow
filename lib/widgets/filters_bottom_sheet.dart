import 'package:flutter/material.dart';
import 'package:lendify/utils/condition_labels.dart';

class FiltersBottomSheet extends StatefulWidget {
  const FiltersBottomSheet({super.key});

  @override
  State<FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<FiltersBottomSheet> {
  RangeValues _priceRange = const RangeValues(0, 500);
  double _distance = 25;
  bool _verifiedOnly = false;
  String _condition = 'all';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          const Text('Preis pro Tag', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 500,
            divisions: 50,
            labels: RangeLabels(
              '${_priceRange.start.round()} €',
              '${_priceRange.end.round()} €',
            ),
            onChanged: (values) => setState(() => _priceRange = values),
          ),
          Text(
            '${_priceRange.start.round()} € - ${_priceRange.end.round()} €',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          
          const SizedBox(height: 24),
          const Text('Entfernung', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Slider(
            value: _distance,
            min: 5,
            max: 50,
            divisions: 9,
            label: '${_distance.round()} km',
            onChanged: (value) => setState(() => _distance = value),
          ),
          Text(
            '${_distance.round()} km',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          
          const SizedBox(height: 24),
          const Text('Zustand', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildConditionChip('all', ConditionLabels.filterLabel('egal')),
              _buildConditionChip('like-new', ConditionLabels.label('like-new')),
              _buildConditionChip('good', ConditionLabels.label('good')),
              _buildConditionChip('acceptable', ConditionLabels.label('acceptable')),
            ],
          ),
          
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Nur verifiziert'),
            value: _verifiedOnly,
            onChanged: (value) => setState(() => _verifiedOnly = value),
            contentPadding: EdgeInsets.zero,
          ),
          
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _priceRange = const RangeValues(0, 500);
                      _distance = 25;
                      _verifiedOnly = false;
                      _condition = 'all';
                    });
                    // Close immediately after reset
                    Navigator.pop(context);
                  },
                  child: const Text('Zurücksetzen'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Anwenden'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionChip(String value, String label) {
    final isSelected = _condition == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _condition = value),
      backgroundColor: Colors.grey.shade100,
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
      ),
    );
  }
}