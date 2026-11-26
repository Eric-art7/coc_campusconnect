import 'package:coc/core/format.dart';
import 'package:coc/core/models.dart';
import 'package:coc/core/theme.dart';
import 'package:coc/services/db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('initialsOf builds two-letter initials', () {
    expect(initialsOf('Eric Munezero'), 'EM');
    expect(initialsOf('  aline  '), 'A');
    expect(initialsOf(''), '?');
  });

  test('conversation id is the same for both people', () {
    expect(Db.convId('b', 'a'), Db.convId('a', 'b'));
    expect(Db.convId('a', 'b'), 'a_b');
  });

  test('Conversation knows who the other person is', () {
    final c = Conversation(
      id: 'a_b',
      participants: ['a', 'b'],
      names: {'a': 'Aline', 'b': 'Eric'},
      lastMessage: 'hi',
      lastSenderId: 'a',
      updatedAt: DateTime(2026, 1, 1),
    );
    expect(c.otherId('a'), 'b');
    expect(c.otherName('b'), 'Aline');
  });

  test('StudyRoom is live around its start time', () {
    StudyRoom room(DateTime at) => StudyRoom(
        id: 'r', ownerId: 'o', title: 't', topic: 'x', startsAt: at, location: 'l', agenda: const [], memberIds: const ['o']);
    expect(room(DateTime.now().add(const Duration(minutes: 5))).isLive, isTrue);
    expect(room(DateTime.now().add(const Duration(days: 2))).isLive, isFalse);
    expect(room(DateTime.now().subtract(const Duration(days: 1))).isPast, isTrue);
  });

  testWidgets('theme exposes the CampusConnect palette', (tester) async {
    late Pal pal;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light, true),
      home: Builder(builder: (context) {
        pal = context.pal;
        return const SizedBox();
      }),
    ));
    expect(pal.primary, const Color(0xFF5B49DF));
  });
}
