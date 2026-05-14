import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/thema.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import 'private_messages_detail_screen.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({Key? key}) : super(key: key);

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  late SupabaseService supabaseService;
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    supabaseService = SupabaseService();
    _loadUsers();
    searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final auth = context.read<AuthProvider>();
      final currentUserId = auth.currentUser?.id ?? '';

      // Fetch all users except current user and exclude investors
      final response = await supabaseService.client
          .from('users')
          .select('id, name, email, outlet_id')
          .neq('id', currentUserId)
          .neq('role', 'investor');

      setState(() {
        users = List<Map<String, dynamic>>.from(response);
        filteredUsers = users;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _filterUsers() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredUsers = users;
      } else {
        filteredUsers = users
            .where((user) {
              final name = (user['name'] as String?)?.toLowerCase() ?? '';
              final email = (user['email'] as String?)?.toLowerCase() ?? '';
              return name.contains(query) || email.contains(query);
            })
            .toList();
      }
    });
  }

  void _startConversation(Map<String, dynamic> user) {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '';
    final userId = user['id'];
    final userName = user['name'] ?? 'Unknown';

    // Navigate to detail screen for new conversation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrivateMessagesDetailScreen(
          conversationWithId: userId,
          conversationWithName: userName,
          currentUserId: currentUserId,
          initialMessages: [],
        ),
      ),
    ).then((_) => Navigator.pop(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Pesan Baru',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau email...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            // Users List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off,
                                  size: 64, color: AppColors.textSecondary),
                              const SizedBox(height: 16),
                              Text(
                                searchController.text.isEmpty
                                    ? 'Tidak ada pengguna'
                                    : 'Pengguna tidak ditemukan',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final userName = user['name'] ?? 'Unknown';
                            final userEmail = user['email'] ?? '';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  userName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(userName),
                              subtitle: Text(userEmail),
                              onTap: () => _startConversation(user),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
