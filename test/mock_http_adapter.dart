import 'package:flagforge_flutter/flagforge_flutter.dart';

class MockHttpAdapter implements HttpAdapter {
  Map<String, dynamic>? _response;
  Object? _error;
  int callCount = 0;
  String? lastUrl;
  Map<String, String>? lastHeaders;
  Map<String, dynamic>? lastBody;

  void setResponse(Map<String, dynamic> response) {
    _response = response;
    _error = null;
  }

  void setError(Object error) {
    _error = error;
    _response = null;
  }

  @override
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    callCount++;
    lastUrl = url;
    lastHeaders = headers;
    lastBody = body;
    if (_error != null) throw _error!;
    if (_response != null) return _response!;
    throw StateError('MockHttpAdapter: nessuna risposta configurata');
  }
}
