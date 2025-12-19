import 'package:flutter/material.dart';
import 'package:lendify/models/category.dart';
import 'package:lendify/utils/category_label.dart';

class CategoryChips extends StatelessWidget {
  final List<Category> categories;
  final List<String> selectedCategories;
  final Function(String) onCategorySelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategories,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategories.contains(category.id);
          
          return Padding(
            padding: EdgeInsets.only(right: index < categories.length - 1 ? 8 : 0),
            child: FilterChip(
              label: Text(
                stackCategoryLabel(category.name),
                maxLines: 2,
                softWrap: true,
                textAlign: TextAlign.center,
              ),
              selected: isSelected,
              onSelected: (_) => onCategorySelected(category.id),
              backgroundColor: Colors.white,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }
}