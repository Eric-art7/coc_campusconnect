import 'package:cloud_firestore/cloud_firestore.dart';
import 'format.dart';

typedef Json = Map<String, dynamic>;
typedef Doc = DocumentSnapshot<Json>;

DateTime _dt(Object? v) => v is Timestamp ? v.toDate() : DateTime.now();
DateTime? _dtn(Object? v) => v is Timestamp ? v.toDate() : null;
int _int(Object? v) => v is num ? v.toInt() : 0;
List<String> _strs(Object? v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

/// users/{uid}
class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    this.fieldOfStudy,
    this.yearOfStudy,
    this.bio,
    this.interests = const [],
    this.role = 'USER',
    this.organizationType,
    this.organizationName,
    this.organizationVerified = false,
    this.searchable = true,
    this.profileVisibility = 'CAMPUS',
    this.messageRequests = 'CAMPUS',
    required this.createdAt,
  });
  final String id, fullName, role, profileVisibility, messageRequests;
  final String? fieldOfStudy, bio, organizationType, organizationName;
  final int? yearOfStudy;
  final List<String> interests;
  final bool organizationVerified, searchable;
  final DateTime createdAt;

  String get initials => initialsOf(fullName);
  bool get isAdmin => role == 'ADMIN';
  String get detail {
    final parts = <String>[
      if (fieldOfStudy != null && fieldOfStudy!.isNotEmpty) fieldOfStudy!,
      if (yearOfStudy != null) 'Year $yearOfStudy',
    ];
    return parts.isEmpty ? 'Campus member' : parts.join(' · ');
  }

  Person toPerson() => Person(id: id, fullName: fullName, fieldOfStudy: fieldOfStudy);

  factory AppUser.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return AppUser(
      id: d.id,
      fullName: (m['fullName'] ?? 'Campus member').toString(),
      fieldOfStudy: m['fieldOfStudy'] as String?,
      yearOfStudy: m['yearOfStudy'] is num ? (m['yearOfStudy'] as num).toInt() : null,
      bio: m['bio'] as String?,
      interests: _strs(m['interests']),
      role: (m['role'] ?? 'USER').toString(),
      organizationType: m['organizationType'] as String?,
      organizationName: m['organizationName'] as String?,
      organizationVerified: m['organizationVerified'] == true,
      searchable: m['searchable'] != false,
      profileVisibility: (m['profileVisibility'] ?? 'CAMPUS').toString(),
      messageRequests: (m['messageRequests'] ?? 'CAMPUS').toString(),
      createdAt: _dt(m['createdAt']),
    );
  }
}

/// Lightweight person (follow lists, search rows).
class Person {
  Person({required this.id, required this.fullName, this.fieldOfStudy});
  final String id, fullName;
  final String? fieldOfStudy;
  String get initials => initialsOf(fullName);
  String get detail =>
      (fieldOfStudy == null || fieldOfStudy!.isEmpty) ? 'Campus member' : fieldOfStudy!;
  factory Person.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return Person(
        id: d.id,
        fullName: (m['fullName'] ?? 'Campus member').toString(),
        fieldOfStudy: m['fieldOfStudy'] as String?);
  }
}

class Post {
  Post({
    required this.id,
    required this.authorId,
    required this.author,
    required this.course,
    required this.body,
    this.imageUrl,
    this.tag,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    this.deletedAt,
  });
  final String id, authorId, author, course, body;
  final String? imageUrl, tag;
  final int likeCount, commentCount;
  final DateTime createdAt;
  final DateTime? deletedAt;
  String get initials => initialsOf(author);

  factory Post.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return Post(
      id: d.id,
      authorId: (m['authorId'] ?? '').toString(),
      author: (m['author'] ?? 'Campus member').toString(),
      course: (m['course'] ?? 'Campus member').toString(),
      body: (m['body'] ?? '').toString(),
      imageUrl: m['imageUrl'] as String?,
      tag: m['tag'] as String?,
      likeCount: _int(m['likeCount']),
      commentCount: _int(m['commentCount']),
      createdAt: _dt(m['createdAt']),
      deletedAt: _dtn(m['deletedAt']),
    );
  }
}

class Comment {
  Comment({required this.id, required this.authorId, required this.author, required this.body, required this.createdAt});
  final String id, authorId, author, body;
  final DateTime createdAt;
  factory Comment.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return Comment(
      id: d.id,
      authorId: (m['authorId'] ?? '').toString(),
      author: (m['author'] ?? 'Campus member').toString(),
      body: (m['body'] ?? '').toString(),
      createdAt: _dt(m['createdAt']),
    );
  }
}

class Group {
  Group({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.ownerId,
    required this.memberIds,
    required this.createdAt,
  });
  final String id, name, category, description, ownerId;
  final List<String> memberIds;
  final DateTime createdAt;
  int get members => memberIds.length;
  bool hasMember(String uid) => memberIds.contains(uid);
  factory Group.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return Group(
      id: d.id,
      name: (m['name'] ?? '').toString(),
      category: (m['category'] ?? 'Community').toString(),
      description: (m['description'] ?? '').toString(),
      ownerId: (m['ownerId'] ?? '').toString(),
      memberIds: _strs(m['memberIds']),
      createdAt: _dt(m['createdAt']),
    );
  }
}

