import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Full-screen PDF preview of an item export. Pages can be pinched/zoomed and
/// swiped; the built-in action bar also offers print and share.
class ItemPdfPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;

  const ItemPdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: PdfPreview(
        build: (format) => Future.value(bytes),
        pdfFileName: fileName,
        initialPageFormat: PdfPageFormat.a4,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}