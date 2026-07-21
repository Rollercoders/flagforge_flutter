import 'dart:convert';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';
import 'package:flagforge_flutter/src/http_adapter.dart';

HttpAdapterImpl adapterReturning(http.Response response) {
  return HttpAdapterImpl(
    client: MockClient((req) async => response),
  );
}

void main() {
  const url = 'http://localhost:3000/api/evaluate/all';
  const headers = {'Authorization': 'Bearer ff_test'};

  test('ritorna la mappa decodificata sul 200', () async {
    final adapter = adapterReturning(
      http.Response(jsonEncode({'a': true}), 200),
    );
    final result = await adapter.post(url, headers, {});
    expect(result, equals({'a': true}));
  });

  test('invia header e body corretti', () async {
    late http.Request captured;
    final adapter = HttpAdapterImpl(
      client: MockClient((req) async {
        captured = req;
        return http.Response('{}', 200);
      }),
    );
    await adapter.post(url, headers, {'userId': 'u1'});
    expect(captured.headers['Authorization'], 'Bearer ff_test');
    expect(captured.headers['Content-Type'], contains('application/json'));
    expect(jsonDecode(captured.body), equals({'userId': 'u1'}));
  });

  test('401 lancia FlagForgeAuthException', () async {
    final adapter = adapterReturning(
      http.Response(jsonEncode({'error': 'Unauthorized'}), 401),
    );
    await expectLater(
      adapter.post(url, headers, {}),
      throwsA(isA<FlagForgeAuthException>()),
    );
  });

  test('500 lancia FlagForgeServerException con status code', () async {
    final adapter = adapterReturning(http.Response('boom', 500));
    await expectLater(
      adapter.post(url, headers, {}),
      throwsA(isA<FlagForgeServerException>()
          .having((e) => e.statusCode, 'statusCode', 500)),
    );
  });

  test('errore di trasporto lancia FlagForgeNetworkException', () async {
    final adapter = HttpAdapterImpl(
      client: MockClient((req) async => throw http.ClientException('down')),
    );
    await expectLater(
      adapter.post(url, headers, {}),
      throwsA(isA<FlagForgeNetworkException>()),
    );
  });

  test('body non-JSON sul 200 lancia FlagForgeParseException', () async {
    final adapter = adapterReturning(http.Response('non-json', 200));
    await expectLater(
      adapter.post(url, headers, {}),
      throwsA(isA<FlagForgeParseException>()),
    );
  });
}
