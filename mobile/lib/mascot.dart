import 'package:flutter/material.dart';

enum HeartMood {
  joyful('😊 Happy'),
  loving('🥰 Loved'),
  missing('🥹 Missing you'),
  anxious('Anxious'),
  sleepy('😴 Tired'),
  angry('😡 Angry'),
  sad('😔 Sad');

  final String label;
  const HeartMood(this.label);

  static HeartMood? parse(dynamic value) {
    for (final mood in values) {
      if (mood.name == value) return mood;
    }
    return null;
  }
}

// Defaults follow couple membership, never the current viewer or their name.
String mascotFor(Map? person, Map couple) {
  final saved = person?['mascot'];
  if (saved == 'male' || saved == 'female') return saved as String;
  return person?['id'] == couple['user_1']?['id'] ? 'male' : 'female';
}

class HeartMascot extends StatelessWidget {
  final String character;
  final HeartMood mood;
  final double size;
  const HeartMascot(
      {super.key,
      required this.character,
      this.mood = HeartMood.joyful,
      this.size = 96});

  @override
  Widget build(BuildContext context) {
    // Measured sprite bounds preserve all limbs and exclude adjacent sprites.
    const lefts = [28.0, 285.0, 530.0, 777.0, 1028.0, 1275.0];
    const rights = [280.0, 515.0, 768.0, 1020.0, 1260.0, 1510.0];
    final index = mood == HeartMood.sad ? 3 : mood.index;
    final top = character == 'female' ? 550.0 : 145.0;
    return SizedBox.square(
      dimension: size,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: rights[index] - lefts[index],
            height: 310,
            child: ClipRect(
              child: Stack(children: [
                Positioned(
                    left: -lefts[index],
                    top: -top,
                    width: 1536,
                    height: 1024,
                    child: Image.asset('assets/mascots/hearts-moods.png',
                        width: 1536,
                        height: 1024,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
