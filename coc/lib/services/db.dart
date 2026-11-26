import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;

import '../core/errors.dart';
import '../core/models.dart';

/// Everything the app reads/writes in Cloud Firestore.
///
/// Collections:
///   users/{uid}  (+ likes, saved, following, followers, notifications)
///   posts/{id}   (+ comments)
///   groups/{id}            studyRooms/{id} (+ notes)
///   conversations/{id} (+ messages)
///   events/{id}            reports/{id}
class Db {
  Db._();

  static FirebaseFirestore get _fs => FirebaseFirestore.instance;
  static CollectionReference<Json> get _users => _fs.collection('users');
  static CollectionReference<Json> get _posts => _fs.collection('posts');
  static CollectionReference<Json> get _groups => _fs.collection('groups');
  static CollectionReference<Json> get _rooms => _fs.collection('studyRooms');
  static CollectionReference<Json> get _convs => _fs.collection('conversations');
  static CollectionReference<Json> get _events => _fs.collection('events');
  static CollectionReference<Json> get _reports => _fs.collection('reports');

  static List<String> _words(String name) => name
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toSet()
      .toList();

  static void _notify(WriteBatch b, String toUid,
      {required String fromUid, required String kind, required String body, String? targetId}) {
    if (toUid == fromUid) return;
    b.set(_users.doc(toUid).collection('notifications').doc(), {
      'kind': kind,
      'body': body,
      'targetId': targetId,
      'fromUid': fromUid,
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });
  }

  // ───────────────────────── Users / profile ─────────────────────────

  static Future<void> createUserProfile(User u,
      {required String fullName, String? fieldOfStudy, int? yearOfStudy}) async {
    final name = fullName.trim();
    final data = <String, dynamic>{
      'fullName': name,
      'nameLower': name.toLowerCase(),
      'nameWords': _words(name),
      'fieldOfStudy': fieldOfStudy,
      'yearOfStudy': yearOfStudy,
      'role': 'USER',
      'organizationVerified': false,
      'searchable': true,
      'profileVisibility': 'CAMPUS',
      'messageRequests': 'CAMPUS',
      'interests': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null);
    await _users.doc(u.uid).set(data, SetOptions(merge: true));
  }

  /// Makes sure users/{uid} exists (covers a failed write during sign-up).
  static Future<void> ensureProfile(User u) async {
    var snap = await _users.doc(u.uid).get();
    if (!snap.exists) {
      await Future.delayed(const Duration(milliseconds: 1500));
      snap = await _users.doc(u.uid).get();
    }
    if (!snap.exists) {
      await createUserProfile(u,
          fullName: u.displayName ?? (u.email ?? 'Campus member').split('@').first);
    }
  }

  static Stream<AppUser?> userStream(String uid) =>
      _users.doc(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);

