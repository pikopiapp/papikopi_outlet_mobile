import 'package:flutter/material.dart';
import '../theme/thema.dart';
import '../services/supabase_service.dart';

class NewAnnouncementScreen extends StatefulWidget {
  final Function() onAnnouncementCreated;

  const NewAnnouncementScreen({
    Key? key,
    required this.onAnnouncementCreated,
  }) : super(key: key);

  @override
  State<NewAnnouncementScreen> createState() => _NewAnnouncementScreenState();
}

class _NewAnnouncementScreenState extends State<NewAnnouncementScreen> {
  late SupabaseService supabaseService;
  bool isLoading = false;

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
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _createAnnouncement() async {
    if (titleController.text.isEmpty || descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan deskripsi tidak boleh kosong')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await supabaseService.createAnnouncement(
        title: titleController.text,
        description: descriptionController.text,
        imageUrl: imageUrlController.text.isEmpty ? null : imageUrlController.text,
      );

      widget.onAnnouncementCreated();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengumuman berhasil dibuat')),
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
          'Buat Pengumuman',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Input
            TextField(
              controller: titleController,
              enabled: !isLoading,
              decoration: InputDecoration(
                labelText: 'Judul',
                hintText: 'Masukkan judul pengumuman',
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
              enabled: !isLoading,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: 'Deskripsi',
                hintText: 'Masukkan isi pengumuman',
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
              enabled: !isLoading,
              decoration: InputDecoration(
                labelText: 'URL Gambar (opsional)',
                hintText: 'https://example.com/image.jpg',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _createAnnouncement,
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
                        'Buat Pengumuman',
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
