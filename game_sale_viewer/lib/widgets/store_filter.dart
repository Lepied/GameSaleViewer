import 'package:flutter/material.dart';
import '../models/store.dart';

/// 스토어 필터 위젯
class StoreFilter extends StatelessWidget {
  final String? selectedStoreId;
  final Function(String?) onStoreSelected;

  const StoreFilter({
    super.key,
    required this.selectedStoreId,
    required this.onStoreSelected,
  });

  @override
  Widget build(BuildContext context) {
    final stores = [
      {'id': null, 'name': '전체'},
      {'id': StoreIds.steam, 'name': 'Steam'},
      {'id': StoreIds.epicGames, 'name': 'Epic'},
      {'id': StoreIds.gog, 'name': 'GOG'},
      {'id': StoreIds.humbleStore, 'name': 'Humble'},
      {'id': StoreIds.greenManGaming, 'name': 'GMG'},
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: stores.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final store = stores[index];
            final isSelected = selectedStoreId == store['id'];

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(store['name'] as String),
                selected: isSelected,
                onSelected: (selected) {
                  onStoreSelected(selected ? store['id'] : null);
                },
                selectedColor: const Color(0xFF66c0f4),
                backgroundColor: Colors.grey[800],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