  static Future<AppUser?> getUser(String uid) async {
    final d = await _users.doc(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  static Future<void> updateProfile(String uid,
      {required String fullName,
      String? fieldOfStudy,
      int? yearOfStudy,
      String? bio,
      required List<String> interests}) {
    final name = fullName.trim();
    return _users.doc(uid).update({
      'fullName': name,
      'nameLower': name.toLowerCase(),
      'nameWords': _words(name),
      'fieldOfStudy': (fieldOfStudy == null || fieldOfStudy.trim().isEmpty) ? null : fieldOfStudy.trim(),
      'yearOfStudy': yearOfStudy,
      'bio': (bio == null || bio.trim().isEmpty) ? null : bio.trim(),
      'interests': interests,
    });
  }

  static Future<void> updatePrivacy(String uid,
      {required String profileVisibility, required String messageRequests, required bool searchable}) {
    return _users.doc(uid).update({
      'profileVisibility': profileVisibility,
      'messageRequests': messageRequests,
      'searchable': searchable,
    });
  }

  static bool _visible(AppUser u, String me, bool Function(String) isConnection) {
    if (u.id == me || !u.searchable) return false;
    if (u.profileVisibility == 'CAMPUS') return true;
    if (u.profileVisibility == 'CONNECTIONS') return isConnection(u.id);
    return false;
  }

  /// Prefix search on the full name, plus exact word match (e.g. last name).
  static Future<List<AppUser>> searchPeople(
      String raw, String me, bool Function(String) isConnection) async {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return [];
    final res = await Future.wait([
      _users
          .where('nameLower', isGreaterThanOrEqualTo: q)
          .where('nameLower', isLessThan: '$q\uf8ff')
          .limit(25)
          .get(),
      _users.where('nameWords', arrayContains: q.split(' ').last).limit(25).get(),
    ]);
    final seen = <String>{};
    final out = <AppUser>[];
    for (final snap in res) {
      for (final d in snap.docs) {
        if (!seen.add(d.id)) continue;
        final u = AppUser.fromDoc(d);
        if (_visible(u, me, isConnection)) out.add(u);
      }
    }
    out.sort((a, b) => a.fullName.compareTo(b.fullName));
    return out;
  }

  static Future<List<AppUser>> recentPeople(String me, bool Function(String) isConnection) async {
    final snap = await _users.orderBy('createdAt', descending: true).limit(30).get();
    return snap.docs
        .map(AppUser.fromDoc)
        .where((u) => _visible(u, me, isConnection))
        .toList();
  }

  // ───────────────────────── Viewer sub-collections ─────────────────────────

  static Stream<Set<String>> idSet(String uid, String sub) =>
      _users.doc(uid).collection(sub).snapshots().map((s) => s.docs.map((d) => d.id).toSet());

  static Stream<List<Person>> people(String uid, String sub) =>
      _users.doc(uid).collection(sub).snapshots().map((s) {
        final list = s.docs.map(Person.fromDoc).toList();
        list.sort((a, b) => a.fullName.compareTo(b.fullName));
        return list;
      });

  static Stream<List<AppNotification>> notifications(String uid) => _users
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());

  static Future<void> markNotificationRead(String uid, String id) =>
      _users.doc(uid).collection('notifications').doc(id).update({'readAt': FieldValue.serverTimestamp()});

  static Future<void> markAllNotificationsRead(String uid, Iterable<AppNotification> list) async {
    final unread = list.where((n) => n.unread).toList();
    if (unread.isEmpty) return;
    final b = _fs.batch();
    for (final n in unread) {
      b.update(_users.doc(uid).collection('notifications').doc(n.id), {'readAt': FieldValue.serverTimestamp()});
    }
    await b.commit();
  }

  // ───────────────────────── Follow ─────────────────────────

  static Future<void> follow(AppUser me, Person p) async {
    final b = _fs.batch();
    b.set(_users.doc(me.id).collection('following').doc(p.id),
        {'fullName': p.fullName, 'fieldOfStudy': p.fieldOfStudy, 'createdAt': FieldValue.serverTimestamp()});
    b.set(_users.doc(p.id).collection('followers').doc(me.id),
        {'fullName': me.fullName, 'fieldOfStudy': me.fieldOfStudy, 'createdAt': FieldValue.serverTimestamp()});
    _notify(b, p.id,
        fromUid: me.id, kind: 'FOLLOW', body: '${me.fullName} started following you', targetId: me.id);
    await b.commit();
  }

  static Future<void> unfollow(String me, String other) async {
    final b = _fs.batch();
    b.delete(_users.doc(me).collection('following').doc(other));
    b.delete(_users.doc(other).collection('followers').doc(me));
    await b.commit();
  }

  // ───────────────────────── Posts ─────────────────────────

  static Stream<List<Post>> feed() => _posts
      .orderBy('createdAt', descending: true)
      .limit(80)
      .snapshots()
      .map((s) => s.docs.map(Post.fromDoc).where((p) => p.deletedAt == null).toList());

  static Stream<List<Post>> userPosts(String uid) =>
      _posts.where('authorId', isEqualTo: uid).snapshots().map((s) {
        final list = s.docs.map(Post.fromDoc).where((p) => p.deletedAt == null).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  static Stream<Post?> postStream(String id) =>
      _posts.doc(id).snapshots().map((d) {
        if (!d.exists) return null;
        final p = Post.fromDoc(d);
        return p.deletedAt == null ? p : null;
      });

  static Future<int> postCount(String uid) async {
    final agg = await _posts.where('authorId', isEqualTo: uid).count().get();
    return agg.count ?? 0;
  }

  static Future<void> createPost(AppUser me,
      {required String body, String? tag, String? imageUrl}) async {
    final text = body.trim();
    if (text.isEmpty) throw AppException('Write something first.');
    await _posts.add({
      'authorId': me.id,
      'author': me.fullName,
      'course': (me.fieldOfStudy == null || me.fieldOfStudy!.isEmpty) ? 'Campus member' : me.fieldOfStudy,
      'body': text,
      'imageUrl': (imageUrl == null || imageUrl.trim().isEmpty) ? null : imageUrl.trim(),
      'tag': tag,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'deletedAt': null,
      'undoExpiresAt': null,
      'removedByAdmin': false,
    });
  }

  /// Soft delete with a short undo window (same behaviour as the web app).
  static Future<DateTime> deletePost(String id) async {
    final expires = DateTime.now().add(const Duration(seconds: 10));
    await _posts.doc(id).update({
      'deletedAt': FieldValue.serverTimestamp(),
      'undoExpiresAt': Timestamp.fromDate(expires),
    });
    return expires;
  }

  static Future<void> undoDelete(String id) =>
      _posts.doc(id).update({'deletedAt': null, 'undoExpiresAt': null});

  static Future<void> setLike(AppUser me, Post post, bool like) async {
    final b = _fs.batch();
    final likeRef = _users.doc(me.id).collection('likes').doc(post.id);
    if (like) {
      b.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
    } else {
      b.delete(likeRef);
    }
    b.update(_posts.doc(post.id), {'likeCount': FieldValue.increment(like ? 1 : -1)});
    if (like) {
      _notify(b, post.authorId,
          fromUid: me.id, kind: 'LIKE', body: '${me.fullName} liked your post', targetId: post.id);
    }
    await b.commit();
  }

  static Future<void> setSaved(String me, String postId, bool saved) {
    final ref = _users.doc(me).collection('saved').doc(postId);
    return saved ? ref.set({'createdAt': FieldValue.serverTimestamp()}) : ref.delete();
  }

  static Future<List<Post>> postsByIds(Iterable<String> ids) async {
    final docs = await Future.wait(ids.map((id) => _posts.doc(id).get()));
    final list = docs.where((d) => d.exists).map(Post.fromDoc).where((p) => p.deletedAt == null).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Stream<List<Comment>> comments(String postId) => _posts
      .doc(postId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Comment.fromDoc).toList());

  static Future<void> addComment(AppUser me, Post post, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    final b = _fs.batch();
    b.set(_posts.doc(post.id).collection('comments').doc(), {
      'authorId': me.id,
      'author': me.fullName,
      'body': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    b.update(_posts.doc(post.id), {'commentCount': FieldValue.increment(1)});
    _notify(b, post.authorId,
        fromUid: me.id, kind: 'COMMENT', body: '${me.fullName} commented on your post', targetId: post.id);
    await b.commit();
  }

  static Future<void> reportPost(AppUser me, String postId, String message) async {
    final text = message.trim();
    if (text.isEmpty) throw AppException('Tell us briefly what is wrong with this post.');
    await _reports.add({
      'reporterId': me.id,
      'postId': postId,
      'message': text,
      'status': 'OPEN',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ───────────────────────── Groups ─────────────────────────

  static Stream<List<Group>> groups() => _groups
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Group.fromDoc).toList());

  static Stream<Group?> groupStream(String id) =>
      _groups.doc(id).snapshots().map((d) => d.exists ? Group.fromDoc(d) : null);

  static Future<String> createGroup(AppUser me,
      {required String name, required String category, required String description}) async {
    final ref = await _groups.add({
      'name': name.trim(),
      'category': category,
      'description': description.trim(),
      'ownerId': me.id,
      'ownerName': me.fullName,
      'memberIds': [me.id],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> setGroupMember(String groupId, String uid, bool join) => _groups.doc(groupId).update({
        'memberIds': join ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      });

  static Future<void> updateGroup(String id,
          {required String name, required String category, required String description}) =>
      _groups.doc(id).update({'name': name.trim(), 'category': category, 'description': description.trim()});

  static Future<void> deleteGroup(String id) => _groups.doc(id).delete();

  // ───────────────────────── Messaging ─────────────────────────

  static String convId(String a, String b) => (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';

  static Stream<List<Conversation>> conversations(String me) =>
      _convs.where('participants', arrayContains: me).snapshots().map((s) {
        final list = s.docs.map(Conversation.fromDoc).toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return list;
      });

  static Stream<Conversation?> conversationStream(String id) =>
      _convs.doc(id).snapshots().map((d) => d.exists ? Conversation.fromDoc(d) : null);

  /// Opens (or creates) a 1-to-1 conversation, honouring the other person's
  /// "message requests" privacy setting.
  static Future<String> openConversation(AppUser me, String otherId, {required bool mutual}) async {
    final id = convId(me.id, otherId);
    final ref = _convs.doc(id);
    final existing = await ref.get();
    if (existing.exists) return id;

    final other = await getUser(otherId);
    if (other == null) throw AppException('This member could not be found.');
    if (other.messageRequests == 'NOBODY') {
      throw AppException('This member is not accepting new message requests.');
    }
    if (other.messageRequests == 'CONNECTIONS' && !mutual) {
      throw AppException('This member only accepts messages from connections.');
    }
    await ref.set({
      'participants': [me.id, otherId],
      'names': {me.id: me.fullName, otherId: other.fullName},
      'lastMessage': '',
      'lastSenderId': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  static Stream<List<Message>> messages(String convId) => _convs
      .doc(convId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(120)
      .snapshots()
      .map((s) => s.docs.map(Message.fromDoc).toList());

  static Future<void> sendMessage(AppUser me, Conversation c, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    final b = _fs.batch();
    final ref = _convs.doc(c.id);
    b.set(ref.collection('messages').doc(), {
      'senderId': me.id,
      'body': text,
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });
    b.update(ref, {
      'lastMessage': text.length > 140 ? text.substring(0, 140) : text,
      'lastSenderId': me.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Only notify at the start of a run of messages to avoid spamming.
    if (c.lastSenderId != me.id) {
      _notify(b, c.otherId(me.id),
          fromUid: me.id, kind: 'MESSAGE', body: 'New message from ${me.fullName}', targetId: c.id);
    }
    await b.commit();
  }

  static Future<void> markMessagesRead(String convId, String me) async {
    final q = await _convs.doc(convId).collection('messages').where('readAt', isNull: true).get();
    final mine = q.docs.where((d) => d.data()['senderId'] != me).toList();
    if (mine.isEmpty) return;
    final b = _fs.batch();
    for (final d in mine) {
      b.update(d.reference, {'readAt': FieldValue.serverTimestamp()});
    }
    await b.commit();
  }

  static Future<String> startCall(AppUser me, Conversation c) async {
    final b = _fs.batch();
    _notify(b, c.otherId(me.id),
        fromUid: me.id, kind: 'CALL', body: '${me.fullName} is calling you', targetId: c.id);
    await b.commit();
    return 'https://meet.jit.si/CampusConnect-call-${c.id}#config.startWithVideoMuted=true';
  }

  // ───────────────────────── Study rooms ─────────────────────────

  static Stream<List<StudyRoom>> studyRooms() => _rooms
      .orderBy('startsAt')
      .snapshots()
      .map((s) => s.docs.map(StudyRoom.fromDoc).toList());

  static Stream<StudyRoom?> studyRoomStream(String id) =>
      _rooms.doc(id).snapshots().map((d) => d.exists ? StudyRoom.fromDoc(d) : null);

  static Future<String> createStudyRoom(AppUser me,
      {required String title,
      required String topic,
      required DateTime startsAt,
      required String location,
      required List<String> agenda}) async {
    final ref = await _rooms.add({
      'ownerId': me.id,
      'title': title.trim(),
      'topic': topic.trim(),
      'startsAt': Timestamp.fromDate(startsAt),
      'location': location.trim(),
      'agenda': agenda,
      'memberIds': [me.id],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> setRoomMember(String roomId, String uid, bool join) => _rooms.doc(roomId).update({
        'memberIds': join ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      });

  static Stream<List<SharedNote>> notes(String roomId) => _rooms
      .doc(roomId)
      .collection('notes')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(SharedNote.fromDoc).toList());

  static Future<void> saveNote(AppUser me, String roomId,
      {String? noteId, required String title, required String content}) async {
    final col = _rooms.doc(roomId).collection('notes');
    if (noteId == null) {
      await col.add({
        'authorId': me.id,
        'author': me.fullName,
        'title': title.trim(),
        'content': content.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await col.doc(noteId).update({
        'title': title.trim(),
        'content': content.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> deleteNote(String roomId, String noteId) =>
      _rooms.doc(roomId).collection('notes').doc(noteId).delete();

  // ───────────────────────── Events ─────────────────────────

  static Stream<List<CampusEvent>> events() =>
      _events.where('published', isEqualTo: true).snapshots().map((s) {
        final cutoff = DateTime.now().subtract(const Duration(hours: 6));
        final list = s.docs.map(CampusEvent.fromDoc).where((e) => e.startsAt.isAfter(cutoff)).toList();
        list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
        return list;
      });

  static Future<void> publishEvent(AppUser me,
      {required String title,
      required String category,
      required String description,
      required DateTime startsAt,
      DateTime? endsAt,
      required String location,
      String? registrationUrl}) async {
    if (!me.organizationVerified) {
      throw AppException('Ask an administrator to verify your university or government account.');
    }
    await _events.add({
      'organizationId': me.id,
      'organizationName': me.organizationName ?? me.fullName,
      'organizationType': me.organizationType ?? 'UNIVERSITY',
      'title': title.trim(),
      'category': category,
      'description': description.trim(),
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': endsAt == null ? null : Timestamp.fromDate(endsAt),
      'location': location.trim(),
      'registrationUrl': (registrationUrl == null || registrationUrl.trim().isEmpty) ? null : registrationUrl.trim(),
      'published': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ───────────────────────── Admin ─────────────────────────

  static Stream<List<AppUser>> adminUsers() => _users
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());

  static Future<void> verifyOrganization(String uid, {required String type, required String name}) =>
      _users.doc(uid).update({
        'organizationType': type,
        'organizationName': name.trim(),
        'organizationVerified': true,
      });

  static Future<void> revokeOrganization(String uid) => _users.doc(uid).update({
        'organizationVerified': false,
        'organizationType': null,
        'organizationName': null,
      });

  static Stream<List<Report>> reports() => _reports
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Report.fromDoc).toList());

  /// approve = keep the post, remove = take it down.
  static Future<void> reviewReport(Report r, {required bool remove}) async {
    final b = _fs.batch();
    b.update(_reports.doc(r.id), {'status': remove ? 'REMOVED' : 'APPROVED'});
    if (remove && r.postId != null) {
      b.update(_posts.doc(r.postId!), {
        'deletedAt': FieldValue.serverTimestamp(),
        'undoExpiresAt': null,
        'removedByAdmin': true,
      });
    }
    await b.commit();
  }

  // ───────────────────────── Assistant index ─────────────────────────

  static Future<CampusIndex> campusIndex() async {
    final res = await Future.wait([
      _groups.limit(100).get(),
      _rooms.limit(100).get(),
      _posts.orderBy('createdAt', descending: true).limit(80).get(),
      _events.where('published', isEqualTo: true).limit(50).get(),
    ]);
    return CampusIndex(
      groups: res[0].docs.map(Group.fromDoc).toList(),
      rooms: res[1].docs.map(StudyRoom.fromDoc).where((r) => !r.isPast).toList(),
      posts: res[2].docs.map(Post.fromDoc).where((p) => p.deletedAt == null).toList(),
      events: res[3].docs.map(CampusEvent.fromDoc).toList(),
    );
  }

  // ───────────────────────── Demo content (debug builds only) ─────────────────────────

  static Future<void> seedDemo(AppUser me) async {
    final b = _fs.batch();
    final posts = [
      ('Build day is this Friday! Who\u2019s joining us? Bring your ideas. We\u2019ll bring the good company.',
          'asset:campus-community.jpg', 'Community'),
      ('Looking for two teammates for the data structures project. We meet in the library on Thursdays.',
          'asset:campus-library.jpg', 'Study'),
      ('Sharing my notes on binary trees \u2014 hope they help someone before the quiz!', null, 'Education'),
    ];
    for (final p in posts) {
      b.set(_posts.doc(), {
        'authorId': me.id,
        'author': me.fullName,
        'course': me.fieldOfStudy ?? 'Campus member',
        'body': p.$1,
        'imageUrl': p.$2,
        'tag': p.$3,
        'likeCount': 0,
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'deletedAt': null,
        'undoExpiresAt': null,
        'removedByAdmin': false,
      });
    }
    final groups = [
      ('CS Study Circle', 'Academic', 'Peer learning & projects for computer science students.'),
      ('Design Society', 'Community', 'Share work, get feedback and meet other designers.'),
      ('AI & Robotics Club', 'Community', 'Hack nights, reading groups and robot builds.'),
    ];
    for (final g in groups) {
      b.set(_groups.doc(), {
        'name': g.$1,
        'category': g.$2,
        'description': g.$3,
        'ownerId': me.id,
        'ownerName': me.fullName,
        'memberIds': [me.id],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    b.set(_rooms.doc(), {
      'ownerId': me.id,
      'title': 'Data structures, together.',
      'topic': 'CS Study Circle \u00b7 Data structures',
      'startsAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
      'location': 'Library, room 2 / online',
      'agenda': ['Binary tree warm-up', 'Walk through DFS and BFS', 'Practice together'],
      'memberIds': [me.id],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await b.commit();
  }
}

class CampusIndex {
  CampusIndex({required this.groups, required this.rooms, required this.posts, required this.events});
  final List<Group> groups;
  final List<StudyRoom> rooms;
  final List<Post> posts;
  final List<CampusEvent> events;
}
