import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const Vision360App());
}

class Vision360App extends StatelessWidget {
  const Vision360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision360',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C4A6E)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  final TextEditingController _apiBaseController = TextEditingController(
    text: 'https://vision360-backend-276274707876.europe-west1.run.app/api',
  );

  final TextEditingController _nameController = TextEditingController(text: 'Utilisateur');
  final TextEditingController _allergiesController = TextEditingController(text: 'arachide');
  final TextEditingController _conditionsController = TextEditingController(text: 'diabete');
  final TextEditingController _preferencesController = TextEditingController(text: 'sans sucre');
  String _mobility = 'fauteuil';
  bool _ttsEnabled = true;

  final TextEditingController _imageB64Controller = TextEditingController();
  final TextEditingController _promptController = TextEditingController(
    text: 'Decris precisement les produits/objets visibles, marques ou categories.',
  );
  final TextEditingController _voiceController = TextEditingController();

  bool _isLoading = false;
  bool _listening = false;
  String _voiceStatus = '';
  CameraController? _cameraController;
  bool _cameraReady = false;
  String _cameraStatus = '';
  int _cooldownUntilMs = 0;
  Timer? _cooldownTicker;
  String _cooldownMsg = '';
  String _geminiText = '';
  String _groqJson = '';
  String _geminiRaw = '';
  String _groqRaw = '';

  final List<Map<String, String>> _history = [];

  Map<String, dynamic> _buildProfile() {
    return {
      'name': _nameController.text.trim(),
      'allergies': _splitList(_allergiesController.text),
      'conditions': _splitList(_conditionsController.text),
      'preferences': _splitList(_preferencesController.text),
      'mobility': _mobility,
      'tts_enabled': _ttsEnabled,
    };
  }

  List<String> _splitList(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _startCamera() async {
    if (_cameraReady) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraStatus = 'Aucune camera detectee.');
        return;
      }
      final camera = cameras.first;
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      setState(() {
        _cameraReady = true;
        _cameraStatus = 'Camera activee.';
      });
    } catch (exc) {
      setState(() => _cameraStatus = 'Erreur camera: $exc');
    }
  }

  Future<void> _stopCamera() async {
    await _cameraController?.dispose();
    _cameraController = null;
    setState(() {
      _cameraReady = false;
      _cameraStatus = 'Camera arretee.';
    });
  }

  Future<String?> _captureImage() async {
    if (_cameraController == null || !_cameraReady) return;
    try {
      final file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      setState(() => _imageB64Controller.text = b64);
      return b64;
    } catch (exc) {
      setState(() => _cameraStatus = 'Capture echouee: $exc');
      return null;
    }
  }

  Future<void> _callGemini() async {
    final apiBase = _apiBaseController.text.trim();
    if (apiBase.isEmpty) return;
    if (DateTime.now().millisecondsSinceEpoch < _cooldownUntilMs) {
      setState(() => _cooldownMsg = 'Attends 1 minute entre chaque envoi.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBase/describe/gemini'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image_b64': _imageB64Controller.text.trim(),
          'prompt': _promptController.text.trim(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final structured = decoded['structured'] as Map<String, dynamic>? ?? {};
      setState(() {
        _geminiText = (structured['text'] ?? '').toString();
        _cooldownUntilMs = DateTime.now().millisecondsSinceEpoch + 60000;
        _cooldownMsg = '';
      });
      _startCooldownTicker();
    } catch (exc) {
      setState(() => _geminiText = 'Erreur Gemini: $exc');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _callGroq() async {
    final apiBase = _apiBaseController.text.trim();
    final description = _voiceController.text.trim().isEmpty
        ? _geminiText.trim()
        : _voiceController.text.trim();

    if (apiBase.isEmpty || description.isEmpty) return;
    if (DateTime.now().millisecondsSinceEpoch < _cooldownUntilMs) {
      setState(() => _cooldownMsg = 'Attends 1 minute entre chaque envoi.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBase/describe/groq'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'description': description,
          'profile_override': _buildProfile(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final structured = decoded['structured'];
      final pretty = const JsonEncoder.withIndent('  ').convert(structured ?? decoded);
      setState(() {
        _groqJson = pretty;
        _cooldownUntilMs = DateTime.now().millisecondsSinceEpoch + 60000;
        _cooldownMsg = '';
      });
      _startCooldownTicker();
      _history.insert(0, {
        'summary': (structured?['summary'] ?? 'Conseil').toString(),
        'time': DateTime.now().toLocal().toString(),
      });
    } catch (exc) {
      setState(() => _groqJson = 'Erreur Groq: $exc');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _callChain({bool debug = false}) async {
    final apiBase = _apiBaseController.text.trim();
    if (apiBase.isEmpty) return;
    if (DateTime.now().millisecondsSinceEpoch < _cooldownUntilMs) {
      setState(() => _cooldownMsg = 'Attends 1 minute entre chaque envoi.');
      return;
    }

    final b64 = await _captureImage();
    if (b64 == null || b64.isEmpty) {
      setState(() => _geminiText = 'Aucune image a envoyer.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final geminiResponse = await http.post(
        Uri.parse('$apiBase/describe/gemini'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image_b64': b64,
          'prompt': _promptController.text.trim(),
        }),
      );

      if (geminiResponse.statusCode != 200) {
        throw Exception(geminiResponse.body);
      }

      final geminiDecoded = jsonDecode(geminiResponse.body) as Map<String, dynamic>;
      final structuredGemini = geminiDecoded['structured'] as Map<String, dynamic>? ?? {};
      final geminiTextValue = (structuredGemini['text'] ?? '').toString();
      setState(() {
        _geminiText = geminiTextValue;
        if (debug) {
          _geminiRaw = const JsonEncoder.withIndent('  ').convert(geminiDecoded);
        }
      });

      final groqResponse = await http.post(
        Uri.parse('$apiBase/describe/groq'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'description': geminiTextValue,
          'profile_override': _buildProfile(),
        }),
      );

      if (groqResponse.statusCode != 200) {
        throw Exception(groqResponse.body);
      }

      final groqDecoded = jsonDecode(groqResponse.body) as Map<String, dynamic>;
      final structured = groqDecoded['structured'];
      final pretty = const JsonEncoder.withIndent('  ').convert(structured ?? groqDecoded);

      setState(() {
        _groqJson = pretty;
        if (debug) {
          _groqRaw = const JsonEncoder.withIndent('  ').convert(groqDecoded);
        }
        _cooldownUntilMs = DateTime.now().millisecondsSinceEpoch + 60000;
        _cooldownMsg = '';
      });
      _startCooldownTicker();
      _history.insert(0, {
        'summary': (structured?['summary'] ?? 'Conseil').toString(),
        'time': DateTime.now().toLocal().toString(),
      });
    } catch (exc) {
      setState(() {
        _groqJson = 'Erreur chaine: $exc';
        if (debug) {
          _geminiRaw = '';
          _groqRaw = '';
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (DateTime.now().millisecondsSinceEpoch >= _cooldownUntilMs) {
        timer.cancel();
        setState(() => _cooldownMsg = '');
      } else {
        final seconds = ((_cooldownUntilMs - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
        setState(() => _cooldownMsg = 'Attends $seconds s avant un nouvel envoi.');
      }
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildProfileTab(),
      _buildGuidanceTab(),
      _buildHistoryTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision360'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
          NavigationDestination(icon: Icon(Icons.visibility), label: 'Guidance'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historique'),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Configuration API'),
        TextField(
          controller: _apiBaseController,
          decoration: const InputDecoration(labelText: 'Base API (Cloud Run)'),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Profil utilisateur'),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        TextField(
          controller: _allergiesController,
          decoration: const InputDecoration(labelText: 'Allergies (separees par virgules)'),
        ),
        TextField(
          controller: _conditionsController,
          decoration: const InputDecoration(labelText: 'Conditions (separees par virgules)'),
        ),
        TextField(
          controller: _preferencesController,
          decoration: const InputDecoration(labelText: 'Preferences (separees par virgules)'),
        ),
        DropdownButtonFormField<String>(
          value: _mobility,
          items: const [
            DropdownMenuItem(value: 'fauteuil', child: Text('Fauteuil')),
            DropdownMenuItem(value: 'canne', child: Text('Canne')),
            DropdownMenuItem(value: 'marche', child: Text('Marche')),
          ],
          onChanged: (value) => setState(() => _mobility = value ?? _mobility),
          decoration: const InputDecoration(labelText: 'Mobilite'),
        ),
        SwitchListTile(
          title: const Text('TTS actif (sortie Groq)'),
          value: _ttsEnabled,
          onChanged: (value) => setState(() => _ttsEnabled = value),
        ),
      ],
    );
  }

  Widget _buildGuidanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Capture / Description'),
        if (_cameraReady && _cameraController != null)
          AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          )
        else
          const SizedBox(
            height: 200,
            child: Center(child: Text('Camera non activee')),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!_cameraReady)
              ElevatedButton.icon(
                onPressed: _startCamera,
                icon: const Icon(Icons.videocam),
                label: const Text('Activer camera'),
              )
            else
              ElevatedButton.icon(
                onPressed: _stopCamera,
                icon: const Icon(Icons.stop),
                label: const Text('Arreter camera'),
              ),
            ElevatedButton.icon(
              onPressed: _cameraReady ? () => _captureImage() : null,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capturer'),
            ),
            ElevatedButton.icon(
              onPressed: _cameraReady ? () => _callChain(debug: false) : null,
              icon: const Icon(Icons.bolt),
              label: const Text('Envoyer (Recommandations)'),
            ),
            ElevatedButton.icon(
              onPressed: _cameraReady ? () => _callChain(debug: true) : null,
              icon: const Icon(Icons.bug_report),
              label: const Text('Envoyer (Debug)'),
            ),
          ],
        ),
        if (_cooldownMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_cooldownMsg),
          ),
        if (_cameraStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_cameraStatus),
          ),
        TextField(
          controller: _imageB64Controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Image base64',
            hintText: 'Colle une image encodée (data:image/... ou base64 brute)',
          ),
        ),
        TextField(
          controller: _promptController,
          decoration: const InputDecoration(labelText: 'Prompt Gemini'),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        _sectionTitle('Commande vocale / texte'),
        TextField(
          controller: _voiceController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Commande vocale (texte)',
            hintText: 'Tu peux saisir un prompt vocal ici',
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _listening = !_listening;
              _voiceStatus = _listening
                  ? 'Ecoute activee (integration micro a faire).'
                  : 'Ecoute arretee.';
            });
          },
          icon: const Icon(Icons.mic),
          label: Text(_listening ? 'Arreter l\'ecoute' : 'Activer l\'ecoute'),
        ),
        if (_voiceStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_voiceStatus),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _callGroq,
          icon: const Icon(Icons.record_voice_over),
          label: const Text('Envoyer a Groq'),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Sorties'),
        _infoCard('Gemini', _geminiText),
        _infoCard('Groq (JSON)', _groqJson),
        if (_geminiRaw.isNotEmpty) _infoCard('Gemini raw', _geminiRaw),
        if (_groqRaw.isNotEmpty) _infoCard('Groq raw', _groqRaw),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return const Center(child: Text('Aucun historique pour le moment.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return Card(
          child: ListTile(
            title: Text(item['summary'] ?? 'Conseil'),
            subtitle: Text(item['time'] ?? ''),
            leading: const Icon(Icons.lightbulb),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoCard(String title, String content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(content.isEmpty ? '—' : content),
          ],
        ),
      ),
    );
  }
}
