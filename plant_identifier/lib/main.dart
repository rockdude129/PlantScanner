import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  runApp(const PlantCheckerApp());
}

class PlantCheckerApp extends StatelessWidget {
  const PlantCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Checker AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          primary: const Color(0xFF1B5E20),
          secondary: const Color(0xFF81C784),
          background: const Color(0xFFF5F7FA),
          surface: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const PlantCheckerHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PlantCheckerHomePage extends StatefulWidget {
  const PlantCheckerHomePage({super.key});

  @override
  State<PlantCheckerHomePage> createState() => _PlantCheckerHomePageState();
}

class _PlantCheckerHomePageState extends State<PlantCheckerHomePage> with SingleTickerProviderStateMixin {
  File? _image;
  bool _loading = false;
  String? _result;
  String? _geminiSummary;
  bool _geminiLoading = false;
  String? _geminiError;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Gemini API key
  final String _geminiApiKey = 'AIzaSyAzEyJ40mUAKferC_PFLMs2DSiuvXVA3wg';

  // Gemini summary fetcher
  Future<String?> _fetchGeminiSummary(String plantName) async {
    setState(() {
      _geminiLoading = true;
      _geminiError = null;
    });
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _geminiApiKey,
    );
    final prompt =
      'Give me a short, friendly, and helpful summary about the plant "$plantName" and how it can be cared for. Make it concise, clear, and easy to understand. Add titles and subtitles and make it properly formatted no bold, just spaces.';
    try {
      final content = await model.generateContent([Content.text(prompt)]);
      setState(() {
        _geminiLoading = false;
      });
      return content.text;
    } catch (e) {
      print('Gemini API error: '
          + e.toString());
      setState(() {
        _geminiLoading = false;
        _geminiError = 'Could not fetch AI summary.';
      });
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _result = null;
      });
      _identifyPlant(_image!);
    }
  }

  Future<void> _identifyPlant(File image) async {
    setState(() {
      _loading = true;
      _result = null;
      _geminiSummary = null;
    });
    _controller.reset();
    
    final url = Uri.parse('https://api.plant.id/v3/identification');
    final apiKey = 'uBfRtba5sdLv673mc45o4dBQ3Xn3XeMjKuR75Wj4OaglDkMh8Z';
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final body = jsonEncode({
      'images': [base64Image],
      'classification_level': 'all'
    });
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Api-Key': apiKey,
        },
        body: body,
      );
      final data = jsonDecode(response.body);
      final suggestions = data['result']?['classification']?['suggestions'];
      if (suggestions != null && suggestions.isNotEmpty) {
        suggestions.sort((a, b) => (b['probability'] as num).compareTo(a['probability'] as num));
        final plant = suggestions[0];
        final probability = (plant['probability'] as num) * 100;
        if (probability < 20) {
          setState(() {
            _result = 'No plant identified.';
            _geminiSummary = null;
          });
        } else {
          final plantName = plant['name'];
          setState(() {
            _result = '$plantName (Probability: ${probability.toStringAsFixed(2)}%)';
            _geminiSummary = null;
            _geminiError = null;
          });
          // Fetch Gemini summary
          final summary = await _fetchGeminiSummary(plantName);
          setState(() {
            _geminiSummary = summary;
          });
        }
      } else {
        setState(() {
          _result = 'No plant identified.';
          _geminiSummary = null;
        });
      }
    } catch (e) {
      setState(() {
        _result = 'No plant identified.';
        _geminiSummary = null;
      });
    } finally {
      setState(() {
        _loading = false;
      });
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Plant Checker AI',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                if (_image != null)
                  Hero(
                    tag: 'plantImage',
                    child: Container(
                      height: 320,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.file(
                          _image!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
                if (_loading)
                  Column(
                    children: [
                      const SpinKitDoubleBounce(
                        color: Color(0xFF1B5E20),
                        size: 50.0,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Analyzing your plant...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                if (!_loading)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Take a Photo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B5E20),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.camera_alt_rounded,
                                label: 'Camera',
                                onPressed: () => _pickImage(ImageSource.camera),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.photo_library_rounded,
                                label: 'Gallery',
                                onPressed: () => _pickImage(ImageSource.gallery),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 40),
                if (_result != null)
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1B5E20).withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFF1B5E20).withOpacity(0.1),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _result!,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1B5E20),
                                letterSpacing: 0.3,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            // Gemini summary section
                            const SizedBox(height: 20),
                            Divider(color: Color(0xFF1B5E20).withOpacity(0.15)),
                            const SizedBox(height: 12),
                            if (_geminiLoading)
                              Column(
                                children: [
                                  const SpinKitThreeBounce(
                                    color: Color(0xFF388E3C),
                                    size: 24.0,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Getting AI summary...',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              )
                            else if (_geminiError != null)
                              Text(
                                _geminiError!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              )
                            else if (_geminiSummary != null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFe8f5e9),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _geminiSummary!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF388E3C),
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                    fontFamily: null,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Gradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: Colors.white),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
