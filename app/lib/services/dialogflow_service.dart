import 'package:dialog_flowtter/dialog_flowtter.dart';

class DialogflowService {
  DialogFlowtter? _client;

  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    try {
      _client = DialogFlowtter(
        sessionId:
            "safeher_${DateTime.now().millisecondsSinceEpoch}",
        jsonPath: 'assets/dialog_flow_auth.json',
      );

      _ready = true;
    } catch (e) {
      _ready = false;

      print("Dialogflow Init Error: $e");
    }
  }

  Future<String> send(String userMessage) async {
    if (!_ready || _client == null) {
      return "Assistant initializing...";
    }

    try {
      final response = await _client!.detectIntent(
        queryInput: QueryInput(
          text: TextInput(
            text: userMessage,
            languageCode: "en",
          ),
        ),
      );

      return response.text ??
          "I didn't understand that.";
    } catch (e) {
      print("Dialogflow Error: $e");

      return "Connection error.";
    }
  }

  void dispose() {
    _client?.dispose();
  }
}
