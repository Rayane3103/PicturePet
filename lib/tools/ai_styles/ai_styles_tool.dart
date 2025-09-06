// No Flutter imports needed here; pure state holder

class AIStylesTool {
  bool _showStylesView = false;
  String? _selectedStyle;

  final List<Map<String, dynamic>> _styles = [
    {'name': 'Original', 'preview': null},
    {'name': 'Ghibli', 'preview': null},
    {'name': 'Toonify', 'preview': null},
    {'name': 'Cyberpunk', 'preview': null},
    {'name': 'Watercolor', 'preview': null},
    {'name': 'Oil Paint', 'preview': null},
  ];

  bool get showStylesView => _showStylesView;
  String? get selectedStyle => _selectedStyle;
  List<Map<String, dynamic>> get styles => _styles;

  void showStyles() {
    _showStylesView = true;
  }

  void backFromStylesView() {
    _showStylesView = false;
    _selectedStyle = null;
  }

  void selectStyle(String styleName) {
    _selectedStyle = styleName;
  }
}


