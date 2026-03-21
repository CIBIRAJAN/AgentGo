import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class PosterGenerator {
  static Future<void> shareWishPoster({
    required BuildContext context,
    required String clientName,
    required String agentName,
    required String eventType,
    required String language,
    required String textMessage,
  }) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final isBirthday = eventType == 'birthday';
      final title = language == 'tamil'
          ? (isBirthday ? 'இனிய பிறந்தநாள்\nநல்வாழ்த்துக்கள்' : 'இனிய திருமண நாள்\nவாழ்த்துக்கள்')
          : (isBirthday ? 'Happy Birthday!' : 'Happy Anniversary!');

      final widget = Container(
        width: 1080,
        height: 1080,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isBirthday
                ? [const Color(0xFF8B5CF6), const Color(0xFF3B82F6)]
                : [const Color(0xFFF43F5E), const Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative elements
            Positioned(
              top: -50,
              right: -50,
              child: Icon(isBirthday ? Icons.cake : Icons.favorite,
                  size: 400, color: Colors.white.withValues(alpha: 0.1)),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Icon(Icons.star_rounded,
                  size: 350, color: Colors.white.withValues(alpha: 0.1)),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isBirthday ? Icons.cake_rounded : Icons.favorite_rounded,
                  size: 150,
                  color: Colors.white,
                ),
                const SizedBox(height: 48),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  clientName.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 84,
                    fontWeight: FontWeight.w900,
                    color: Colors.yellowAccent,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 64),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Text(
                    language == 'tamil' ? 'உங்கள் மனமார்ந்த வாழ்த்துக்கள்!' : 'Wishing you all the best!',
                    style: const TextStyle(
                      fontSize: 48,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 80),
                Text(
                  language == 'tamil' ? 'அன்புடன்,' : 'Warm Regards,',
                  style: const TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  agentName,
                  style: const TextStyle(
                    fontSize: 48,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Positioned(
              bottom: 32,
              child: Text(
                'powered by AgentGo',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white, 
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

      final screenshotController = ScreenshotController();
      final bytes = await screenshotController.captureFromLongWidget(
        Material(child: widget),
        delay: const Duration(milliseconds: 100),
        context: context,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/wish_poster.png');
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        Navigator.pop(context); // hide loading
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        text: textMessage,
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate poster: $e')),
        );
      }
    }
  }
}
