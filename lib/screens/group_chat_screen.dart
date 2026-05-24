import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/thema.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/screen_skeleton.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}


class _GroupChatScreenState extends State<GroupChatScreen> {
  late SupabaseService supabaseService;
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  TextEditingController messageController = TextEditingController();
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    supabaseService = SupabaseService();
    scrollController = ScrollController();
    _loadMessages();
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      // Fetch the single global group chat
      var groupChatResponse = await supabaseService.client
          .from('group_chats')
          .select('id')
          .limit(1);

      String groupChatId;
      
      if (groupChatResponse.isEmpty) {
        // Create group chat if it doesn't exist
        final createResponse = await supabaseService.client
            .from('group_chats')
            .insert({
              'name': 'Group Outlet Papi Kopi',
              'description': 'Team communication for all outlets',
            })
            .select('id');
        
        if (createResponse.isEmpty) {
          setState(() => isLoading = false);
          return;
        }
        groupChatId = createResponse[0]['id'];
      } else {
        groupChatId = groupChatResponse[0]['id'];
      }

      // Fetch messages with sender info - simple query without join
      final messagesResponse = await supabaseService.client
          .from('group_chat_messages')
          .select('*')
          .eq('group_chat_id', groupChatId)
          .order('created_at', ascending: true);

      if (messagesResponse.isNotEmpty) {
      }
      
      // Fetch sender info separately if needed
      List<Map<String, dynamic>> messagesWithSenders = [];
      Set<String> senderIds = {};
      
      // Collect all unique sender IDs first
      for (var msg in messagesResponse) {
        senderIds.add(msg['sender_id']);
      }
      
      
      // Fetch all senders in one query
      Map<String, Map<String, dynamic>> senderMap = {};
      if (senderIds.isNotEmpty) {
        try {
          final sendersResponse = await supabaseService.client
              .from('users')
              .select('id, name, role')
              .inFilter('id', senderIds.toList());
          
          for (var sender in sendersResponse) {
            senderMap[sender['id']] = sender;
          }
        } catch (e) {
        }
      }
      
      // Combine messages with sender info
      for (var msg in messagesResponse) {
        final sender = senderMap[msg['sender_id']];
        messagesWithSenders.add({
          ...msg,
          'sender': sender,
          'users': sender,
        });
      }

      
      setState(() {
        messages = messagesWithSenders;
        isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (messageController.text.isEmpty) return;

    final messageText = messageController.text;
    messageController.clear();

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id ?? '';

      if (userId.isEmpty) return;

      // Get the single global group chat id
      var groupChatResponse = await supabaseService.client
          .from('group_chats')
          .select('id')
          .limit(1);

      String groupChatId;
      
      if (groupChatResponse.isEmpty) {
        // Create group chat if it doesn't exist
        final createResponse = await supabaseService.client
            .from('group_chats')
            .insert({
              'name': 'Group Outlet Papi Kopi',
              'description': 'Team communication for all outlets',
            })
            .select('id');
        
        if (createResponse.isEmpty) {
          throw Exception('Failed to create group chat');
        }
        groupChatId = createResponse[0]['id'];
      } else {
        groupChatId = groupChatResponse[0]['id'];
      }

      
      // Send message
      await supabaseService.client.from('group_chat_messages').insert({
        'group_chat_id': groupChatId,
        'sender_id': userId,
        'message': messageText,
      });

      
      // Reload messages
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.altSurface),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.groups, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Group Outlet Papi Kopi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: isLoading
                ? const ScreenSkeleton(lineCount: 10, showTitle: false)
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada pesan',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          // Get sender info from either field
                          final sender = (message['sender'] ?? message['users']) as Map<String, dynamic>?;
                          final senderName = sender?['name'] ?? 'Unknown';
                          final senderRole = sender?['role'] ?? '';
                          final messageText = message['message'] ?? '';
                          final timestamp =
                              DateTime.parse(message['created_at']);
                          final timeString =
                              DateFormat('HH:mm', 'id_ID').format(timestamp);
                          

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primary,
                                      child: Text(
                                        senderName.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                senderName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: senderRole == 'manager'
                                                      ? AppColors.accent
                                                          .withOpacity(0.2)
                                                      : AppColors.primary
                                                          .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  senderRole,
                                                  style: TextStyle(
                                                    color: senderRole == 'manager'
                                                        ? AppColors.accent
                                                        : AppColors.primary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.background,
                                              border: Border.all(
                                                color: AppColors.altSurface,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  messageText,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  timeString,
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          // Input Area
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
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: AppColors.primary,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
