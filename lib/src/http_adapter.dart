import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'exceptions.dart';

/// Abstraction over the HTTP transport used to fetch flags.
///
/// Implement this to plug in a custom client for testing or advanced needs.
abstract class HttpAdapter {
  /// Performs a POST and returns the decoded JSON map on success.
  ///
  /// Throws a [FlagForgeException] subtype on any failure.
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body, {
    Duration timeout,
  });
}

/// Default [HttpAdapter] backed by `package:http`.
class HttpAdapterImpl implements HttpAdapter {
  final http.Client _client;

  /// Creates a [HttpAdapterImpl]. An optional [client] can be injected.
  HttpAdapterImpl({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(url),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const FlagForgeNetworkException('Request timed out');
    } on SocketException catch (e) {
      throw FlagForgeNetworkException('Connection failed: ${e.message}');
    } on http.ClientException catch (e) {
      throw FlagForgeNetworkException('Network error: ${e.message}');
    }

    final code = response.statusCode;
    if (code == 401) {
      throw const FlagForgeAuthException('Missing or invalid API key');
    }
    if (code < 200 || code >= 300) {
      throw FlagForgeServerException(
        'Server error (${response.body})',
        code,
      );
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const FlagForgeParseException('Response is not valid JSON');
    }
  }
}
