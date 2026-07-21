import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

void main() {
  group('InMemoryFlagStore', () {
    test('read ritorna null prima di qualsiasi write', () async {
      final store = InMemoryFlagStore();
      expect(await store.read(), isNull);
    });

    test('read ritorna quanto scritto', () async {
      final store = InMemoryFlagStore();
      await store.write({'a': true, 'b': false});
      expect(await store.read(), equals({'a': true, 'b': false}));
    });

    test('read ritorna una copia difensiva', () async {
      final store = InMemoryFlagStore();
      await store.write({'a': true});
      final first = await store.read();
      first!['a'] = false;
      expect((await store.read())!['a'], isTrue);
    });

    test('clear azzera lo stato', () async {
      final store = InMemoryFlagStore();
      await store.write({'a': true});
      await store.clear();
      expect(await store.read(), isNull);
    });
  });
}
