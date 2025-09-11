import 'dart:async';

class ProjectsEvents {
  ProjectsEvents._internal();
  static final ProjectsEvents instance = ProjectsEvents._internal();

  final StreamController<void> _controller = StreamController<void>.broadcast();
  Stream<void> get stream => _controller.stream;

  void notifyChanged() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }
}


