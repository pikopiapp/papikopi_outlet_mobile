import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/thema.dart';

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({
    super.key,
    this.cameraFacing = CameraFacing.back,
    this.title = 'Scan QR Code',
    this.subtitle = 'Arahkan kamera ke kode untuk memindai',
    this.showFlashIcon = true,
    this.multiScan = false,
  });

  final CameraFacing cameraFacing;
  final String title;
  final String subtitle;
  final bool showFlashIcon;
  final bool multiScan;

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

  static Future<List<String>?> openMulti(
    BuildContext context, {
    CameraFacing cameraFacing = CameraFacing.back,
    String title = 'Scan QR Code',
    String subtitle = 'Scan produk berkali-kali, tekan Selesai bila sudah',
    bool showFlashIcon = true,
  }) {
    return Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (context) => CameraScannerScreen(
          cameraFacing: cameraFacing,
          title: title,
          subtitle: subtitle,
          showFlashIcon: showFlashIcon,
          multiScan: true,
        ),
      ),
    );
  }

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  // One camera session reads each code many times per second; ignore the same
  // code within this window so one bottle is not counted dozens of times, while
  // scanning the same bottle again a moment later still adds another unit.
  static const _repeatWindow = Duration(milliseconds: 1500);

  late final MobileScannerController _scannerController;
  bool _isFlashOn = false;
  bool _isScanned = false;
  final List<String> _codes = [];
  final Map<String, DateTime> _lastSeen = {};

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

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    if (!widget.multiScan) {
      if (_isScanned) return;
      _isScanned = true;
      Navigator.of(context).pop(rawValue);
      return;
    }

    final now = DateTime.now();
    final last = _lastSeen[rawValue];
    if (last != null && now.difference(last) < _repeatWindow) return;
    _lastSeen[rawValue] = now;
    HapticFeedback.selectionClick();
    setState(() => _codes.add(rawValue));
  }

  String _labelFor(String code) {
    try {
      final data = jsonDecode(code);
      if (data is Map) {
        final name = data['product'] ?? data['product_name'] ?? data['name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString();
        }
      }
    } catch (_) {
      // Not JSON, fall through to the raw value.
    }
    return code.length > 18 ? '${code.substring(0, 18)}…' : code;
  }

  Map<String, int> get _counts {
    final counts = <String, int>{};
    for (final code in _codes) {
      final label = _labelFor(code);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.multiScan;
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
                        onDetect: _onDetect,
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
                child: multi ? _buildMultiBottomPanel() : _buildSingleBottomPanel(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleBottomPanel() {
    return Column(
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
    );
  }

  Widget _buildMultiBottomPanel() {
    final counts = _counts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_codes.isEmpty)
          Text(
            'Scan produk satu per satu. Produk yang sama boleh discan berulang untuk menambah jumlah.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          )
        else
          SizedBox(
            height: 88,
            child: ListView(
              reverse: true,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: counts.entries.map((entry) {
                    return Chip(
                      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
                      label: Text(
                        '${entry.key} ×${entry.value}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _codes.isEmpty
                ? null
                : () => Navigator.of(context).pop(List<String>.from(_codes)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.check),
            label: Text(
              'Selesai (${_codes.length} scan)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
