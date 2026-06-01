import 'package:flutter/material.dart';
import '../theme/thema.dart';
import '../services/supabase_service.dart';

class EditGroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupDescription;
  final Function() onGroupUpdated;

  const EditGroupChatScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    this.groupDescription,
    required this.onGroupUpdated,
  }) : super(key: key);

  @override
  State<EditGroupChatScreen> createState() => _EditGroupChatScreenState();
}

class _EditGroupChatScreenState extends State<EditGroupChatScreen> {
  late SupabaseService supabaseService;
  bool isLoading = false;
  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> groupMembers = [];
  Set<String> selectedMemberIds = {};

  late TextEditingController nameController;
  late TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();
    supabaseService = SupabaseService();
    nameController = TextEditingController(text: widget.groupName);
    descriptionController = TextEditingController(text: widget.groupDescription ?? '');
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      // Load all users
      final usersResponse = await supabaseService.client
          .from('users')
          .select('id, email, name')
          .order('email');
      allUsers = List<Map<String, dynamic>>.from(usersResponse);

      // Load current group members
      final membersResponse = await supabaseService.client
          .from('group_members')
          .select('user_id')
          .eq('group_id', widget.groupId);

      groupMembers = List<Map<String, dynamic>>.from(membersResponse);
      selectedMemberIds = Set.from(groupMembers.map((m) => m['user_id'] as String));

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateGroupChat() async {
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama group tidak boleh kosong')),
      );
      return;
    }

    if (selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 anggota')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Update group info
      await supabaseService.client
          .from('group_chats')
          .update({
            'name': nameController.text,
            'description': descriptionController.text,
          })
          .eq('id', widget.groupId);

      // Get current members
      final currentMemberIds = Set.from(groupMembers.map((m) => m['user_id'] as String));

      // Find members to remove
      final membersToRemove = currentMemberIds.difference(selectedMemberIds);

      // Find members to add
      final membersToAdd = selectedMemberIds.difference(currentMemberIds);

      // Remove members
      for (final userId in membersToRemove) {
        try {
          await supabaseService.removeGroupMember(widget.groupId, userId);
        } catch (e) {
          print('Error removing member $userId: $e');
        }
      }

      // Add new members
      for (final userId in membersToAdd) {
        try {
          await supabaseService.addGroupMember(widget.groupId, userId);
        } catch (e) {
          print('Error adding member $userId: $e');
        }
      }

      widget.onGroupUpdated();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group berhasil diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Edit Group',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 150, top: 16, left: 16, right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: 'Nama Group',
                      hintText: 'Masukkan nama group',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    enabled: !isLoading,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Deskripsi (opsional)',
                      hintText: 'Masukkan deskripsi group',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Anggota Group',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: allUsers.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Tidak ada pengguna tersedia',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: allUsers.length,
                            itemBuilder: (context, index) {
                              final user = allUsers[index];
                              final userId = user['id'] as String;
                              final isSelected = selectedMemberIds.contains(userId);
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedMemberIds.add(userId);
                                    } else {
                                      selectedMemberIds.remove(userId);
                                    }
                                  });
                                },
                                title: Text(user['name'] ?? user['email'] ?? 'Unknown'),
                                subtitle: Text(user['email'] ?? ''),
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${selectedMemberIds.length} anggota dipilih',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _updateGroupChat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
