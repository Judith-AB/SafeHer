import 'package:flutter/material.dart';
import 'package:safeher/theme.dart';

class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime time;

  ChatMessage({required this.text, required this.isBot})
      : time = DateTime.now();
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isBot = message.isBot;
    
    final bubbleColor = isBot ? AppTheme.white : AppTheme.deepCharcoal;
    final textColor = isBot ? AppTheme.deepCharcoal : AppTheme.creamLight;
    final timeColor = isBot 
        ? AppTheme.deepCharcoal.withOpacity(0.5) 
        : AppTheme.creamLight.withOpacity(0.65);

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isBot ? 4 : 18),
            bottomRight: Radius.circular(isBot ? 18 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepCharcoal.withOpacity(0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBot)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.balance,
                        size: 11, color: AppTheme.oliveMuted),
                    SizedBox(width: 4),
                    Text(
                      'Legal Assistant',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.oliveMuted,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _fmt(message.time),
                style: TextStyle(fontSize: 10, color: timeColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}