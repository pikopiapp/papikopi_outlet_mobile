import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
// import 'dart:typed_data';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/product.dart';
// import 'package:bluetooth_print/bluetooth_print.dart';
// import 'package:bluetooth_print/bluetooth_print_model.dart';

class PrintLabelDialog extends StatefulWidget {
  final Product product;
  final String batch;
  final String productionDate;
  final String? expiryDate;

  const PrintLabelDialog({
    Key? key,
    required this.product,
    required this.batch,
    required this.productionDate,
    this.expiryDate,
  }) : super(key: key);

  @override
  State<PrintLabelDialog> createState() => _PrintLabelDialogState();
}

class _PrintLabelDialogState extends State<PrintLabelDialog> {
  // final BluetoothPrint _bluetoothPrint = BluetoothPrint.instance;
  bool _isConnected = false;
  bool _isPrinting = false;
  // List<BluetoothDevice> _devices = [];
  List<dynamic> _devices = [];

  @override
  void initState() {
    super.initState();
    _initPrinter();
  }

  Future<void> _initPrinter() async {
    // Initialize Bluetooth printer (disabled - needs compatibility fix)
    // bool? isConnected = await _bluetoothPrint.isConnected;
    // setState(() {
    //   _isConnected = isConnected ?? false;
    // });

    // Get paired devices
    // final devices = await _bluetoothPrint.getDevices();
    // setState(() {
    //   _devices = devices ?? [];
    // });
  }

  Future<void> _connectPrinter(dynamic device) async {
    try {
      // Bluetooth printer disabled - needs compatibility fix
      // bool? result = await _bluetoothPrint.connect(device);
      // if (result ?? false) {
      //   setState(() => _isConnected = true);
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('✓ Terhubung ke ${device.name}')),
      //   );
      // }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('❌ Gagal terhubung: $e')),
      // );
    }
  }

  Future<void> _printLabel() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Printer tidak terhubung')),
      );
      return;
    }

    setState(() => _isPrinting = true);

    try {
      // Generate QR code data
      final qrData = {
        'product_id': widget.product.id,
        'batch': widget.batch,
        'production_date': widget.productionDate,
        'product': widget.product.name,
      };

      // Format dates
      final prodDate = DateFormat('dd/MM/yyyy').format(
        DateTime.parse(widget.productionDate),
      );
      final expDate = widget.expiryDate != null
          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.expiryDate!))
          : 'N/A';

      // Generate QR code image (100x100 for thermal printer)
      final qrImage = await QrPainter(
        data: qrData.toString(),
        version: QrVersions.auto,
        gapless: true,
      ).toImageData(100);

      // Build print commands for thermal printer
      List<int> bytes = [];

      // Initialize printer
      bytes.addAll([0x1B, 0x40]); // ESC @

      // Set print density (for XP-4601BT)
      bytes.addAll([0x1D, 0x7C, 0x03]); // GS | (set density)

      // Print label (50mm x 20mm = 200 x 80 dots @ 203dpi)
      // Line 1: Product Name (bold)
      _addText(bytes, widget.product.name, bold: true, size: 2);
      _addNewline(bytes);

      // Line 2: Production Date
      _addText(bytes, 'Prod: $prodDate', size: 1);
      _addNewline(bytes);

      // Line 3: Expiry Date
      _addText(bytes, 'Exp: $expDate', size: 1);
      _addNewline(bytes);

      // Line 4: Batch (truncated)
      _addText(bytes, 'Batch: ${widget.batch.substring(0, 12)}', size: 1);
      _addNewline(bytes);

      // QR Code (80x80 for label)
      // Note: XP-4601BT doesn't support image printing directly
      // Alternative: Use BarTender integration or print QR as text

      // Line 5: Instagram
      _addText(bytes, '@papikopi_bdg', size: 1, centered: true);
      _addNewline(bytes);

      // Cut paper
      bytes.addAll([0x1D, 0x56, 0x00]); // GS V 0 (full cut)

      // Send to printer (disabled - needs compatibility fix)
      // await _bluetoothPrint.writeBytes(Uint8List.fromList(bytes));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Label berhasil dicetak (demo mode)')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  void _addText(List<int> bytes, String text,
      {bool bold = false, int size = 1, bool centered = false}) {
    // Set font size (1=normal, 2=double)
    if (size > 1) {
      bytes.addAll([0x1D, 0x21, 0x11]); // GS ! (double height & width)
    }

    // Set alignment
    if (centered) {
      bytes.addAll([0x1B, 0x61, 0x01]); // ESC a 1 (center)
    }

    // Add text
    bytes.addAll(text.codeUnits);

    // Reset alignment
    if (centered) {
      bytes.addAll([0x1B, 0x61, 0x00]); // ESC a 0 (left)
    }

    // Reset font size
    if (size > 1) {
      bytes.addAll([0x1D, 0x21, 0x00]); // GS ! (normal)
    }
  }

  void _addNewline(List<int> bytes) {
    bytes.addAll([0x0A]); // LF
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🖨️ Cetak Label',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Product Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Produk: ${widget.product.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Batch: ${widget.batch}'),
                  Text(
                    'Produksi: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.productionDate))}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Printer Selection
            if (!_isConnected) ...[
              const Text(
                'Hubungkan Printer:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_devices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    '⚠️ Tidak ada printer ditemukan. Pastikan printer Bluetooth sudah dipasangkan.',
                    style: TextStyle(fontSize: 12),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _devices.map((device) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          onPressed: () => _connectPrinter(device),
                          child: Text(device.name ?? 'Unknown'),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('✓ Printer terhubung')),
                    TextButton(
                      onPressed: () => setState(() => _isConnected = false),
                      child: const Text('Ubah'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Print Button
            SizedBox(
              width: double.maxFinite,
              child: ElevatedButton.icon(
                onPressed: _isConnected && !_isPrinting ? _printLabel : null,
                icon: _isPrinting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print),
                label: Text(_isPrinting ? 'Sedang mencetak...' : 'Cetak Sekarang'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
