import 'package:flutter/foundation.dart';

/// Lets any screen switch the bottom-bar tab (0 Feed, 1 Groups, 2 Chat, 3 Study, 4 AI).
class TabNav extends ChangeNotifier {
  int index = 0;
  void go(int i) {
    if (i == index) return;
    index = i;
    notifyListeners();
  }
}
