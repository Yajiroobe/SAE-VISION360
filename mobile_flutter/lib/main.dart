/// Application mobile Vision360 - Assistance IA pour PMR
///
/// Cette application Flutter fournit une interface mobile pour le système
/// Vision360 d'assistance aux personnes à mobilité réduite. Elle permet :
/// - La capture d'images via la caméra du téléphone
/// - L'envoi à l'API pour analyse (Gemini) et recommandations (Groq)
/// - La lecture vocale des recommandations (TTS)
/// - La gestion du profil utilisateur (allergies, mobilité, préférences)
///
/// Architecture :
/// - Vision360App : Widget racine MaterialApp
/// - HomeScreen : Écran principal avec navigation par onglets
/// - Onglets : Profil, Guidance (caméra), Historique

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Point d'entrée de l'application
void main() {
  runApp(const Vision360App());
}

/// Widget racine de l'application Vision360.
///
/// Configure le thème Material 3 avec une palette de couleurs accessibles
/// et lance l'écran principal [HomeScreen].
class Vision360App extends StatelessWidget {
  const Vision360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision360',
      theme: ThemeData(
        // Couleur principale bleu foncé pour bon contraste
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C4A6E)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Écran principal de l'application avec navigation par onglets.
///
/// Gère l'état global de l'application incluant :
/// - Authentification utilisateur (mock local)
/// - Configuration API et profil utilisateur
/// - Capture caméra et appels API
/// - Synthèse vocale des recommandations
/// - Historique des interactions
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ---------------------------------------------------------------------------
  // État de l'interface
  // ---------------------------------------------------------------------------

  /// Index de l'onglet actif (0: Profil, 1: Guidance, 2: Historique)
  int _tabIndex = 0;

  /// Indique si l'application est en cours de chargement initial
  bool _loadingApp = true;

  // ---------------------------------------------------------------------------
  // Contrôleurs de formulaire - Configuration API
  // ---------------------------------------------------------------------------

  /// URL de base de l'API Vision360 (Cloud Run par défaut)
  final TextEditingController _apiBaseController = TextEditingController(
    text: 'https://vision360-backend-276274707876.europe-west1.run.app/api',
  );

  // ---------------------------------------------------------------------------
  // Contrôleurs de formulaire - Profil utilisateur
  // ---------------------------------------------------------------------------

  final TextEditingController _nameController =
      TextEditingController(text: 'Utilisateur');
  final TextEditingController _allergiesController =
      TextEditingController(text: 'arachide');
  final TextEditingController _conditionsController =
      TextEditingController(text: 'diabete');
  final TextEditingController _preferencesController =
      TextEditingController(text: 'sans sucre');

  /// Type de mobilité (fauteuil, canne, marche)
  String _mobility = 'fauteuil';

  /// Activation de la synthèse vocale
  bool _ttsEnabled = true;

  // ---------------------------------------------------------------------------
  // Contrôleurs de formulaire - Capture et commandes
  // ---------------------------------------------------------------------------

  /// Image capturée encodée en base64
  final TextEditingController _imageB64Controller = TextEditingController();

  /// Prompt envoyé à Gemini pour l'analyse d'image
  final TextEditingController _promptController = TextEditingController(
    text:
        'Decris precisement les produits/objets visibles, marques ou categories.',
  );

  /// Commande vocale saisie manuellement
  final TextEditingController _voiceController = TextEditingController();

  // ---------------------------------------------------------------------------
  // Contrôleurs de formulaire - Authentification
  // ---------------------------------------------------------------------------

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // ---------------------------------------------------------------------------
  // État d'authentification
  // ---------------------------------------------------------------------------

  bool _isAuthenticated = false;
  bool _registerMode = false;
  String _currentUserEmail = '';
  String _authMessage = '';

  // ---------------------------------------------------------------------------
  // État de chargement et caméra
  // ---------------------------------------------------------------------------

  /// Indique si une requête API est en cours
  bool _isLoading = false;

  /// Indique si l'écoute vocale est active
  bool _listening = false;
  String _voiceStatus = '';

  /// Contrôleur de caméra Flutter
  CameraController? _cameraController;
  bool _cameraReady = false;
  String _cameraStatus = '';

  // ---------------------------------------------------------------------------
  // Gestion du cooldown entre appels API
  // ---------------------------------------------------------------------------

  /// Timestamp jusqu'auquel les appels sont bloqués
  int _cooldownUntilMs = 0;
  Timer? _cooldownTicker;
  String _cooldownMsg = '';

