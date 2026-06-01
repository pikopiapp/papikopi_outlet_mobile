import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/thema.dart';
import '../services/supabase_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final String announcementId;

  const AnnouncementDetailScreen({
    Key? key,
    required this.announcementId,
  }) : super(key: key);

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  late SupabaseService supabaseService;
  Map<String, dynamic>? announcement;
  bool isLoading = true;
  bool isEditing = false;

  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late TextEditingController imageUrlController;

  @override
  void initState() {
    super.initState();
    supabaseService = SupabaseService();
    titleController = TextEditingController();
    descriptionController = TextEditingController();
    imageUrlController = TextEditingController();
    _loadAnnouncement();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncement() async {
    try {
      final data = await supabaseService.getAnnouncementById(widget.announcementId);
      setState(() {
        announcement = data;
        titleController.text = data['title'] ?? '';
        descriptionController.text = data['description'] ?? '';
        imageUrlController.text = data['image_url'] ?? '';
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveAnnouncement() async {
    if (titleController.text.isEmpty || descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title dan description tidak boleh kosong')),
      );
      return;
    }

    try {
      await supabaseService.updateAnnouncement(
        id: widget.announcementId,
        title: titleController.text,
        description: descriptionController.text,
        imageUrl: imageUrlController.text.isEmpty ? null : imageUrlController.text,
      );

      setState(() => isEditing = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengumuman berhasil diperbarui')),
        );
      }

      _loadAnnouncement();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteAnnouncement() async {
    try {
      await supabaseService.deleteAnnouncement(widget.announcementId);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate deletion
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengumuman berhasil dihapus')),
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

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengumuman'),
        content: const Text('Apakah Anda yakin ingin menghapus pengumuman ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAnnouncement();
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.currentUser?.role == 'admin' || auth.currentUser?.role == 'manager';

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text('Pengumuman', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (announcement == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text('Pengumuman', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text('Pengumuman tidak ditemukan', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final timestamp = DateTime.parse(announcement!['created_at']);
    final timeString = DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(timestamp);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Pengumuman', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: isAdmin && !isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => setState(() => isEditing = true),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: _showDeleteDialog,
                  tooltip: 'Hapus',
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: isEditing
            ? _buildEditForm()
            : _buildDetailView(timeString),
      ),
    );
  }

  Widget _buildDetailView(String timeString) {
    final imageUrl = announcement!['image_url'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          announcement!['title'] ?? 'Pengumuman',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Timestamp
        Text(
          timeString,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        // Image if available
        if (imageUrl != null && imageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    color: AppColors.altSurface,
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // Description
        Text(
          announcement!['description'] ?? '',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Input
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: 'Judul',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(height: 16),

        // Description Input
        TextField(
          controller: descriptionController,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Deskripsi',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(height: 16),

        // Image URL Input
        TextField(
          controller: imageUrlController,
          decoration: InputDecoration(
            labelText: 'URL Gambar (opsional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _saveAnnouncement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Simpan',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => isEditing = false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Batal'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