class Conversation {
  Conversation({
    required this.id,
    required this.participants,
    required this.names,
    required this.lastMessage,
    required this.lastSenderId,
    required this.updatedAt,
  });
  final String id, lastMessage, lastSenderId;
  final List<String> participants;
  final Map<String, String> names;
  final DateTime updatedAt;
  String otherId(String me) => participants.firstWhere((p) => p != me, orElse: () => me);
  String otherName(String me) => names[otherId(me)] ?? 'Campus member';
  factory Conversation.fromDoc(Doc d) {
    final m = d.data() ?? {};
    final raw = m['names'];
    return Conversation(
      id: d.id,
      participants: _strs(m['participants']),
      names: raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v.toString())) : {},
      lastMessage: (m['lastMessage'] ?? '').toString(),
      lastSenderId: (m['lastSenderId'] ?? '').toString(),
      updatedAt: _dt(m['updatedAt']),
    );
  }
}

class Message {
  Message({required this.id, required this.senderId, required this.body, required this.createdAt, this.readAt});
  final String id, senderId, body;
  final DateTime createdAt;
  final DateTime? readAt;
  factory Message.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return Message(
      id: d.id,
      senderId: (m['senderId'] ?? '').toString(),
      body: (m['body'] ?? '').toString(),
      createdAt: _dt(m['createdAt']),
      readAt: _dtn(m['readAt']),
    );
  }
}

class StudyRoom {
  StudyRoom({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.topic,
    required this.startsAt,
    required this.location,
    required this.agenda,
    required this.memberIds,
  });
  final String id, ownerId, title, topic, location;
  final DateTime startsAt;
  final List<String> agenda, memberIds;
  int get members => memberIds.length;
  bool hasMember(String uid) => memberIds.contains(uid);
  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(startsAt.subtract(const Duration(minutes: 15))) &&
        now.isBefore(startsAt.add(const Duration(hours: 3)));
  }
  bool get isPast => DateTime.now().isAfter(startsAt.add(const Duration(hours: 3)));
  String get meetingUrl => 'https://meet.jit.si/CampusConnect-$id';
  factory StudyRoom.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return StudyRoom(
      id: d.id,
      ownerId: (m['ownerId'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      topic: (m['topic'] ?? '').toString(),
      startsAt: _dt(m['startsAt']),
      location: (m['location'] ?? '').toString(),
      agenda: _strs(m['agenda']),
      memberIds: _strs(m['memberIds']),
    );
  }
}

class SharedNote {
  SharedNote({required this.id, required this.authorId, required this.author, required this.title, required this.content, required this.updatedAt});
  final String id, authorId, author, title, content;
  final DateTime updatedAt;
  factory SharedNote.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return SharedNote(
      id: d.id,
      authorId: (m['authorId'] ?? '').toString(),
      author: (m['author'] ?? 'Campus member').toString(),
      title: (m['title'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      updatedAt: _dt(m['updatedAt']),
    );
  }
}

class AppNotification {
  AppNotification({required this.id, required this.kind, required this.body, this.targetId, this.fromUid, required this.createdAt, this.readAt});
  final String id, kind, body;
  final String? targetId, fromUid;
  final DateTime createdAt;
  final DateTime? readAt;
  bool get unread => readAt == null;
  factory AppNotification.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return AppNotification(
      id: d.id,
      kind: (m['kind'] ?? '').toString(),
      body: (m['body'] ?? '').toString(),
      targetId: m['targetId'] as String?,
      fromUid: m['fromUid'] as String?,
      createdAt: _dt(m['createdAt']),
      readAt: _dtn(m['readAt']),
    );
  }
}

class CampusEvent {
  CampusEvent({
    required this.id,
    required this.title,
    required this.organization,
    required this.organizationType,
    required this.category,
    required this.description,
    required this.startsAt,
    this.endsAt,
    required this.location,
    this.registrationUrl,
  });
  final String id, title, organization, organizationType, category, description, location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? registrationUrl;
  bool get isGovernment => organizationType == 'GOVERNMENT';
  factory CampusEvent.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return CampusEvent(
      id: d.id,
      title: (m['title'] ?? '').toString(),
      organization: (m['organizationName'] ?? '').toString(),
      organizationType: (m['organizationType'] ?? 'UNIVERSITY').toString(),
      category: (m['category'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      startsAt: _dt(m['startsAt']),
      endsAt: _dtn(m['endsAt']),
      location: (m['location'] ?? '').toString(),
      registrationUrl: m['registrationUrl'] as String?,
    );
  }
}

class Report {
  Report({required this.id, required this.reporterId, this.postId, required this.message, required this.status, required this.createdAt});
  final String id, reporterId, message, status;
  final String? postId;
  final DateTime createdAt;
  bool get isOpen => status == 'OPEN';
  factory Report.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return Report(
      id: d.id,
      reporterId: (m['reporterId'] ?? '').toString(),
      postId: m['postId'] as String?,
      message: (m['message'] ?? '').toString(),
      status: (m['status'] ?? 'OPEN').toString(),
      createdAt: _dt(m['createdAt']),
    );
  }
}
