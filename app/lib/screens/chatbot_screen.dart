import 'package:flutter/material.dart';
import 'package:safeher/theme.dart';
import '../services/dialogflow_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _df = DialogflowService();
  final List<ChatMessage> _msgs = [];

  bool _typing = false;
  bool _ready = false;
  String? _error;

  static const _chips = [
    ('🆘 Helplines',       'show helplines'),
    ('📋 File FIR',        'how to file FIR'),
    ('🏠 DV Rights',       'domestic violence rights'),
    ('👔 POSH Act',        'workplace harassment POSH act'),
    ('👶 POCSO',           'POCSO act child protection'),
    ('🚫 Protection order','how to get a restraining order'),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _df.init();
      if (!mounted) return;
      setState(() => _ready = true);
      _addBot(
        'Hello! I\'m SafeHer\'s legal aid assistant 👩‍⚖️\n\n'
        'I can help you with:\n'
        '• Domestic violence rights (DV Act 2005)\n'
        '• How to file an FIR\n'
        '• Workplace harassment (POSH Act)\n'
        '• Child protection (POCSO Act)\n'
        '• Emergency helplines\n\n'
        'Tap a topic below or type your question.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          'Could not connect to legal assistant. '
          'Check your internet connection.');
    }
  }

  void _addBot(String text) {
    setState(() => _msgs.add(ChatMessage(text: text, isBot: true)));
    _scrollBottom();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || !_ready) return;

    _input.clear();
    setState(() {
      _msgs.add(ChatMessage(text: text, isBot: false));
      _typing = true;
    });
    _scrollBottom();

    try {
      final reply = await _df.send(text);
      if (!mounted) return;
      setState(() => _typing = false);
      _addBot(reply);
    } catch (_) {
      if (!mounted) return;
      setState(() => _typing = false);
      _addBot(
        'Sorry, something went wrong. For emergencies:\n\n'
        '🆘 Police: 100\n'
        '👩 Mahila Helpline: 181',
      );
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _df.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamLight,
      appBar: AppBar(
        backgroundColor: AppTheme.deepCharcoal,
        iconTheme: const IconThemeData(color: AppTheme.creamLight),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.creamLight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.balance, size: 18, color: AppTheme.creamLight),
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Legal Aid Assistant',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.creamLight)),
                Text('SafeHer • Free legal guidance',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.beigeMid)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_outlined, color: AppTheme.creamLight),
            tooltip: 'Emergency helplines',
            onPressed: () => _send('show helplines'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null) _errorBanner(),
          _chipRow(),
          Expanded(child: _messageList()),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _errorBanner() => Container(
        width: double.infinity,
        color: Colors.red.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_error!,
                  style: TextStyle(
                      color: Colors.red.shade700, fontSize: 13)),
            ),
          ],
        ),
      );

  Widget _chipRow() => Container(
        height: 48,
        color: AppTheme.creamLight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: _chips
              .map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(c.$1,
                          style: const TextStyle(fontSize: 12, color: AppTheme.deepCharcoal)),
                      backgroundColor: AppTheme.beigeMid,
                      side: BorderSide(
                          color: AppTheme.oliveMuted.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () => _send(c.$2),
                    ),
                  ))
              .toList(),
        ),
      );

  Widget _messageList() => ListView.builder(
        controller: _scroll,
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        itemCount: _msgs.length + (_typing ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _msgs.length) return const TypingIndicator();
          return ChatBubble(message: _msgs[i]);
        },
      );

  Widget _inputBar() => Container(
        color: AppTheme.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: _ready,
                  style: const TextStyle(color: AppTheme.deepCharcoal),
                  decoration: InputDecoration(
                    hintText: _ready
                        ? 'Ask a legal question...'
                        : 'Connecting…',
                    hintStyle: TextStyle(color: AppTheme.deepCharcoal.withOpacity(0.4)),
                    filled: true,
                    // Subtly themed fill
                    fillColor: AppTheme.creamLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: _send,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _send(_input.text),
                child: AnimatedOpacity(
                  opacity: _ready ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppTheme.deepCharcoal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: AppTheme.creamLight, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}