import 'package:flutter/material.dart';
import '../theme/thema.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';

class PrivateMessagesDetailScreen extends StatefulWidget {
  final String conversationWithId;
  final String conversationWithName;
  final String currentUserId;
  final List<Map<String, dynamic>> initialMessages;

  const PrivateMessagesDetailScreen({
    Key? key,
    required this.conversationWithId,
    required this.conversationWithName,
    required this.currentUserId,
    required this.initialMessages,
  }) : super(key: key);

  @override
  State<PrivateMessagesDetailScreen> createState() =>
      _PrivateMessagesDetailScreenState();
}

class _PrivateMessagesDetailScreenState
    extends State<PrivateMessagesDetailScreen> {
  late SupabaseService supabaseService;
  late TextEditingController messageController;
  List<Map<String, dynamic>> conversation = [];
  bool isLoading = false;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    supabaseService = SupabaseService();
    messageController = TextEditingController();
    
    // Initialize with passed messages and filter for this conversation
    conversation = widget.initialMessages
        .where((msg) =>
            (msg['sender_id'] == widget.currentUserId &&
                msg['receiver_id'] == widget.conversationWithId) ||
            (msg['sender_id'] == widget.conversationWithId &&
                msg['receiver_id'] == widget.currentUserId))
        .toList();
    
    // Sort by created_at ascending (oldest first, newest last)
    conversation.sort((a, b) {
      final timeA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
      final timeB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
      return timeA.compareTo(timeB);
    });
    
    // Load full conversation from database to ensure all messages are shown
    _loadConversation();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    // Refresh conversation from database after sending
    setState(() => isLoading = true);
    try {
      final messages = await supabaseService.getPrivateMessages(
        userId: widget.currentUserId,
      );

      // Filter hanya messages antara current user dan conversation partner
      final filtered = messages
          .where((msg) =>
              (msg['sender_id'] == widget.currentUserId &&
                  msg['receiver_id'] == widget.conversationWithId) ||
              (msg['sender_id'] == widget.conversationWithId &&
                  msg['receiver_id'] == widget.currentUserId))
          .toList();
      
      // Sort by created_at ascending (oldest first, newest last)
      filtered.sort((a, b) {
        final timeA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
        final timeB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
        return timeA.compareTo(timeB);
      });

      setState(() {
        conversation = filtered;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading conversation: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (messageController.text.trim().isEmpty) return;

    setState(() => isSending = true);

    try {
      final success = await supabaseService.sendPrivateMessage(
        senderId: widget.currentUserId,
        receiverId: widget.conversationWithId,
        message: messageController.text.trim(),
      );

      if (success) {
        messageController.clear();
        await _loadConversation();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pesan terkirim')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengirim pesan')),
          );
        }
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          widget.conversationWithName,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages list
            Expanded(
            child: conversation.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.message,
                            size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada pesan',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: conversation.length,
                    itemBuilder: (context, index) {
                      final message = conversation[index];
                      final isCurrentUser =
                          message['sender_id'] == widget.currentUserId;
                      final timestamp = message['created_at'] != null
                          ? DateTime.parse(message['created_at'])
                          : DateTime.now();
                      final formattedTime =
                          DateFormat('HH:mm').format(timestamp);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Align(
                          alignment: isCurrentUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? AppColors.primary
                                  : AppColors.altSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: isCurrentUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['message'] ?? '',
                                  style: TextStyle(
                                    color: isCurrentUser
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedTime,
                                  style: TextStyle(
                                    color: isCurrentUser
                                        ? Colors.white70
                                        : AppColors.textSecondary,
                                    fontSize: 10,
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
          // Message input
          Container(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.altSurface),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    enabled: !isSending,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: isSending ? null : _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSending ? AppColors.textSecondary : AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}
