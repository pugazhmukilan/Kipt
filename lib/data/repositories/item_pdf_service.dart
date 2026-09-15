import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_constants.dart';
import '../models/attachment.dart';
import '../models/item_field.dart';
import '../models/item_with_details.dart';

/// Generates a shareable, printable PDF export of a single item.
///
/// Every field row is rendered so the export never silently drops data —
/// including PASSWORD rows. Decrypted password values must be supplied via
/// [buildItemPdf]'s [passwordValues] map (after a fresh biometric/PIN check);
/// a password without a value renders as a masked "******** (protected)" row.
/// Photos are laid out in a 2-per-row grid, and any attached PDFs are
/// rasterized page by page so the whole export is one self-contained PDF file.
class ItemPdfService {
  // Warm neumorphic palette mirrored from AppTheme (light mode).
  static const _accent = PdfColor.fromInt(0xFF7FA37A);
  static const _accentDeep = PdfColor.fromInt(0xFF3D5A3A);
  static const _surface = PdfColor.fromInt(0xFFEDE7DE);
  static const _textPrimary = PdfColor.fromInt(0xFF4A453D);
  static const _textSecondary = PdfColor.fromInt(0xFF8C8776);
  static const _outline = PdfColor.fromInt(0xFFB3AB9B);
  static const _outlineVariant = PdfColor.fromInt(0xFFC4BCAD);
  static const _dateAccent = PdfColor.fromInt(0xFF6E94A6);
  static const _passwordAccent = PdfColor.fromInt(0xFFC98A3D);
  static const _passwordRowTint = PdfColor.fromInt(0xFFF6EBD9);
  static const _maskedPassword = '******** (protected)';

  /// Photos rendered per page (2 columns x 3 rows).
  static const _photosPerRow = 2;
  static const _photosPerPage = 6;
  static const _photoRowHeight = 190.0;

  static pw.Font? _cachedBaseFont;
  static pw.MemoryImage? _cachedLogo;

  pw.MemoryImage? _logo;

  /// Builds a complete PDF export for [details] and returns the raw bytes.
  ///
  /// [passwordValues] maps PASSWORD field ids ([ItemField.id]) to their
  /// decrypted values. Password rows are always rendered — the decrypted value
  /// when supplied, otherwise masked — so the export never loses data.
  Future<Uint8List> buildItemPdf(
    ItemWithDetails details, {
    Map<int, String>? passwordValues,
  }) async {
    final base = await _loadBaseFont();
    _logo = await _loadLogo();

    final photos = await _loadAvailablePhotos(details.attachments);
    final documents = await _rasterizeDocuments(details.attachments);

    final doc = pw.Document(
      title: details.item.title,
      author: AppConstants.appName,
      subject: details.item.title,
      theme: pw.ThemeData.withFont(base: base),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(context, details.item.title),
        footer: _buildFooter,
        build: (context) => _summarySection(details, passwordValues),
      ),
    );

