class AdjustTool {
  bool showAdjustView = false;
  double brightness = 0.0; // [-1,1]
  double contrast = 1.0;   // [0,?]
  double saturation = 1.0; // [0,?]

  void show() {
    showAdjustView = true;
  }

  void back() {
    showAdjustView = false;
  }

  void reset() {
    brightness = 0.0;
    contrast = 1.0;
    saturation = 1.0;
  }
}


