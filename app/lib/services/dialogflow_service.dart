import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';

class LegalReply {
  final String text;
  final String? intent;
  final double confidence;
  final bool referral;

  LegalReply(this.text, this.intent, this.confidence, this.referral);
}

// Calls Dialogflow through a Cloud Function so the app ships no service-account key.
class DialogflowService {
  final _functions =
    FirebaseFunctions.instanceFor(region: 'asia-south1');
  final String sessionId = _randomId();

  static String _randomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<LegalReply> send(String message) async {
    final result = await _functions
        .httpsCallable('detectLegalIntent')
        .call({'text': message, 'sessionId': sessionId});
    final d = Map<String, dynamic>.from(result.data as Map);
    return LegalReply(
      (d['reply'] as String?) ?? '',
      d['intent'] as String?,
      (d['confidence'] as num?)?.toDouble() ?? 0,
      d['referral'] == true,
    );
  }

  Future<void> logUnanswered(String query) async {
    await _functions.httpsCallable('escalateLegalQuery').call({'userQuery': query});
  }
}