    final photoPageCount =
        (photos.length / _photosPerPage).ceil();
    for (var start = 0; start < photos.length; start += _photosPerPage) {
      final chunk = photos.sublist(
        start,
        math.min(start + _photosPerPage, photos.length),
      );
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(40),
          header: (context) => _buildHeader(context, details.item.title),
          footer: _buildFooter,
          build: (context) => [
            _sectionHeading('Photos'),
            pw.SizedBox(height: 4),
            pw.Text(
              '${photos.length} photo${photos.length == 1 ? '' : 's'}'
              ' - page ${start ~/ _photosPerPage + 1} of $photoPageCount',
              style: _captionStyle,
            ),
            pw.SizedBox(height: 12),
            _photoGrid(chunk, photos.length),
          ],
        ),
      );
    }

    for (final document in documents) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(40),
          header: (context) =>
              _buildHeader(context, '${details.item.title} - Document'),
          footer: _buildFooter,
          build: (context) => _documentSection(document),
        ),
      );
    }

    return doc.save();
  }

  /// Writes [bytes] to a temporary PDF file and returns its path, ready to be
  /// shared or opened by the system PDF viewer.
  Future<String> writeShareFile(Uint8List bytes, String title) async {
    final dir = await getTemporaryDirectory();
    final safe = title.trim().replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final name = '${safe.isEmpty ? 'item' : safe}.pdf';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // ---------------------------------------------------------------------------
  // Content builders
  // ---------------------------------------------------------------------------

  List<pw.Widget> _summarySection(
    ItemWithDetails details,
    Map<int, String>? passwordValues,
  ) {
    return [
      pw.Text(
        details.item.title,
        style: pw.TextStyle(
          fontSize: 26,
          color: _accentDeep,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      if (details.categoryName != null)
        pw.Padding(
          padding: pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            details.categoryName!,
            style: pw.TextStyle(
              fontSize: 13,
              color: _accent,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      if (details.item.tags.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        _tagWrap(details.item.tags),
      ],
      pw.SizedBox(height: 22),
      _sectionHeading('Item Details'),
      pw.SizedBox(height: 10),
      _buildFieldTable(details.fields, passwordValues),
      if (details.item.notes != null && details.item.notes!.isNotEmpty) ...[
        pw.SizedBox(height: 22),
        _sectionHeading('Notes'),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _surface,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Text(
            details.item.notes!,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 11,
              lineSpacing: 4,
            ),
          ),
        ),
      ],
      pw.SizedBox(height: 22),
      pw.Text(
        'Created ${_formatDate(details.item.createdAt)}'
        ' - Updated ${_formatDate(details.item.updatedAt)}',
        style: _captionStyle,
      ),
    ];
  }

  pw.Widget _tagWrap(List<String> tags) {
    return pw.Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags
          .map(
            (tag) => pw.Container(
              padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: _surface,
                border: pw.Border.all(color: _outline, width: 0.6),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                tag,
                style: pw.TextStyle(fontSize: 9, color: _textSecondary),
              ),
            ),
          )
          .toList(),
    );
  }

  /// Builds the 3-column [Type | Field | Value] details table. Every field is
  /// included (text, date AND password rows) with color-coded type badges and
  /// an amber tint on password rows for quick visual differentiation. Password
  /// values are shown decrypted when supplied in [passwordValues], otherwise
  /// masked — rows are never dropped.
  pw.Widget _buildFieldTable(
    List<ItemField> fields,
    Map<int, String>? passwordValues,
  ) {
    final rows = fieldRows(fields, passwordValues);
    if (rows.isEmpty) return pw.SizedBox.shrink();

    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(color: _outline, width: 0.6),
        bottom: pw.BorderSide(color: _outline, width: 0.6),
        verticalInside: pw.BorderSide(color: _outline, width: 0.6),
        horizontalInside: pw.BorderSide(color: _outlineVariant, width: 0.4),
      ),
      columnWidths: {
        0: pw.FlexColumnWidth(0.7),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(2.4),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _accent),
          children: [
            _tableHeaderCell('TYPE'),
            _tableHeaderCell('FIELD'),
            _tableHeaderCell('VALUE'),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            decoration: row.isPassword
                ? pw.BoxDecoration(color: _passwordRowTint)
                : null,
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              _typeBadge(row),
              _fieldLabelCell(row),
              _valueCell(row),
            ],
          ),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _typeBadge(PdfFieldRow row) {
    final (bg, fg) = switch (row.type) {
      FieldType.text => (_outline, PdfColors.white),
      FieldType.date => (_dateAccent, PdfColors.white),
      FieldType.password => (_passwordAccent, PdfColors.white),
    };
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          row.typeLabel,
          style: pw.TextStyle(
            color: fg,
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static pw.Widget _fieldLabelCell(PdfFieldRow row) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        row.fieldLabel,
        style: pw.TextStyle(
          color: _textPrimary,
          fontSize: 10,
          fontWeight: row.isPassword
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _valueCell(PdfFieldRow row) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        row.value,
        style: row.valueHidden
            ? pw.TextStyle(
                color: _textSecondary,
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
              )
            : pw.TextStyle(
                color: row.isPassword ? _accentDeep : _textPrimary,
                fontSize: 10,
                fontWeight: row.isPassword
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Field rows (kept testable so PDF content can be verified without parsing)
  // ---------------------------------------------------------------------------

  /// Flattens [fields] into the exact rows rendered in the export table.
  ///
  /// [passwordValues] carries the decrypted PASSWORD values (keys = field id).
  /// Every field — including PASSWORD rows — is present; a password without a
  /// supplied value renders as [maskedPassword].
  @visibleForTesting
  static List<PdfFieldRow> fieldRows(
    List<ItemField> fields,
    Map<int, String>? passwordValues,
  ) {
    return fields.map((field) {
      final value = switch (field.fieldType) {
        FieldType.text => field.value,
        FieldType.date => field.parsedDate != null
            ? DateFormat(AppConstants.dateFormatDisplay).format(field.parsedDate!)
            : field.value,
        FieldType.password => _passwordDisplay(field, passwordValues),
      };
      return PdfFieldRow(
        type: field.fieldType,
        typeLabel: field.fieldType.displayLabel,
        fieldLabel: field.label,
        value: value,
        isPassword: field.fieldType == FieldType.password,
        valueHidden: field.fieldType == FieldType.password &&
            value == _maskedPassword,
      );
    }).toList();
  }

  static String _passwordDisplay(
    ItemField field,
    Map<int, String>? passwordValues,
  ) {
    final value = field.id != null ? (passwordValues?[field.id]) : null;
    if (value != null && value.isNotEmpty) return value;
    return _maskedPassword;
  }

  pw.Widget _photoGrid(List<_PhotoData> photos, int total) {
    final rows = <pw.Widget>[];
    for (var i = 0; i < photos.length; i += _photosPerRow) {
      final left = photos[i];
      final right = i + 1 < photos.length ? photos[i + 1] : null;
      rows.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 16),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _photoCell(left, total)),
              if (right != null) ...[
                pw.SizedBox(width: 12),
                pw.Expanded(child: _photoCell(right, total)),
              ],
            ],
          ),
        ),
      );
    }
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: rows,
    );
  }

  pw.Widget _photoCell(_PhotoData photo, int total) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: double.infinity,
          height: _photoRowHeight,
          child: pw.ClipRRect(
            horizontalRadius: 12,
            verticalRadius: 12,
            child: pw.Image(pw.MemoryImage(photo.bytes), fit: pw.BoxFit.cover),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Photo ${photo.index} of $total', style: _captionStyle),
      ],
    );
  }

  List<pw.Widget> _documentSection(_RasterDoc document) {
    return [
      _sectionHeading('Attached Document'),
      pw.SizedBox(height: 4),
      pw.Text(document.fileName, style: _captionStyle),
      pw.SizedBox(height: 12),
      for (var i = 0; i < document.pages.length; i++) ...[
        pw.Text(
          'Page ${i + 1} of ${document.pages.length}',
          style: _captionStyle,
        ),
        pw.SizedBox(height: 4),
        pw.Image(
          pw.MemoryImage(document.pages[i].pngBytes),
          fit: pw.BoxFit.contain,
          width: double.infinity,
        ),
        if (i != document.pages.length - 1) pw.SizedBox(height: 16),
      ],
    ];
  }

  pw.Widget _sectionHeading(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _accent, width: 1.2),
        ),
      ),
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 12,
          color: _accentDeep,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _buildHeader(pw.Context context, String pageTitle) {
    final logo = _logo;
    return pw.Container(
      color: _accent,
      padding: pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (logo != null) ...[
                pw.SizedBox(
                  width: 20,
                  height: 20,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 8),
              ],
              pw.Text(
                AppConstants.appName,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          pw.Flexible(
            child: pw.Text(
              pageTitle,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _outlineVariant, width: 0.6),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Exported from ${AppConstants.appName}'
            ' - ${_formatDate(DateTime.now())}',
            style: _captionStyle,
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: _captionStyle,
          ),
        ],
      ),
    );
  }

  static const _captionStyle = pw.TextStyle(
    fontSize: 8.5,
    color: _textSecondary,
  );

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<List<_PhotoData>> _loadAvailablePhotos(
    List<Attachment> attachments,
  ) async {
    final photos = <_PhotoData>[];
    var index = 0;
    for (final attachment in attachments.where((a) => a.isPhoto)) {
      final file = File(attachment.path);
      if (!await file.exists()) continue;
      try {
        final bytes = await file.readAsBytes();
        index++;
        photos.add(_PhotoData(bytes: bytes, index: index));
      } catch (_) {
        // Unreadable image file - skip it.
      }
    }
    return photos;
  }

  Future<List<_RasterDoc>> _rasterizeDocuments(
    List<Attachment> attachments,
  ) async {
    final docs = <_RasterDoc>[];
    for (final attachment in attachments.where((a) => !a.isPhoto)) {
      final file = File(attachment.path);
      if (!await file.exists()) continue;
      try {
        final bytes = await file.readAsBytes();
        final pages = <_RasterDocPage>[];
        await for (final raster in Printing.raster(bytes, dpi: 144)) {
          final png = await raster.toPng();
          pages.add(_RasterDocPage(pngBytes: png));
        }
        if (pages.isNotEmpty) {
          docs.add(
            _RasterDoc(fileName: p.basename(attachment.path), pages: pages),
          );
        }
      } catch (_) {
        // Unsupported or non-PDF file: skip it.
      }
    }
    return docs;
  }

  static Future<pw.Font> _loadBaseFont() async {
    if (_cachedBaseFont != null) return _cachedBaseFont!;
    try {
      final data = await rootBundle.load('assets/fonts/Inter.ttf');
      if (data.lengthInBytes >= 4) {
        _cachedBaseFont = pw.Font.ttf(data);
        return _cachedBaseFont!;
      }
    } catch (_) {
      // Font asset unavailable (e.g. unit tests) - fall back to a built-in.
    }
    _cachedBaseFont = pw.Font.helvetica();
    return _cachedBaseFont!;
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo!;
    try {
      final data = await rootBundle.load('assets/light_logo.png');
      final bytes = data.buffer.asUint8List();
      const pngMagic = [0x89, 0x50, 0x4E, 0x47];
      final isPng = bytes.length >= 8 &&
          pngMagic.asMap().entries.every((e) => bytes[e.key] == e.value);
      if (isPng) {
        _cachedLogo = pw.MemoryImage(bytes);
      }
    } catch (_) {
      // Logo asset unavailable - the header simply omits the image.
    }
    return _cachedLogo;
  }

  static String _formatDate(DateTime date) {
    return DateFormat(AppConstants.dateFormatDisplay).format(date);
  }
}

class _PhotoData {
  final Uint8List bytes;
  final int index;

  const _PhotoData({
    required this.bytes,
    required this.index,
  });
}

class _RasterDoc {
  final String fileName;
  final List<_RasterDocPage> pages;

  const _RasterDoc({required this.fileName, required this.pages});
}

class _RasterDocPage {
  final Uint8List pngBytes;

  const _RasterDocPage({required this.pngBytes});
}

/// One rendered row of the export's field table (also used to unit-test that
/// no fields — including passwords — are silently dropped).
class PdfFieldRow {
  final FieldType type;
  final String typeLabel;
  final String fieldLabel;
  final String value;
  final bool isPassword;

  /// True when this is a password row rendered masked (no value supplied).
  final bool valueHidden;

  const PdfFieldRow({
    required this.type,
    required this.typeLabel,
    required this.fieldLabel,
    required this.value,
    required this.isPassword,
    required this.valueHidden,
  });
}