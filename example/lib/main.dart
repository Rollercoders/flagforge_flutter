import 'package:flutter/material.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final FlagForgeClient _client;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _client = FlagForgeClient(
      const FlagForgeConfig(
        baseUrl: 'http://localhost:3000',
        apiKey: 'ff_xxxxxxxxxxxxxxxxxx',
        context: EvaluationContext(userId: 'user-123'),
      ),
    );
    _client.initialize().then((_) => setState(() => _ready = true));
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('FlagForge example')),
        body: Center(
          child: !_ready
              ? const CircularProgressIndicator()
              : ValueListenableBuilder<bool>(
                  valueListenable: _client.watch('new-checkout-flow'),
                  builder: (_, enabled, __) => Text(
                    enabled ? 'Nuovo checkout attivo' : 'Checkout classico',
                  ),
                ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            try {
              await _client.refresh();
            } catch (_) {
              // in un'app reale: mostra un messaggio all'utente
            }
          },
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
