import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/thema.dart';
import '../widgets/screen_skeleton.dart';


class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<Map<String, dynamic>> _leaderboardWithOutletFuture;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize with empty future
    _leaderboardWithOutletFuture = Future.value({'outlet': null, 'leaderboard': []});
    // Defer context.read() to after build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_initialized) {
        _loadLeaderboard();
        _initialized = true;
      }
    });
  }

  Future<Map<String, dynamic>> _fetchLeaderboardWithOutlet() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final supabaseService = SupabaseService();

      if (authProvider.currentUser == null) {
        return {'outlet': null, 'leaderboard': []};
      }

      final outletId = authProvider.currentUser!.outletId;
      
      // Fetch outlet data
      final outlet = await supabaseService.getOutlet(outletId);

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Fetch leaderboard
      final leaderboard = await supabaseService.getLeaderboard(
        outletId: outletId,
        startDate: startOfDay,
        endDate: endOfDay,
      );

      return {
        'outlet': outlet,
        'leaderboard': leaderboard,
      };
    } catch (e) {
      rethrow;
    }
  }

  void _loadLeaderboard() {
    try {
      setState(() {
        _leaderboardWithOutletFuture = _fetchLeaderboardWithOutlet();
      });
    } catch (e) {
      setState(() {
        _leaderboardWithOutletFuture = Future.error(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 40,
              width: 40,
            ),
            const SizedBox(width: 8),
            const Text('Leaderboard Barista'),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _leaderboardWithOutletFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ScreenSkeleton(lineCount: 10, showTitle: false);
          }


          if (snapshot.hasError) {
            return const Center(
              child: Text('Terjadi kesalahan saat memuat leaderboard'),
            );
          }

          final data = snapshot.data ?? {'outlet': null, 'leaderboard': []};
          final outlet = data['outlet'];
          final leaderboard = data['leaderboard'] as List<Map<String, dynamic>>? ?? [];

          return Column(
            children: [
              // Show outlet info if available
              if (outlet != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outlet.name ?? 'Outlet',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${outlet.location ?? '-'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tipe: ${outlet.type ?? '-'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              // Show leaderboard
              Expanded(
                child: leaderboard.isEmpty
                    ? const Center(
                        child: Text('Belum ada data leaderboard'),
                      )
                    : ListView.builder(
                        itemCount: leaderboard.length,
                        itemBuilder: (context, index) {
                          final item = leaderboard[index];
                          final rank = index + 1;
                          final isTop3 = rank <= 3;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isTop3
                                  ? AppColors.accentLight.withOpacity(0.2)
                                  : AppColors.surface,
                              border: Border.all(
                                color: isTop3
                                    ? AppColors.accent
                                    : AppColors.altSurface,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isTop3
                                  ? [
                                      BoxShadow(
                                        color: Colors.amber[200]!.withOpacity(0.5),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Row(
                              children: [
                                // Rank
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getRankColor(rank),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$rank',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Outlet and Barista Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Outlet Name
                                      Text(
                                        item['outlet_name'] as String? ?? 'Outlet',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Barista Name
                                      Text(
                                        '${item['barista_name'] as String? ?? 'Unknown'} • ${item['transaction_count']} transaksi',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Revenue/Omset
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rp${_formatNumber((item['total_revenue'] as num?)?.toInt() ?? 0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Profit: Rp${_formatNumber((item['total_profit'] as num?)?.toInt() ?? 0)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green[600],
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
            ],
          );
        },
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber[700]!;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.amber[600]!;
      default:
        return Colors.blue[400]!;
    }
  }

  String _formatNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    } else {
      return '$value';
    }
  }
}
