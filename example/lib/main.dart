import 'package:flutter/material.dart';
import 'package:customfit_ai_flutter_sdk/customfit_ai_flutter_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CustomFit.ai SDK Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'CustomFit.ai Flutter SDK Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CFClient? _client;
  bool _isInitialized = false;
  String _flagValue = 'Not evaluated';
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initializeSDK();
  }

  Future<void> _initializeSDK() async {
    try {
      // Initialize the CustomFit.ai SDK
      final config = CFConfig.development(
          'your-api-key-here'); // Replace with your actual API key

      final user = CFUser.builder('example-user-123')
          .addStringProperty('name', 'Example User')
          .addStringProperty('email', 'user@example.com')
          .addStringProperty('plan', 'premium')
          .addStringProperty('region', 'us-east')
          .build();

      _client = await CFClient.initialize(config, user);

      setState(() {
        _isInitialized = true;
        _status = 'SDK Initialized Successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _evaluateFlag() async {
    if (_client == null) return;

    try {
      // Evaluate a feature flag
      final result = _client!.featureFlags.getBoolean('example-flag', false);

      setState(() {
        _flagValue = result.toString();
      });

      // Track an event
      await _client!.trackEvent('flag_evaluated', properties: {
        'flag_key': 'example-flag',
        'result': result,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      setState(() {
        _flagValue = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    // CFClient cleanup is handled automatically
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SDK Status',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.error,
                          color: _isInitialized ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(_isInitialized ? 'Ready' : 'Not Ready'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Feature Flag Evaluation',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Flag Value: $_flagValue'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isInitialized ? _evaluateFlag : null,
                      child: const Text('Evaluate Flag'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Getting Started',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Replace "your-api-key-here" with your actual API key\n'
                      '2. Update the base URL to match your CustomFit.ai instance\n'
                      '3. Create feature flags in your CustomFit.ai dashboard\n'
                      '4. Update the flag key "example-flag" to match your flags',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