  // ---------------------------------------------------------------------------
  // Résultats des appels API
  // ---------------------------------------------------------------------------

  String _geminiText = '';
  String _groqJson = '';
  String _geminiRaw = '';
  String _groqRaw = '';
  Map<String, dynamic>? _groqStructured;

  // ---------------------------------------------------------------------------
  // Historique et TTS
  // ---------------------------------------------------------------------------

  /// Historique des interactions (summary + timestamp)
  final List<Map<String, String>> _history = [];

  /// Instance Flutter TTS pour la synthèse vocale
  final FlutterTts _tts = FlutterTts();

  // ---------------------------------------------------------------------------
  // Clés de stockage SharedPreferences
  // ---------------------------------------------------------------------------

  static const String _usersKey = 'vision360_users';
  static const String _sessionKey = 'vision360_session';
  static const String _apiBaseKey = 'vision360_api_base';

  // ---------------------------------------------------------------------------
  // Cycle de vie
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _initTts();
  }

  /// Initialise le moteur de synthèse vocale.
  ///
  /// Configure la langue française et les paramètres de débit/tonalité.
  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.45); // Débit modéré pour meilleure compréhension
      await _tts.setPitch(1.0);
    } catch (_) {
      // Ignore les erreurs TTS; l'app fonctionne sans audio
    }
  }

  /// Initialise l'application au démarrage.
  ///
  /// Charge la configuration API sauvegardée et restaure la session
  /// utilisateur si une connexion précédente existe.
  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();

    // Restaurer l'URL API si sauvegardée
    final savedApi = prefs.getString(_apiBaseKey);
    if (savedApi != null && savedApi.isNotEmpty) {
      _apiBaseController.text = savedApi;
    }

    // Restaurer la session utilisateur
    final sessionEmail = prefs.getString(_sessionKey);
    if (sessionEmail != null && sessionEmail.isNotEmpty) {
      _currentUserEmail = sessionEmail;
      _isAuthenticated = true;
      await _loadUserData();
    }

    if (mounted) {
      setState(() => _loadingApp = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Gestion des clés de stockage par utilisateur
  // ---------------------------------------------------------------------------

  /// Clé de stockage du profil pour l'utilisateur courant
  String _profileKey() => 'vision360_profile_$_currentUserEmail';

  /// Clé de stockage de l'historique pour l'utilisateur courant
  String _historyKey() => 'vision360_history_$_currentUserEmail';

  // ---------------------------------------------------------------------------
  // Gestion du profil utilisateur
  // ---------------------------------------------------------------------------

  /// Construit un objet profil depuis les champs du formulaire.
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

  /// Divise une chaîne séparée par virgules en liste.
  List<String> _splitList(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Authentification (mock local)
  // ---------------------------------------------------------------------------

  /// Charge les utilisateurs enregistrés depuis SharedPreferences.
  Future<Map<String, String>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  /// Sauvegarde les utilisateurs dans SharedPreferences.
  Future<void> _saveUsers(Map<String, String> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  /// Sauvegarde l'email de session courante.
  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, _currentUserEmail);
  }

  /// Supprime la session courante (déconnexion).
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  /// Sauvegarde l'URL de base de l'API.
  Future<void> _saveApiBase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseKey, _apiBaseController.text.trim());
  }

  /// Sauvegarde le profil utilisateur courant.
  Future<void> _saveProfile() async {
    if (_currentUserEmail.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(), jsonEncode(_buildProfile()));
  }

  /// Sauvegarde l'historique des interactions.
  Future<void> _saveHistory() async {
    if (_currentUserEmail.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey(), jsonEncode(_history));
  }

  /// Charge les données utilisateur (profil + historique).
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    // Charger le profil
    final profileRaw = prefs.getString(_profileKey());
    if (profileRaw != null && profileRaw.isNotEmpty) {
      final profile = jsonDecode(profileRaw) as Map<String, dynamic>;
      _nameController.text = (profile['name'] ?? '').toString();
      _allergiesController.text =
          ((profile['allergies'] as List<dynamic>? ?? [])).join(', ');
      _conditionsController.text =
          ((profile['conditions'] as List<dynamic>? ?? [])).join(', ');
      _preferencesController.text =
          ((profile['preferences'] as List<dynamic>? ?? [])).join(', ');
      _mobility = (profile['mobility'] ?? 'fauteuil').toString();
      _ttsEnabled = profile['tts_enabled'] == true;
    }

    // Charger l'historique
    final historyRaw = prefs.getString(_historyKey());
    _history.clear();
    if (historyRaw != null && historyRaw.isNotEmpty) {
      final list = jsonDecode(historyRaw) as List<dynamic>;
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          _history.add({
            'summary': (item['summary'] ?? '').toString(),
            'time': (item['time'] ?? '').toString(),
          });
        }
      }
    }
  }

  /// Gère la connexion ou l'inscription selon le mode actif.
  Future<void> _handleAuth() async {
    final email = _emailController.text.trim().toLowerCase();
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _authMessage = 'Email et mot de passe obligatoires.');
      return;
    }

    final users = await _loadUsers();

    // Mode inscription
    if (_registerMode) {
      if (pass != confirm) {
        setState(
            () => _authMessage = 'Les mots de passe ne correspondent pas.');
        return;
      }
      if (users.containsKey(email)) {
        setState(() => _authMessage = 'Ce compte existe deja.');
        return;
      }
      users[email] = pass;
      await _saveUsers(users);
      setState(() {
        _authMessage = 'Inscription reussie. Connecte-toi.';
        _registerMode = false;
      });
      return;
    }

    // Mode connexion
    if (!users.containsKey(email) || users[email] != pass) {
      setState(() => _authMessage = 'Identifiants invalides.');
      return;
    }

    _currentUserEmail = email;
    await _saveSession();
    await _loadUserData();
    setState(() {
      _isAuthenticated = true;
      _authMessage = '';
    });
  }

  /// Déconnecte l'utilisateur courant.
  Future<void> _logout() async {
    await _clearSession();
    setState(() {
      _isAuthenticated = false;
      _currentUserEmail = '';
      _tabIndex = 0;
    });
  }

  // ---------------------------------------------------------------------------
  // Gestion de la caméra
  // ---------------------------------------------------------------------------

  /// Démarre la caméra et initialise le contrôleur.
  Future<void> _startCamera() async {
    if (_cameraReady) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraStatus = 'Aucune camera detectee.');
        return;
      }
      // Utilise la première caméra disponible (généralement arrière)
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

  /// Arrête la caméra et libère les ressources.
  Future<void> _stopCamera() async {
    await _cameraController?.dispose();
    _cameraController = null;
    setState(() {
      _cameraReady = false;
      _cameraStatus = 'Camera arretee.';
    });
  }

  /// Capture une image et la convertit en base64.
  ///
  /// Returns:
  ///   String base64 de l'image, ou null en cas d'erreur
  Future<String?> _captureImage() async {
    if (_cameraController == null || !_cameraReady) return null;
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

  // ---------------------------------------------------------------------------
  // Appels API
  // ---------------------------------------------------------------------------

  /// Appelle l'endpoint Groq avec une description textuelle.
  ///
  /// Envoie la description et le profil utilisateur pour obtenir
  /// des recommandations personnalisées.
  Future<void> _callGroqWithDescription(String description) async {
    final apiBase = _apiBaseController.text.trim();
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

    final groqDecoded = jsonDecode(response.body) as Map<String, dynamic>;
    final structured = groqDecoded['structured'];
    final pretty =
        const JsonEncoder.withIndent('  ').convert(structured ?? groqDecoded);

    setState(() {
      _groqJson = pretty;
      _groqStructured =
          structured is Map<String, dynamic> ? structured : null;
      // Activer le cooldown de 60 secondes
      _cooldownUntilMs = DateTime.now().millisecondsSinceEpoch + 60000;
      _cooldownMsg = '';
    });
    _startCooldownTicker();

    // Ajouter à l'historique
    _history.insert(0, {
      'summary': (structured?['summary'] ?? 'Conseil').toString(),
      'time': DateTime.now().toLocal().toString(),
    });
    await _saveHistory();

  }

  /// Formate une liste pour l'affichage TTS.
  String _formatList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).join(', ');
    }
    if (value == null) return '';
    return value.toString();
  }

  /// Lit les recommandations Groq via synthèse vocale.
  ///
  /// Construit un texte à partir du summary, risks et actions
  /// et le lit via le moteur TTS.
  Future<void> _speakGroq(dynamic structured) async {
    if (!_ttsEnabled) return;
    if (structured is! Map) return;

    final summary = structured['summary']?.toString() ?? '';
    final risks = _formatList(structured['risks']);
    final actions = _formatList(structured['actions']);

    final buffer = StringBuffer();
    if (summary.isNotEmpty) buffer.writeln('Synthese. $summary');
    if (risks.isNotEmpty) buffer.writeln('Risques. $risks.');
    if (actions.isNotEmpty) buffer.writeln('Actions. $actions.');

    final text = buffer.toString().trim();
    if (text.isEmpty) return;

    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Ignore les erreurs TTS pour garder l'UI responsive
    }
  }

  /// Exécute la chaîne complète : capture → Gemini → Groq → TTS.
  ///
  /// [debug] : Si true, affiche les réponses brutes des APIs
  Future<void> _callChain({bool debug = false}) async {
    final apiBase = _apiBaseController.text.trim();
    if (apiBase.isEmpty) return;

    // Vérifier le cooldown
    if (DateTime.now().millisecondsSinceEpoch < _cooldownUntilMs) {
      setState(() => _cooldownMsg = 'Attends 1 minute entre chaque envoi.');
      return;
    }

    await _saveApiBase();
    await _saveProfile();

    // Capturer l'image
    final b64 = await _captureImage();
    if (b64 == null || b64.isEmpty) {
      setState(() => _geminiText = 'Aucune image a envoyer.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Appel Gemini pour analyse d'image
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

      final geminiDecoded =
          jsonDecode(geminiResponse.body) as Map<String, dynamic>;
      final structuredGemini =
          geminiDecoded['structured'] as Map<String, dynamic>? ?? {};
      final geminiTextValue = (structuredGemini['text'] ?? '').toString();
      setState(() {
        _geminiText = geminiTextValue;
        if (debug) {
          _geminiRaw =
              const JsonEncoder.withIndent('  ').convert(geminiDecoded);
        }
      });

      // Appel Groq pour recommandations
      await _callGroqWithDescription(geminiTextValue);
      if (debug) {
        final groqDecoded = jsonDecode(_groqJson.isNotEmpty ? _groqJson : '{}');
        _groqRaw = const JsonEncoder.withIndent('  ').convert(groqDecoded);
      }
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

  /// Appelle Groq manuellement avec le texte saisi ou la description Gemini.
  Future<void> _callGroqManual() async {
    final description = _voiceController.text.trim().isEmpty
        ? _geminiText.trim()
        : _voiceController.text.trim();
    if (description.isEmpty) return;

    // Vérifier le cooldown
    if (DateTime.now().millisecondsSinceEpoch < _cooldownUntilMs) {
      setState(() => _cooldownMsg = 'Attends 1 minute entre chaque envoi.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _callGroqWithDescription(description);
    } catch (exc) {
      setState(() => _groqJson = 'Erreur Groq: $exc');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Démarre le timer de cooldown pour affichage du compte à rebours.
  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (DateTime.now().millisecondsSinceEpoch >= _cooldownUntilMs) {
        timer.cancel();
        setState(() => _cooldownMsg = '');
      } else {
        final seconds =
            ((_cooldownUntilMs - DateTime.now().millisecondsSinceEpoch) / 1000)
                .ceil();
        setState(
            () => _cooldownMsg = 'Attends $seconds s avant un nouvel envoi.');
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Export de l'historique
  // ---------------------------------------------------------------------------

  /// Exporte l'historique vers un fichier JSON.
  Future<void> _exportHistoryToFile() async {
    final jsonData = const JsonEncoder.withIndent('  ').convert(_history);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/vision360_history_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(jsonData);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Historique exporte: ${file.path}')),
    );
  }

  /// Copie l'historique dans le presse-papiers.
  Future<void> _copyHistoryToClipboard() async {
    final jsonData = const JsonEncoder.withIndent('  ').convert(_history);
    await Clipboard.setData(ClipboardData(text: jsonData));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Historique copie dans le presse-papiers.')),
    );
  }

  // ---------------------------------------------------------------------------
  // Nettoyage des ressources
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _cameraController?.dispose();
    _tts.stop();
    _apiBaseController.dispose();
    _nameController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _preferencesController.dispose();
    _imageB64Controller.dispose();
    _promptController.dispose();
    _voiceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Construction de l'interface
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Afficher un loader pendant l'initialisation
    if (_loadingApp) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Afficher l'écran de connexion si non authentifié
    if (!_isAuthenticated) {
      return _buildAuthScreen();
    }

    // Pages des onglets
    final pages = <Widget>[
      _buildProfileTab(),
      _buildGuidanceTab(),
      _buildHistoryTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Vision360 (${_currentUserEmail.isEmpty ? 'guest' : _currentUserEmail})'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
          NavigationDestination(
              icon: Icon(Icons.visibility), label: 'Guidance'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historique'),
        ],
      ),
    );
  }

  /// Construit l'écran d'authentification (connexion/inscription).
  Widget _buildAuthScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion Vision360')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _registerMode
                ? 'Inscription (mock local)'
                : 'Connexion (mock local)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
          ),
          if (_registerMode)
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirmer mot de passe'),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleAuth,
            child: Text(_registerMode ? 'S inscrire' : 'Se connecter'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _registerMode = !_registerMode;
              _authMessage = '';
            }),
            child: Text(
              _registerMode ? 'J ai deja un compte' : 'Creer un compte',
            ),
          ),
          if (_authMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child:
                  Text(_authMessage, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  /// Construit l'onglet de configuration du profil.
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Configuration API'),
        TextField(
          controller: _apiBaseController,
          decoration: const InputDecoration(labelText: 'Base API (Cloud Run)'),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Profil utilisateur'),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        TextField(
          controller: _allergiesController,
          decoration: const InputDecoration(labelText: 'Allergies (virgules)'),
        ),
        TextField(
          controller: _conditionsController,
          decoration: const InputDecoration(labelText: 'Conditions (virgules)'),
        ),
        TextField(
          controller: _preferencesController,
          decoration:
              const InputDecoration(labelText: 'Preferences (virgules)'),
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
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                await _saveApiBase();
                await _saveProfile();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil sauvegarde en local.')),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('Sauvegarder'),
            ),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Se deconnecter'),
            ),
          ],
        ),
      ],
    );
  }

  /// Construit l'onglet de guidage avec caméra et appels API.
  Widget _buildGuidanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Capture / Description'),
        // Prévisualisation caméra
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
        // Boutons de contrôle caméra
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
        // Messages de statut
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
        // Champs debug
        TextField(
          controller: _imageB64Controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Image base64 (debug)'),
        ),
        TextField(
          controller: _promptController,
          decoration: const InputDecoration(labelText: 'Prompt Gemini'),
        ),
        const SizedBox(height: 12),
        // Section commande vocale
        _sectionTitle('Commande vocale / texte'),
        TextField(
          controller: _voiceController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Commande vocale (texte)',
            hintText: 'Entree manuelle en attendant micro natif',
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _listening = !_listening;
              _voiceStatus = _listening
                  ? 'Ecoute activee (integration micro natif a faire).'
                  : 'Ecoute arretee.';
            });
          },
          icon: const Icon(Icons.mic),
          label: Text(_listening ? 'Arreter l ecoute' : 'Activer l ecoute'),
        ),
        if (_voiceStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_voiceStatus),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _callGroqManual,
          icon: const Icon(Icons.record_voice_over),
          label: const Text('Envoyer a Groq (manuel)'),
        ),
        const SizedBox(height: 12),
        // Section résultats
        _sectionTitle('Sorties'),
        _infoCard('Gemini', _geminiText),
        _infoCard(
          'Groq (JSON)',
          _groqJson,
          footer: Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _ttsEnabled && _groqStructured != null
                    ? () => _speakGroq(_groqStructured)
                    : null,
                icon: const Icon(Icons.volume_up),
                label: const Text('Lire TTS'),
              ),
              OutlinedButton.icon(
                onPressed: () => _tts.stop(),
                icon: const Icon(Icons.stop),
                label: const Text('Stop TTS'),
              ),
            ],
          ),
        ),
        if (_geminiRaw.isNotEmpty) _infoCard('Gemini raw', _geminiRaw),
        if (_groqRaw.isNotEmpty) _infoCard('Groq raw', _groqRaw),
      ],
    );
  }

  /// Construit l'onglet d'historique des interactions.
  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Historique persistant'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _copyHistoryToClipboard,
              icon: const Icon(Icons.copy),
              label: const Text('Copier JSON'),
            ),
            ElevatedButton.icon(
              onPressed: _exportHistoryToFile,
              icon: const Icon(Icons.download),
              label: const Text('Exporter fichier'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                setState(() => _history.clear());
                await _saveHistory();
              },
              icon: const Icon(Icons.delete),
              label: const Text('Vider'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          const Text('Aucun historique pour le moment.')
        else
          ..._history.map(
            (item) => Card(
              child: ListTile(
                title: Text(item['summary'] ?? 'Conseil'),
                subtitle: Text(item['time'] ?? ''),
                leading: const Icon(Icons.lightbulb),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets utilitaires
  // ---------------------------------------------------------------------------

  /// Crée un titre de section stylisé.
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Crée une carte d'information avec titre et contenu.
  Widget _infoCard(String title, String content, {Widget? footer}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(content.isEmpty ? '-' : content),
            if (footer != null) ...[
              const SizedBox(height: 12),
              footer,
            ],
          ],
        ),
      ),
    );
  }
}
