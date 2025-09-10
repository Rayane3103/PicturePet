import 'package:flutter/material.dart';

class AddTextTool {
  bool showTextView = false;
  String text = '';
  int x = 20;
  int y = 20;
  int fontSize = 32;
  Color color = Colors.white;
  
  // Normalized position within the canvas [0, 1].
  // Used for interactive dragging; converted to pixel coordinates on apply.
  double normalizedX = 0.1;
  double normalizedY = 0.1;

  void show() {
    showTextView = true;
  }

  void back() {
    showTextView = false;
  }
}


