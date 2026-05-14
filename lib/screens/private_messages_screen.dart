import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/thema.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import 'private_messages_detail_screen.dart';
import 'new_message_screen.dart';
import 'group_chat_screen.dart';
import 'package:intl/intl.dart';

class PrivateMessagesScreen extends StatefulWidget {
  const PrivateMessagesScreen({Key? key}) : super(key: key);

  @override
  State<PrivateMessagesScreen> createState() => _PrivateMessagesScreenState();
}

class _PrivateMessagesScreenState extends State<PrivateMessagesScreen> with SingleTickerProviderStateMixin {
  late SupabaseService supabaseService;
  late TabController _tabController;
  List<Map<String, dynamic>> conversations = [];
  List<Map<String, dynamic>> groupChats = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    supabaseService = SupabaseService();
    _loadConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id ?? '';

      final messages = await supabaseService.getPrivateMessagesWithSenderInfo(
        userId: userId,
      );

      // Group messages by sender to get unique conversations
      final Map<String, Map<String, dynamic>> conversationMap = {};

      for (var message in messages) {
        final receiverId = message['receiver_id'];
        final senderId = message['sender_id'];
        
        // Only group incoming messages
        if (receiverId == userId) {
          final conversationKey = senderId;
          
          // Keep latest message
          if (!conversationMap.containsKey(conversationKey) ||
              DateTime.parse(message['created_at']).isAfter(
                DateTime.parse(conversationMap[conversationKey]?['created_at'] ?? ''),
              )) {
            conversationMap[conversationKey] = message;
          }
        }
      }

      setState(() {
        conversations = conversationMap.values.toList();
        conversations.sort((a, b) => 
          DateTime.parse(b['created_at']).compareTo(
            DateTime.parse(a['created_at']),
          ),
        );
        isLoading = false;
      });
    } catch (e) {
      print('Error loading conversations: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _handleNewMessage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewMessageScreen()),
    ).then((_) => _loadConversations());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Pesan',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.mail),
              text: 'Pesan Pribadi',
            ),
            Tab(
              icon: const Icon(Icons.groups),
              text: 'Group',
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Private Messages
          _buildPrivateMessagesTab(),
          // Tab 2: Group Chats
          _buildGroupChatsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _handleNewMessage,
              tooltip: 'Pesan Baru',
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildPrivateMessagesTab() {
    return isLoading
          ? const Center(child: CircularProgressIndicator())
          : conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada pesan',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final message = conversations[index];
                      final senderName = message['sender']?['name'] ?? 'Unknown';
                      final senderId = message['sender_id'];
                      final messageText = message['message'] ?? '';
                      final timestamp = DateTime.parse(message['created_at']);
                      final timeString = DateFormat('dd MMM HH:mm', 'id_ID').format(timestamp);

                      return GestureDetector(
                        onTap: () {
                          final auth = context.read<AuthProvider>();
                          final currentUserId = auth.currentUser?.id ?? '';
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PrivateMessagesDetailScreen(
                                conversationWithId: senderId,
                                conversationWithName: senderName,
                                currentUserId: currentUserId,
                                initialMessages: conversations,
                              ),
                            ),
                          ).then((_) => _loadConversations());
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.altSurface),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    senderName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    timeString,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                messageText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
  }

  Widget _buildGroupChatsTab() {
    return const GroupChatScreen();
  }
}
