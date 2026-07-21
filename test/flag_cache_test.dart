// test/flag_cache_test.dart
import 'package:test/test.dart';
import 'package:flagforge_flutter/src/flag_cache.dart';

void main() {
  group('FlagCache', () {
    test('isEnabled ritorna false per chiave sconosciuta', () {
      final cache = FlagCache();
      expect(cache.isEnabled('x'), isFalse);
    });

    test('replaceAll popola i valori', () {
      final cache = FlagCache();
      cache.replaceAll({'a': true, 'b': false});
      expect(cache.isEnabled('a'), isTrue);
      expect(cache.isEnabled('b'), isFalse);
    });

    test('replaceAll sostituisce lo stato precedente', () {
      final cache = FlagCache();
      cache.replaceAll({'a': true});
      cache.replaceAll({'b': true});
      expect(cache.isEnabled('a'), isFalse);
      expect(cache.isEnabled('b'), isTrue);
    });

    test('snapshot è una copia difensiva', () {
      final cache = FlagCache();
      cache.replaceAll({'a': true});
      cache.snapshot['a'] = false;
      expect(cache.isEnabled('a'), isTrue);
    });

    test('isEmpty riflette lo stato', () {
      final cache = FlagCache();
      expect(cache.isEmpty, isTrue);
      cache.replaceAll({'a': true});
      expect(cache.isEmpty, isFalse);
    });
  });
}
