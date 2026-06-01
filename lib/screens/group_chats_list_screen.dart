import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/thema.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import 'new_group_chat_screen.dart';
import 'group_chat_detail_screen.dart';

class GroupChatsListScreen extends StatefulWidget {
  const GroupChatsListScreen({super.key});

  @override
  State<GroupChatsListScreen> createState() => _GroupChatsListScreenState();
}

class _GroupChatsListScreenState extends State<GroupChatsListScreen> {
  late SupabaseService supabaseService;
  List<Map<String, dynamic>> groupChats = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    supabaseService = SupabaseService();
    _loadGroupChats();
  }

  Future<void> _loadGroupChats() async {
    try {
      final response = await supabaseService.client
          .from('group_chats')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        groupChats = List<Map<String, dynamic>>.from(response);
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

  void _openCreateGroupDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewGroupChatScreen(
          onGroupCreated: _loadGroupChats,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isManager = auth.currentUser?.role == 'manager' || auth.currentUser?.role == 'admin';

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (groupChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Belum ada group chat',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            if (isManager)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: ElevatedButton(
                  onPressed: _openCreateGroupDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Buat Group Baru',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadGroupChats,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: groupChats.length,
          itemBuilder: (context, index) {
            final group = groupChats[index];
            final id = group['id'];
            final name = group['name'] ?? 'Group';
            final description = group['description'] ?? '';
            final timestamp = DateTime.parse(group['created_at']);
            final timeString = DateFormat('dd MMM yyyy', 'id_ID').format(timestamp);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupChatDetailScreen(
                      groupChatId: id,
                      groupName: name,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(14),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
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
                    if (description.isNotEmpty)
                      Text(
                        description,
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
      ),
      floatingActionButton: isManager
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _openCreateGroupDialog,
              tooltip: 'Buat Group Baru',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
