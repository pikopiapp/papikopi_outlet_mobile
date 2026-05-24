import 'package:flutter/material.dart';


import '../../models/outlet.dart';
import '../../services/supabase_service.dart';
import '../../theme/thema.dart';
import '../../widgets/header.dart';
import '../../widgets/screen_skeleton.dart';


class ManagerOutletScreen extends StatefulWidget {
  const ManagerOutletScreen({super.key});

  @override
  State<ManagerOutletScreen> createState() => _ManagerOutletScreenState();
}

class _ManagerOutletScreenState extends State<ManagerOutletScreen> {
  late final SupabaseService _supabase;
  bool _isLoading = true;
  String? _error;
  List<Outlet> _outlets = const [];

  @override
  void initState() {
    super.initState();
    _supabase = SupabaseService();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!_supabase.isInitialized) {
        await _supabase.initialize();
      }

      final response = await _supabase.getOutlets();

      // Map raw rows -> model Outlet
      final parsed = response.map((row) {
        // column set from schema: id, name, type, address, created_at, updated_at
        // model outlet.dart kemungkinan memakai field: location/phone/whatsapp/isActive.
        // Karena schema outlets belum memuat phone/whatsapp/isActive, kita set fallback.
        final id = (row['id'] as String?) ?? '';
        final name = (row['name'] as String?) ?? '';
        final type = (row['type'] as String?)?.toLowerCase() ?? 'gerobak';
        final address = (row['address'] as String?) ?? '';
        final createdAtRaw = row['created_at'];
        final updatedAtRaw = row['updated_at'];

        DateTime parseDate(dynamic v) {
          if (v is DateTime) return v;
          if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
          return DateTime.now();
        }

        final createdAt = parseDate(createdAtRaw);
        final updatedAt = parseDate(updatedAtRaw);

        return Outlet(
          id: id,
          name: name,
          type: type,
          location: address,
          phone: null,
          whatsapp: null,
          isActive: true,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
      }).toList();

      setState(() {
        _outlets = parsed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PapikopiAppBar(
        onLogout: null,
        onProfile: null,
        onSettings: null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daftar Outlet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Data outlet dari backend Supabase.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (_isLoading) {
                      return const ScreenSkeleton(lineCount: 8, showTitle: false);
                    }

                    if (_error != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Gagal memuat outlet: $_error',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (_outlets.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Belum ada outlet.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _loadOutlets,
                      child: ListView.separated(
                        itemCount: _outlets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final outlet = _outlets[index];
                          final statusColor = outlet.isActive ? AppColors.success : AppColors.textSecondary;

                          return Card(
                            elevation: 0,
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: AppColors.altSurface),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: statusColor.withOpacity(0.35),
                                      ),
                                    ),
                                    child: Icon(
                                      outlet.isActive ? Icons.storefront : Icons.pause_circle,
                                      color: statusColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          outlet.name,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          outlet.type,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          outlet.location,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Barista: (data belum tersedia)',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],

                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Belum ada halaman detail outlet'),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.chevron_right),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


