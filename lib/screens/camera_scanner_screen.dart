import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/thema.dart';

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({
    super.key,
    this.cameraFacing = CameraFacing.back,
    this.title = 'Scan QR Code',
    this.subtitle = 'Arahkan kamera ke kode untuk memindai',
    this.showFlashIcon = true,
  });

  final CameraFacing cameraFacing;
  final String title;
  final String subtitle;
  final bool showFlashIcon;

  static Future<String?> open(
    BuildContext context, {
    CameraFacing cameraFacing = CameraFacing.back,
    String title = 'Scan QR Code',
    String subtitle = 'Arahkan kamera ke kode untuk memindai',
    bool showFlashIcon = true,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => CameraScannerScreen(
          cameraFacing: cameraFacing,
          title: title,
          subtitle: subtitle,
          showFlashIcon: showFlashIcon,
        ),
      ),
    );
  }

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  late final MobileScannerController _scannerController;
  bool _isFlashOn = false;
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      facing: widget.cameraFacing,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    await _scannerController.toggleTorch();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final previewRatio = 1600 / 1024;
                  final previewWidth = constraints.maxWidth;
                  final previewHeight = (previewWidth / previewRatio).clamp(0.0, constraints.maxHeight).toDouble();

                  return Center(
                    child: SizedBox(
                      width: previewWidth,
                      height: previewHeight,
                      child: MobileScanner(
                        controller: _scannerController,
                        fit: BoxFit.cover,
                        onDetect: (capture) {
                          if (_isScanned) return;
                          if (capture.barcodes.isEmpty) return;
                          final barcode = capture.barcodes.first;
                          final rawValue = barcode.rawValue;
                          if (rawValue != null && rawValue.isNotEmpty) {
                            _isScanned = true;
                            Navigator.of(context).pop(rawValue);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.showFlashIcon) ...[
                      IconButton(
                        onPressed: _toggleFlash,
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.75),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: -10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Arahkan QR code ke dalam kotak. Pindai otomatis setelah kode terdeteksi.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Tunggu sampai kode terbaca',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
