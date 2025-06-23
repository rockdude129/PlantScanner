import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const PlantCheckerApp());
}

class PlantCheckerApp extends StatelessWidget {
  const PlantCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantScanner AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF558B2F),
          primary: const Color(0xFF558B2F),
          secondary: const Color(0xFF8BC34A),
          background: const Color(0xFFFDF6E3),
          surface: const Color(0xFFFFFBF2),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: const Color(0xFF3E2723),
          onSurface: const Color(0xFF3E2723),
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
  
  // Follow-up questions feature
  final TextEditingController _questionController = TextEditingController();
  final List<Map<String, String>> _conversation = [];
  bool _askingQuestion = false;
  String? _currentPlantName;

  // Gemini API key
  final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? 'default_key';

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
        _geminiError = 'Could not fetch AI summary. There may be a problem with the Gemini Model or the API.';
      });
      return null;
    }
  }

  // Follow-up question handler
  Future<void> _askFollowUpQuestion(String question) async {
    if (question.trim().isEmpty || _currentPlantName == null) return;
    
    setState(() {
      _askingQuestion = true;
    });
    
    // Add user question to conversation
    _conversation.add({
      'type': 'user',
      'message': question,
    });
    
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _geminiApiKey,
    );
    
    // Create context-aware prompt
    final prompt = 'You are a helpful plant expert. The user has identified a plant called "$_currentPlantName" and is asking a follow-up question. Please provide a helpful, accurate, and friendly answer about this specific plant. Keep your response concise but informative.\n\nUser question: $question';
    
    try {
      final content = await model.generateContent([Content.text(prompt)]);
      final response = content.text ?? 'Sorry, I couldn\'t generate a response.';
      
      // Add AI response to conversation
      _conversation.add({
        'type': 'ai',
        'message': response,
      });
    } catch (e) {
      print('Gemini follow-up error: ${e.toString()}');
      _conversation.add({
        'type': 'ai',
        'message': 'Sorry, I encountered an error while processing your question. Please try again.',
      });
    } finally {
      setState(() {
        _askingQuestion = false;
      });
      _questionController.clear();
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
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _result = null;
        _conversation.clear(); // Clear previous conversation
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
    
    final apiKey = dotenv.env['PLANTNET_API_KEY'] ?? 'default_key';
    final project = 'all'; // Use 'all' for all floras
    final url = Uri.parse('https://my-api.plantnet.org/v2/identify/$project?api-key=$apiKey');
    
    try {
      // Create multipart request for Pl@ntNet API
      var request = http.MultipartRequest('POST', url);
      
      // Add the image file
      request.files.add(await http.MultipartFile.fromPath(
        'images',
        image.path,
      ));
      
      // Add organs parameter (auto-detect)
      request.fields['organs'] = 'auto';
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        print('Pl@ntNet API error: ${response.statusCode} - ${response.body}');
        setState(() {
          _result = 'Error identifying plant. Please check your API key.';
          _geminiSummary = null;
        });
        return;
      }
      
      final data = jsonDecode(response.body);
      print('Pl@ntNet response: $data'); // Debug log
      
      final results = data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        // Sort by score (confidence)
        results.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
        final plant = results[0];
        final score = (plant['score'] as num) * 100;
        
        // Extract plant name from the species object
        final species = plant['species'];
        final plantName = species['commonNames']?.first ?? 
                         species['scientificNameWithoutAuthor'] ?? 
                         'Unknown Plant';
        
        if (score < 20) {
          setState(() {
            _result = 'No plant identified.';
            _geminiSummary = null;
            _currentPlantName = null;
          });
        } else {
          setState(() {
            _result = '$plantName (Confidence: ${score.toStringAsFixed(2)}%)';
            _geminiSummary = null;
            _geminiError = null;
            _currentPlantName = plantName; // Store for follow-up questions
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
      print('Pl@ntNet API error: ${e.toString()}');
      setState(() {
        _result = 'No plant has been identified!';
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
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 32,
                  height: 32,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'PlantScanner AI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
            ],
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
                      color: Theme.of(context).colorScheme.surface,
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
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _geminiSummary!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                    fontFamily: null,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            
                            // Follow-up questions section
                            if (_currentPlantName != null && _geminiSummary != null) ...[
                              const SizedBox(height: 20),
                              Divider(color: Color(0xFF1B5E20).withOpacity(0.15)),
                              const SizedBox(height: 12),
                              
                              // Conversation history
                              if (_conversation.isNotEmpty) ...[
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                                  ),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _conversation.length,
                                    itemBuilder: (context, index) {
                                      final message = _conversation[index];
                                      final isUser = message['type'] == 'user';
                                      
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (isUser) const Spacer(),
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: isUser
                                                      ? Theme.of(context).colorScheme.primary
                                                      : Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.04),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 4),
                                                    )
                                                  ]
                                                ),
                                                child: Text(
                                                  message['message']!,
                                                  style: TextStyle(
                                                    color: isUser 
                                                      ? Colors.white
                                                      : Colors.black87,
                                                    fontSize: 14,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (!isUser) const Spacer(),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              
                              // Question input
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: TextField(
                                        controller: _questionController,
                                        decoration: InputDecoration(
                                          hintText: 'Ask a question about $_currentPlantName...',
                                          hintStyle: TextStyle(color: Colors.grey[500]),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                        onSubmitted: (value) {
                                          if (value.trim().isNotEmpty) {
                                            _askFollowUpQuestion(value);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1B5E20),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: _askingQuestion
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.send, color: Colors.white),
                                      onPressed: _askingQuestion
                                        ? null
                                        : () {
                                            if (_questionController.text.trim().isNotEmpty) {
                                              _askFollowUpQuestion(_questionController.text);
                                            }
                                          },
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              Text(
                                'Ask follow-up questions about care, growth, or any plant-related topics!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
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
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
