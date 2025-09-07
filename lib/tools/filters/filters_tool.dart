import 'package:flutter/material.dart';

class FiltersTool {
  // Filter state
  bool _showFiltersView = false;
  String? _selectedFilter;

  // Filter definitions
  final List<Map<String, dynamic>> _filters = [
    {'name': 'Original', 'matrix': null},
    {'name': 'Black & White', 'matrix': <double>[
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0, 0, 0, 1, 0,
    ]},
    {'name': 'Sepia', 'matrix': <double>[
      0.393, 0.769, 0.189, 0, 0,
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0, 0, 0, 1, 0,
    ]},
    {'name': 'Vintage', 'matrix': <double>[
      0.9, 0.5, 0.1, 0, 0,
      0.3, 0.8, 0.1, 0, 0,
      0.2, 0.3, 0.5, 0, 0,
      0, 0, 0, 1, 0,
    ]},
    {'name': 'Bright', 'matrix': <double>[
      1.2, 0, 0, 0, 0,
      0, 1.2, 0, 0, 0,
      0, 0, 1.2, 0, 0,
      0, 0, 0, 1, 0,
    ]},
    {'name': 'Warm', 'matrix': <double>[
      1.1, 0, 0, 0, 0,
      0, 1.0, 0, 0, 0,
      0, 0, 0.9, 0, 0,
      0, 0, 0, 1, 0,
    ]},
    {'name': 'Cool', 'matrix': <double>[
      0.9, 0, 0, 0, 0,
      0, 1.0, 0, 0, 0,
      0, 0, 1.1, 0, 0,
      0, 0, 0, 1, 0,
    ]},
    {'name': 'High Contrast', 'matrix': <double>[
      1.5, 0, 0, 0, 0,
      0, 1.5, 0, 0, 0,
      0, 0, 1.5, 0, 0,
      0, 0, 0, 1, 0,
    ]},
    {'name': 'Low Contrast', 'matrix': <double>[
      0.7, 0, 0, 0, 0,
      0, 0.7, 0, 0, 0,
      0, 0, 0.7, 0, 0,
      0, 0, 0, 1, 0,
    ]},
    {'name': 'Saturated', 'matrix': <double>[
      1.3, 0, 0, 0, 0,
      0, 1.3, 0, 0, 0,
      0, 0, 1.3, 0, 0,
      0, 0, 0, 1, 0,
    ]},
  ];

  // Getters
  bool get showFiltersView => _showFiltersView;
  String? get selectedFilter => _selectedFilter;
  List<Map<String, dynamic>> get filters => _filters;

  // Methods
  void showFilters() {
    _showFiltersView = true;
  }

  void backFromFiltersView() {
    _showFiltersView = false;
    _selectedFilter = null;
  }

  void selectFilter(String filterName) {
    _selectedFilter = filterName;
  }

  void clearFilter() {
    _selectedFilter = null;
  }

  Map<String, dynamic>? getSelectedFilterData() {
    if (_selectedFilter == null) return null;
    try {
      return _filters.firstWhere((f) => f['name'] == _selectedFilter);
    } catch (e) {
      return null;
    }
  }

  ColorFilter? getSelectedColorFilter() {
    final filterData = getSelectedFilterData();
    if (filterData == null || filterData['matrix'] == null) return null;
    return ColorFilter.matrix(filterData['matrix']);
  }
}
