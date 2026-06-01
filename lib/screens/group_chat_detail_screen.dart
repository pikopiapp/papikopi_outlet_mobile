import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/thema.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import 'edit_group_chat_screen.dart';

class GroupChatDetailScreen extends StatefulWidget {
  final String groupChatId;
  final String groupName;

  const GroupChatDetailScreen({
    Key? key,
    required this.groupChatId,
    required this.groupName,
  }) : super(key: key);

  @override
  State<GroupChatDetailScreen> createState() => _GroupChatDetailScreenState();
}

class _GroupChatDetailScreenState extends State<GroupChatDetailScreen> {
  late SupabaseService supabaseService;
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  TextEditingController messageController = TextEditingController();
  late ScrollController scrollController;
  String? groupDescription;

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
      // Fetch group info including description
      final groupResponse = await supabaseService.client
          .from('group_chats')
          .select('description')
          .eq('id', widget.groupChatId)
          .single();

      groupDescription = groupResponse['description'];

      final messagesResponse = await supabaseService.client
          .from('group_chat_messages')
          .select('*')
          .eq('group_chat_id', widget.groupChatId)
          .order('created_at', ascending: true);

      Set<String> senderIds = {};
      for (var msg in messagesResponse) {
        senderIds.add(msg['sender_id']);
      }

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
          print('Error fetching senders: $e');
        }
      }

      List<Map<String, dynamic>> messagesWithSenders = [];
      for (var msg in messagesResponse) {
        final sender = senderMap[msg['sender_id']];
        messagesWithSenders.add({
          ...msg,
          'sender': sender,
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

      await supabaseService.client.from('group_chat_messages').insert({
        'group_chat_id': widget.groupChatId,
        'sender_id': userId,
        'message': messageText,
      });

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

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Group?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus group "${widget.groupName}"? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: _deleteGroup,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    try {
      Navigator.pop(context); // Close dialog
      
      await supabaseService.deleteGroupChat(widget.groupChatId);
      
      if (mounted) {
        Navigator.pop(context); // Close detail screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group berhasil dihapus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          widget.groupName,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditGroupChatScreen(
                    groupId: widget.groupChatId,
                    groupName: widget.groupName,
                    groupDescription: groupDescription,
                    onGroupUpdated: () {
                      _loadMessages();
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: _showDeleteConfirmation,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada pesan',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.only(bottom: 150),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final sender = message['sender'];
                            final senderName = sender?['name'] ?? 'Unknown';
                            final messageText = message['message'] ?? '';
                            final timestamp = DateTime.parse(message['created_at']);
                            final timeString = DateFormat('HH:mm').format(timestamp);
                            final auth = context.read<AuthProvider>();
                            final isCurrentUser = message['sender_id'] == auth.currentUser?.id;

                            return Align(
                              alignment: isCurrentUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? AppColors.primary
                                      : AppColors.altSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: isCurrentUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (!isCurrentUser)
                                      Text(
                                        senderName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentUser
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    Text(
                                      messageText,
                                      style: TextStyle(
                                        color: isCurrentUser
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      timeString,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isCurrentUser
                                            ? Colors.white70
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(12).copyWith(bottom: 80),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
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
                            hintText: 'Kirim pesan...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
