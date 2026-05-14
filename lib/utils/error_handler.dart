import 'package:flutter/material.dart';

/// Error handling utilities
class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is Exception) {
      String message = error.toString();
      
      // Parse specific error patterns
      if (message.contains('no element')) {
        return 'Data tidak ditemukan. Coba refresh.';
      } else if (message.contains('timeout')) {
        return 'Koneksi timeout. Periksa internet Anda.';
      } else if (message.contains('connection')) {
        return 'Tidak ada koneksi internet.';
      } else if (message.contains('unauthorized')) {
        return 'Sesi anda telah berakhir. Silakan login kembali.';
      } else if (message.contains('permission')) {
        return 'Anda tidak memiliki izin untuk tindakan ini.';
      } else if (message.contains('duplicate')) {
        return 'Data sudah ada. Gunakan data yang berbeda.';
      } else if (message.contains('foreign key')) {
        return 'Data terkait tidak ditemukan.';
      }
      
      return message;
    }
    return 'Terjadi kesalahan yang tidak terduga.';
  }

  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final message = getErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showWarningSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Error display widget
class ErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorDisplay({
    Key? key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.red[700],
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading overlay
class LoadingOverlay extends StatelessWidget {
  final String message;
  final bool dismissible;

  const LoadingOverlay({
    Key? key,
    this.message = 'Loading...',
    this.dismissible = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => dismissible,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Safe async operation with error handling
Future<T?> safeAsyncOperation<T>({
  required BuildContext context,
  required Future<T> Function() operation,
  String? loadingMessage,
  String? errorMessage,
  bool showLoading = true,
}) async {
  try {
    if (showLoading) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => LoadingOverlay(message: loadingMessage ?? 'Loading...'),
      );
    }

    final result = await operation();

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading dialog
    }

    return result;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading dialog
      ErrorHandler.showErrorSnackBar(context, e);
    }
    return null;
  }
}
