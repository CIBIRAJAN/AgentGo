import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/theme/app_colors.dart';
import '../../utils/formatters.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';

class GlobalCelebration {
  final String id;
  final String name;
  final String date;
  final String imageUrl;
  final Color themeColor;

  GlobalCelebration({
    required this.id,
    required this.name,
    required this.date,
    required this.imageUrl,
    required this.themeColor,
  });

  factory GlobalCelebration.fromMap(Map<String, dynamic> map) {
    String colorHex = map['theme_color_hex'] ?? '#000000';
    if (colorHex.startsWith('#')) {
      colorHex = colorHex.substring(1);
    }
    return GlobalCelebration(
      id: map['id'],
      name: map['name'],
      date: map['date'],
      imageUrl: map['image_url'],
      themeColor: Color(int.parse('0xFF$colorHex')),
    );
  }
}

class GlobalCelebrationsScreen extends ConsumerStatefulWidget {
  const GlobalCelebrationsScreen({super.key});

  @override
  ConsumerState<GlobalCelebrationsScreen> createState() => _GlobalCelebrationsScreenState();
}

class _GlobalCelebrationsScreenState extends ConsumerState<GlobalCelebrationsScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  List<GlobalCelebration>? _celebrations;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCelebrations();
  }

  Future<void> _fetchCelebrations() async {
    try {
      final response = await Supabase.instance.client
          .from('global_celebrations')
          .select()
          .order('name');
      
      if (mounted) {
        setState(() {
          _celebrations = (response as List)
              .map((e) => GlobalCelebration.fromMap(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching celebrations: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _generateAndShowPoster(GlobalCelebration celebration) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select Language',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTertiary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'மொழியையும் வாழ்த்தையும் தேர்ந்தெடுக்கவும்',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.language_rounded, color: Colors.blue),
              ),
              title: const Text('English Greeting'),
              subtitle: const Text('Design a card in English'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _generateLocalizedPoster(celebration, 'en');
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.translate_rounded, color: Colors.orange),
              ),
              title: const Text('தமிழ் வாழ்த்து'),
              subtitle: const Text('தமிழில் அட்டையை வடிவமைக்கவும்'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _generateLocalizedPoster(celebration, 'ta');
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _generateLocalizedPoster(GlobalCelebration celebration, String lang) {
    final user = ref.read(userProvider).value;
    final agentName = user?.name ?? 'Your Agent';
    final screenshotController = ScreenshotController();
    
    // Localized content
    String title = 'Happy ${celebration.name}!';
    String festiveMessage = 'Wishing you all the best!';
    String warmRegardsText = 'Warm Regards,';
    
    final name = celebration.name.toLowerCase();
    
    if (lang == 'ta') {
      warmRegardsText = 'அன்புடன்,';
      if (name.contains('new year')) {
        title = 'இனிய புத்தாண்டு வாழ்த்துக்கள்';
        festiveMessage = 'இந்த ஆண்டு உங்கள் வாழ்வில் மகிழ்ச்சியும் வெற்றியும் பெருகட்டும்.';
      } else if (name.contains('pongal')) {
        title = 'இனிய பொங்கல் நல்வாழ்த்துக்கள்';
        festiveMessage = 'உங்கள் வாழ்வில் செல்வம் பெருகி மகிழ்ச்சி நிறையட்டும்.';
      } else if (name.contains('republic')) {
        title = 'இனிய குடியரசு தின நல்வாழ்த்துக்கள்';
        festiveMessage = 'இந்திய நாட்டின் பெருமையை கொண்டாடுவோம்!';
      } else if (name.contains('independence')) {
        title = 'சுதந்திர தின நல்வாழ்த்துக்கள்';
        festiveMessage = 'இந்தியாவின் சுதந்திர தினத்தை பெருமையுடன் கொண்டாடுவோம்!';
      } else if (name.contains('shivaratri')) {
        title = 'மஹா சிவராத்திரி நல்வாழ்த்துக்கள்';
        festiveMessage = 'எம்பெருமான் ஈசனின் அருள் உங்களுக்கு எப்போதும் கிடைக்கட்டும்.';
      } else if (name.contains('holi')) {
        title = 'இனிய ஹோலி நல்வாழ்த்துக்கள்';
        festiveMessage = 'உங்கள் வாழ்க்கை வண்ணமயமாக அமையட்டும்.';
      } else if (name.contains('diwali')) {
        title = 'இனிய தீபாவளி நல்வாழ்த்துக்கள்';
        festiveMessage = 'உங்கள் இல்லத்தில் ஒளியும் மகிழ்ச்சியும் பெருகட்டும்.';
      } else if (name.contains('christmas')) {
        title = 'இனிய கிறிஸ்துமஸ் நல்வாழ்த்துக்கள்';
        festiveMessage = 'உங்கள் இல்லம் அன்பினாலும் அமைதியினாலும் நிறையட்டும்.';
      }
    } else {
      if (name.contains('new year')) festiveMessage = 'May this year bring you new joy, success, and prosperity!';
      else if (name.contains('pongal')) festiveMessage = 'Wishing you a harvest of happiness and abundant prosperity!';
      else if (name.contains('republic')) festiveMessage = 'Saluting the spirit of India. Happy Republic Day!';
      else if (name.contains('independence')) festiveMessage = 'Freedom in mind, Faith in words. Happy Independence Day!';
      else if (name.contains('shivaratri')) festiveMessage = 'May the divine grace of Lord Shiva be with you always.';
      else if (name.contains('holi')) festiveMessage = 'May your life be as vibrant and colorful as the festival itself!';
      else if (name.contains('diwali')) festiveMessage = 'Wishing you a festival of lights filled with joy and prosperity!';
      else if (name.contains('christmas')) festiveMessage = 'Merry Christmas! May your home be filled with love and warmth.';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            Expanded(
              child: Screenshot(
                controller: screenshotController,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: celebration.themeColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background Image
                      Image.network(
                        celebration.imageUrl,
                        fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.4),
                        colorBlendMode: BlendMode.darken,
                        errorBuilder: (_, __, ___) => Container(color: celebration.themeColor),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getCelebrationIcon(celebration.name),
                              size: 70,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: lang == 'ta' ? 28 : 36,
                                fontWeight: FontWeight.w900,
                                shadows: const [Shadow(color: Colors.black45, blurRadius: 10)],
                              ),
                            ),
                            const SizedBox(height: 40),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                festiveMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: lang == 'ta' ? 18 : 20,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                            Text(
                              warmRegardsText,
                              style: const TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              agentName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'powered by AgentGo',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final image = await screenshotController.capture();
                    if (image != null) {
                      final directory = await getApplicationDocumentsDirectory();
                      final imagePath = await File('${directory.path}/greeting.png').create();
                      await imagePath.writeAsBytes(image);
                      await Share.shareXFiles([XFile(imagePath.path)], 
                        text: 'Happy ${celebration.name}! - Shared via AgentGo');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCelebrationIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('birthday')) return Icons.cake_rounded;
    if (name.contains('christmas')) return Icons.forest_rounded;
    if (name.contains('pongal')) return Icons.agriculture_rounded;
    if (name.contains('independence')) return Icons.flag_rounded;
    if (name.contains('republic')) return Icons.account_balance_rounded;
    if (name.contains('shivaratri')) return Icons.temple_hindu_rounded;
    if (name.contains('holi')) return Icons.palette_rounded;
    if (name.contains('diwali')) return Icons.auto_awesome_rounded;
    if (name.contains('new year')) return Icons.celebration_rounded;
    return Icons.festival_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Global Celebrations'),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          const SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upcoming Festivals',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Swipe to explorer celebrations & generate posters',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _celebrations == null || _celebrations!.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.celebration_outlined, size: 64, color: AppColors.textTertiary),
                            const SizedBox(height: 16),
                            const Text('No festive days found', style: TextStyle(color: AppColors.textSecondary)),
                            TextButton(onPressed: _fetchCelebrations, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: _celebrations!.length,
                        itemBuilder: (context, index) {
                          final celebration = _celebrations![index];
                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double value = 1.0;
                              if (_pageController.position.haveDimensions) {
                                value = _pageController.page! - index;
                                value = (1 - (value.abs() * .3)).clamp(0.0, 1.0);
                              }
                              return Center(
                                child: SizedBox(
                                  height: Curves.easeInOut.transform(value) * 500,
                                  width: Curves.easeInOut.transform(value) * 400,
                                  child: child,
                                ),
                              );
                            },
                            child: Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _generateAndShowPoster(celebration),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      celebration.imageUrl,
                                      fit: BoxFit.cover,
                                      color: Colors.black.withOpacity(0.2),
                                      colorBlendMode: BlendMode.darken,
                                      errorBuilder: (_, __, ___) =>
                                          Container(color: celebration.themeColor),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(30),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            celebration.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              celebration.date,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          ElevatedButton(
                                            onPressed: () =>
                                                _generateAndShowPoster(celebration),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: celebration.themeColor,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15)),
                                            ),
                                            child: const Text('Generate Greeting'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
