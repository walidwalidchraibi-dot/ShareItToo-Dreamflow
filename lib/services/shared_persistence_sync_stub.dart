import 'dart:async';

final StreamController<String> _controller =
    StreamController<String>.broadcast(sync: true);

Stream<String> get sharedPersistenceChanges => _controller.stream;

void notifySharedPersistenceChange(String key) {
  if (!_controller.isClosed) {
    _controller.add(key);
  }
}
