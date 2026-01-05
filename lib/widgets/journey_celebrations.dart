import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

enum CelebrationType {
  stepCompleted, // ✅ Single step done
  milestone25, // 🎯 25% complete
  milestone50, // 🎯 50% complete
  milestone75, // 🎯 75% complete
  journeyCompleted, // 🏆 GOAL REACHED!
}

class CelebrationConfig {
  final int confettiCount;
  final Duration duration;
  final List<Color> colors;
  final bool showBanner;
  final String? bannerText;
  final bool playSound;
  final bool fullScreenOverlay;

  const CelebrationConfig({
    required this.confettiCount,
    required this.duration,
    required this.colors,
    this.showBanner = false,
    this.bannerText,
    this.playSound = false,
    this.fullScreenOverlay = false,
  });
}

class JourneyCelebration extends StatefulWidget {
  final CelebrationType type;
  final VoidCallback? onFinished;

  const JourneyCelebration({
    super.key,
    required this.type,
    this.onFinished,
  });

  @override
  State<JourneyCelebration> createState() => _JourneyCelebrationState();
}

class _JourneyCelebrationState extends State<JourneyCelebration> {
  late ConfettiController _controller;
  late CelebrationConfig _config;

  static final Map<CelebrationType, CelebrationConfig> _celebrations = {
    CelebrationType.stepCompleted: CelebrationConfig(
      confettiCount: 50,
      duration: const Duration(seconds: 2),
      colors: [Colors.green, Colors.lightGreen, Colors.white],
      showBanner: false,
    ),
    CelebrationType.milestone25: CelebrationConfig(
      confettiCount: 100,
      duration: const Duration(seconds: 3),
      colors: [Colors.blue, Colors.lightBlue, Colors.white],
      showBanner: true,
      bannerText: "🎉 25% Done! Keep it up!",
    ),
    CelebrationType.milestone50: CelebrationConfig(
      confettiCount: 150,
      duration: const Duration(seconds: 3),
      colors: [Colors.amber, Colors.orange, Colors.yellow],
      showBanner: true,
      bannerText: "🎉 HALFWAY THERE! 🎉",
    ),
    CelebrationType.milestone75: CelebrationConfig(
      confettiCount: 200,
      duration: const Duration(seconds: 4),
      colors: [Colors.purple, Colors.deepPurple, Colors.white],
      showBanner: true,
      bannerText: "🎉 SO CLOSE! 75% 🎉",
    ),
    CelebrationType.journeyCompleted: CelebrationConfig(
      confettiCount: 500,
      duration: const Duration(seconds: 5),
      colors: [
        Colors.red,
        Colors.orange,
        Colors.yellow,
        Colors.green,
        Colors.blue,
      ],
      showBanner: true,
      bannerText: "🏆 GOAL ACHIEVED! 🏆",
      playSound: true,
      fullScreenOverlay: true,
    ),
  };

  @override
  void initState() {
    super.initState();
    _config = _celebrations[widget.type]!;
    _controller = ConfettiController(duration: _config.duration);
    _controller.play();

    // Auto-dispose/finish after duration + buffer
    Future.delayed(_config.duration + const Duration(seconds: 1), () {
      if (mounted) {
        widget.onFinished?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Full screen overlay if needed
        if (_config.fullScreenOverlay)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            width: double.infinity,
            height: double.infinity,
          ),

        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: _config.colors,
            numberOfParticles: _config.confettiCount ~/ 5,
            emissionFrequency: 0.05,
            gravity: 0.2,
          ),
        ),

        // Banner
        if (_config.showBanner && _config.bannerText != null)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    _config.bannerText!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
