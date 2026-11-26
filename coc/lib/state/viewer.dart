import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../services/db.dart';

/// Live data about the signed-in person: profile, likes, saved posts,
/// follow graph and notifications. Created once per sign-in.
class ViewerData extends ChangeNotifier {
  ViewerData(this.user);
  final User user;

  AppUser? profile;
  Set<String> likedIds = {};
  Set<String> savedIds = {};
  Set<String> followingIds = {};
  Set<String> followerIds = {};
  List<AppNotification> notifications = [];

  final List<StreamSubscription<dynamic>> _subs = [];
  bool _disposed = false;

  String get uid => user.uid;
  String get email => user.email ?? '';
  bool get emailVerified => user.emailVerified;
  int get unreadCount => notifications.where((n) => n.unread).length;
  AppUser get me => profile!;

  /// A "connection" is a mutual follow.
  bool isConnection(String id) => followingIds.contains(id) && followerIds.contains(id);

  Future<void> start() async {
    try {
      await Db.ensureProfile(user);
    } catch (_) {
      // Listening below will surface permission problems as an empty profile.
    }
    if (_disposed) return;
    _listen<AppUser?>(Db.userStream(uid), (v) => profile = v);
    _listen<Set<String>>(Db.idSet(uid, 'likes'), (v) => likedIds = v);
    _listen<Set<String>>(Db.idSet(uid, 'saved'), (v) => savedIds = v);
    _listen<Set<String>>(Db.idSet(uid, 'following'), (v) => followingIds = v);
    _listen<Set<String>>(Db.idSet(uid, 'followers'), (v) => followerIds = v);
    _listen<List<AppNotification>>(Db.notifications(uid), (v) => notifications = v);
  }

  void _listen<T>(Stream<T> stream, void Function(T) onData) {
    _subs.add(stream.listen((v) {
      if (_disposed) return;
      onData(v);
      notifyListeners();
    }, onError: (Object _) {}));
  }

  Future<void> reloadUser() async {
    await user.reload();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
