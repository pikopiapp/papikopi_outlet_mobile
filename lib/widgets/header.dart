import 'package:flutter/material.dart';
import '../theme/thema.dart';

class PapikopiAppBar extends AppBar {
  final VoidCallback? onLogout;
  final VoidCallback? onProfile;
  final VoidCallback? onSettings;
  final VoidCallback? onRefresh;
  final VoidCallback? onMessages;
  final List<Widget>? additionalActions;

  PapikopiAppBar({
    this.onLogout,
    this.onProfile,
    this.onSettings,
    this.onRefresh,
    this.onMessages,
    this.additionalActions,
    Key? key,
  }) : super(
    key: key,
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 2,
    title: Row(
      children: [
        Image.asset('assets/logo.png', height: 40),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Papikopi Outlet',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    actions: _buildActions(onLogout, onProfile, onSettings, onRefresh, onMessages, additionalActions),
  );

  static List<Widget> _buildActions(
    VoidCallback? onLogout,
    VoidCallback? onProfile,
    VoidCallback? onSettings,
    VoidCallback? onRefresh,
    VoidCallback? onMessages,
    List<Widget>? additionalActions,
  ) {
    final actions = <Widget>[];

    // Tambahan actions jika ada
    if (additionalActions != null) {
      actions.addAll(additionalActions);
    }

    // Messages button jika ada
    if (onMessages != null) {
      actions.add(
        IconButton(
          onPressed: onMessages,
          icon: const Icon(Icons.mail),
          tooltip: 'Pesan',
        ),
      );
    }

    // Refresh button jika ada
    if (onRefresh != null) {
      actions.add(
        _RefreshButton(onRefresh: onRefresh),
      );
    }

    // Menu button (Profile, Setting, Logout)
    actions.add(
      PopupMenuButton(
        onSelected: (value) {
          if (value == 'profile' && onProfile != null) {
            onProfile();
          } else if (value == 'settings' && onSettings != null) {
            onSettings();
          } else if (value == 'logout' && onLogout != null) {
            onLogout();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Profil'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'settings',
            child: Row(
              children: [
                const Icon(Icons.settings, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Setting'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text('Logout'),
              ],
            ),
          ),
        ],
      ),
    );

    return actions;
  }
}

class _RefreshButton extends StatefulWidget {
  final VoidCallback onRefresh;

  const _RefreshButton({required this.onRefresh});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleRefresh() {
    // Start spinning animation
    _controller.repeat();
    
    // Call the refresh callback
    widget.onRefresh();
    
    // Stop animation after 3 seconds (or when data loads)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controller.isAnimating) {
        _controller.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: IconButton(
        onPressed: _handleRefresh,
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh Data',
      ),
    );
  }
}
