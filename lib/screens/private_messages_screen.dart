import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/thema.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import 'private_messages_detail_screen.dart';
import 'new_message_screen.dart';
import 'group_chats_list_screen.dart';
import 'announcement_detail_screen.dart';
import 'new_announcement_screen.dart';
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
  List<Map<String, dynamic>> announcements = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    supabaseService = SupabaseService();
    _loadConversations();
    _loadAnnouncements();
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

      // Group messages by conversation partner (both sent and received)
      final Map<String, Map<String, dynamic>> conversationMap = {};

      for (var message in messages) {
        final receiverId = message['receiver_id'];
        final senderId = message['sender_id'];
        
        // Get conversation partner ID
        String conversationPartnerId;
        if (senderId == userId) {
          // Message was sent by current user
          conversationPartnerId = receiverId;
        } else {
          // Message was received by current user
          conversationPartnerId = senderId;
        }
        
        // Keep latest message
        if (!conversationMap.containsKey(conversationPartnerId) ||
            DateTime.parse(message['created_at']).isAfter(
              DateTime.parse(conversationMap[conversationPartnerId]?['created_at'] ?? ''),
            )) {
          conversationMap[conversationPartnerId] = message;
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

  Future<void> _loadAnnouncements() async {
    try {
      final response = await supabaseService.client
          .from('announcements')
          .select('*')
          .order('created_at', ascending: false)
          .limit(100);

      setState(() {
        announcements = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading announcements: $e')),
        );
      }
    }
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
              icon: const Icon(Icons.announcement),
              text: 'Pengumuman',
            ),
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
          // Tab 0: Announcements
          _buildAnnouncementsTab(),
          // Tab 1: Private Messages
          _buildPrivateMessagesTab(),
          // Tab 2: Group Chats
          _buildGroupChatsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? _buildAnnouncementFAB()
          : _tabController.index == 1
              ? FloatingActionButton(
                  backgroundColor: AppColors.primary,
                  onPressed: _handleNewMessage,
                  tooltip: 'Pesan Baru',
                  child: const Icon(Icons.edit, color: Colors.white),
                )
              : null,
    );
  }

  Widget _buildAnnouncementFAB() {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.currentUser?.role == 'admin' || auth.currentUser?.role == 'manager';

    if (!isAdmin) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      backgroundColor: AppColors.primary,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewAnnouncementScreen(
              onAnnouncementCreated: _loadAnnouncements,
            ),
          ),
        );
      },
      tooltip: 'Buat Pengumuman',
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  Widget _buildAnnouncementsTab() {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : announcements.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.announcement, size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada pengumuman',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadAnnouncements,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: announcements.length,
                  itemBuilder: (context, index) {
                    final announcement = announcements[index];
                    final id = announcement['id'];
                    final title = announcement['title'] ?? 'Pengumuman';
                    final description = announcement['description'] ?? '';
                    final imageUrl = announcement['image_url'];
                    final timestamp = DateTime.parse(announcement['created_at']);
                    final timeString = DateFormat('dd MMM HH:mm', 'id_ID').format(timestamp);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnnouncementDetailScreen(
                              announcementId: id,
                            ),
                          ),
                        ).then((deleted) {
                          if (deleted == true) {
                            _loadAnnouncements();
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Color(0xFFE8E8E8),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
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
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // View detail button
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AnnouncementDetailScreen(
                                              announcementId: id,
                                            ),
                                          ),
                                        ).then((deleted) {
                                          if (deleted == true) {
                                            _loadAnnouncements();
                                          }
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 0),
                                      ),
                                      child: const Text(
                                        'Lihat Selengkapnya →',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Image preview if available
                            if (imageUrl != null && imageUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    imageUrl,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 150,
                                        color: AppColors.altSurface,
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
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
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final message = conversations[index];
                      final senderId = message['sender_id'];
                      final currentUserId = context.read<AuthProvider>().currentUser?.id ?? '';
                      
                      // Get conversation partner name and ID
                      String conversationPartnerId;
                      String conversationPartnerName;
                      
                      if (senderId == currentUserId) {
                        // Current user sent this message, so partner is receiver
                        conversationPartnerId = message['receiver_id'];
                        conversationPartnerName = message['receiver_name'] ?? message['receiver_email'] ?? 'Unknown';
                      } else {
                        // Someone sent this to current user
                        conversationPartnerId = senderId;
                        conversationPartnerName = message['sender_name'] ?? message['sender_email'] ?? 'Unknown';
                      }
                      
                      final messageText = message['message'] ?? '';
                      final timestamp = DateTime.parse(message['created_at']);
                      final timeString = DateFormat('dd MMM HH:mm', 'id_ID').format(timestamp);

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PrivateMessagesDetailScreen(
                                conversationWithId: conversationPartnerId,
                                conversationWithName: conversationPartnerName,
                                currentUserId: currentUserId,
                                initialMessages: conversations,
                              ),
                            ),
                          ).then((_) => _loadConversations());
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Color(0xFFFAFAFA),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: Color(0xFFE8E8E8),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      conversationPartnerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: Color(0xFF1F1F1F),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    timeString,
                                    style: TextStyle(
                                      color: Color(0xFF999999),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                messageText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 13,
                                  height: 1.4,
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
    return const GroupChatsListScreen();
  }
}
