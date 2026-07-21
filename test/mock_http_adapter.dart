import 'package:flagforge_flutter/flagforge_flutter.dart';

class MockHttpAdapter implements HttpAdapter {
  Map<String, dynamic>? _response;
  Exception? _error;
  int callCount = 0;
  Map<String, dynamic>? lastBody;

  void setResponse(Map<String, dynamic> response) {
    _response = response;
    _error = null;
  }

  void setError(Exception error) {
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
    lastBody = body;
    if (_error != null) throw _error!;
    if (_response != null) return _response!;
    throw StateError('MockHttpAdapter: nessuna risposta configurata');
  }
}
