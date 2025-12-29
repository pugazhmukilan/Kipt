import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/product_with_details.dart';
import '../models/rental_data.dart';
import '../../core/utils/date_utils.dart' as utils;
import '../../core/constants/app_constants.dart';

class PdfService {
  // Professional whitepaper color scheme using app theme
  static const PdfColor primaryAccent = PdfColor.fromInt(0xFF4ECDC4); // App theme teal/cyan
  static const PdfColor darkAccent = PdfColor.fromInt(0xFF3DB5AD); // Darker teal
  static const PdfColor charcoalGray = PdfColor.fromInt(0xFF2C3E50); // Dark text
  static const PdfColor mediumGray = PdfColor.fromInt(0xFF95A5A6); // Medium gray
  static const PdfColor lightGray = PdfColor.fromInt(0xFFF8F9FA); // Very light background
  static const PdfColor borderGray = PdfColor.fromInt(0xFFE0E0E0); // Subtle borders
  
  Future<File> generateProductPdf(ProductWithDetails productWithDetails) async {
    final pdf = pw.Document();
    final product = productWithDetails.product;
    
    // Load app logo
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/light_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print('Error loading logo: $e');
    }
    
    // Separate images and PDFs
    final imageAttachments = productWithDetails.attachments
        .where((a) => a.imageType != AppConstants.imageTypePdf)
        .toList();
    final pdfAttachments = productWithDetails.attachments
        .where((a) => a.imageType == AppConstants.imageTypePdf)
        .toList();
    
    // Pre-load all images before building the PDF
    final loadedImages = await _loadAllImages(imageAttachments);
    
    // Main document page with professional layout
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => [
          // Professional header with logo and branding
          _buildProfessionalHeader(logoImage, product.name),
          
          pw.SizedBox(height: 30),
          
          // Main content container with padding
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Document title and metadata
                _buildDocumentTitle(product),
                
                pw.SizedBox(height: 25),
                
                // Key information box
                _buildKeyInformationBox(product),
                
                pw.SizedBox(height: 25),
                
                // Product details section
                _buildProductDetailsSection(product),
                
                // Rental information (if applicable)
                if (product.category == 'House Rental' && product.rentalData != null) ...[
                  pw.SizedBox(height: 25),
                  _buildRentalInformationSection(product.rentalData!),
                ],
                
                // Attachments summary
                if (loadedImages.isNotEmpty || pdfAttachments.isNotEmpty) ...[
                  pw.SizedBox(height: 25),
                  _buildAttachmentsSummary(loadedImages.length, pdfAttachments.length),
                ],
                
                // Notes section
                if (productWithDetails.notes.isNotEmpty) ...[
                  pw.SizedBox(height: 25),
                  _buildNotesSection(productWithDetails.notes),
                ],
              ],
            ),
          ),
        ],
        footer: (context) => _buildProfessionalFooter(context, logoImage),
      ),
    );
    
    // Add professional image pages
    for (int i = 0; i < loadedImages.length; i++) {
      final imageData = loadedImages[i];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Column(
              children: [
                // Header
                _buildImagePageHeader(logoImage, i + 1, loadedImages.length, product.name),
                
                // Image content
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(30),
                    color: PdfColors.white,
                    child: imageData['image'] != null
                        ? pw.Center(
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfService.mediumGray, width: 1),
                                boxShadow: [
                                  pw.BoxShadow(
                                    color: PdfColors.grey400,
                                    offset: const PdfPoint(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: pw.Image(
                                imageData['image'],
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                          )
                        : _buildErrorBox(imageData['error'] ?? 'Failed to load image'),
                  ),
                ),
                
                // Footer
                _buildSimpleFooter(context),
              ],
            );
          },
        ),
      );
    }
    
    // Add PDF attachments with professional rendering
    for (int i = 0; i < pdfAttachments.length; i++) {
      try {
        final pdfAttachment = pdfAttachments[i];
        final pdfPath = pdfAttachment.imagePath;
        final pdfFile = File(pdfPath);
        
        if (await pdfFile.exists()) {
          // Add separator page
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.zero,
              build: (context) {
                return pw.Column(
                  children: [
                    _buildImagePageHeader(logoImage, i + 1, pdfAttachments.length, 'PDF Attachment'),
                    pw.Expanded(
                      child: pw.Center(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(40),
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.all(20),
                                decoration: pw.BoxDecoration(
                                  color: PdfService.lightGray,
                                  borderRadius: pw.BorderRadius.circular(12),
                                  border: pw.Border.all(color: PdfService.primaryAccent, width: 2),
                                ),
                                child: pw.Icon(
                                  pw.IconData(0xe24d), // PDF icon
                                  size: 80,
                                  color: PdfService.primaryAccent,
                                ),
                              ),
                              pw.SizedBox(height: 20),
                              pw.Text(
                                'PDF Document Attachment',
                                style: pw.TextStyle(
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfService.charcoalGray,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 10),
                              pw.Text(
                                'Following pages contain the attached PDF document',
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  color: PdfColors.grey700,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildSimpleFooter(context),
                  ],
                );
              },
            ),
          );
          
          // Render PDF pages
          try {
            final pdfBytes = await pdfFile.readAsBytes();
            final pageImages = Printing.raster(pdfBytes, dpi: 150);
            
            int pageNum = 1;
            await for (final page in pageImages) {
              final imageBytes = await page.toPng();
              final image = pw.MemoryImage(imageBytes);
              
              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  margin: pw.EdgeInsets.zero,
                  build: (context) {
                    return pw.Column(
                      children: [
                        _buildPDFPageHeader(logoImage, pageNum, 'PDF Attachment ${i + 1}'),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(20),
                            color: PdfColors.white,
                            child: pw.Center(
                              child: pw.Image(image, fit: pw.BoxFit.contain),
                            ),
                          ),
                        ),
                        _buildSimpleFooter(context),
                      ],
                    );
                  },
                ),
              );
              pageNum++;
            }
          } catch (renderError) {
            print('Error rendering PDF pages: $renderError');
            pdf.addPage(_buildErrorPage(logoImage, 'Could not render PDF document', 
              'The PDF attachment exists but could not be rendered in this export.'));
          }
        } else {
          pdf.addPage(_buildErrorPage(logoImage, 'PDF Not Found', 
            'The PDF attachment could not be located.'));
        }
      } catch (e) {
        print('Error adding PDF attachment ${i + 1}: $e');
        pdf.addPage(_buildErrorPage(logoImage, 'Error Loading PDF', 
          'An error occurred while processing the PDF attachment.'));
      }
    }
    
    // Save PDF
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/product_${product.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }
  
  /// Load all images from attachment file paths
  Future<List<Map<String, dynamic>>> _loadAllImages(List<dynamic> attachments) async {
    final List<Map<String, dynamic>> loadedImages = [];
    
    for (int i = 0; i < attachments.length; i++) {
      try {
        final attachment = attachments[i];
        final imagePath = attachment.imagePath as String;
        final file = File(imagePath);
        
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final image = pw.MemoryImage(bytes);
          
          loadedImages.add({
            'image': image,
            'path': imagePath,
            'index': i + 1,
          });
        } else {
          loadedImages.add({
            'image': null,
            'error': 'Image file not found',
            'path': imagePath,
            'index': i + 1,
          });
        }
      } catch (e) {
        print('Error loading image ${i + 1} for PDF: $e');
        loadedImages.add({
          'image': null,
          'error': 'Failed to load image: $e',
          'index': i + 1,
        });
      }
    }
    
    return loadedImages;
  }
  
  // ========== PROFESSIONAL WHITEPAPER LAYOUT BUILDERS ==========
  
  /// Builds a clean, professional cover-style header
  pw.Widget _buildProfessionalHeader(pw.MemoryImage? logoImage, String productName) {
    return pw.Container(
      color: PdfColors.white,
      padding: const pw.EdgeInsets.fromLTRB(50, 60, 50, 40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo
          if (logoImage != null)
            pw.Container(
              height: 50,
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            )
          else
            pw.Text(
              AppConstants.appName,
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfService.charcoalGray,
                letterSpacing: 2,
              ),
            ),
          
          pw.SizedBox(height: 50),
          
          // Orange accent line
          pw.Container(
            width: 60,
            height: 4,
            color: PdfService.primaryAccent,
          ),
          
          pw.SizedBox(height: 20),
          
          // Document title
          pw.Text(
            'PRODUCT INFORMATION',
            style: pw.TextStyle(
              fontSize: 36,
              fontWeight: pw.FontWeight.bold,
              color: PdfService.charcoalGray,
              letterSpacing: 1,
            ),
          ),
          
          pw.SizedBox(height: 12),
          
          pw.Text(
            'Comprehensive Product Details & Documentation',
            style: pw.TextStyle(
              fontSize: 14,
              color: PdfService.mediumGray,
              letterSpacing: 0.5,
            ),
          ),
          
          pw.SizedBox(height: 40),
          
          // Date and document info
          pw.Row(
            children: [
              _buildMetadataItem('Generated', utils.DateTimeUtils.formatDisplayDate(DateTime.now())),
              pw.SizedBox(width: 40),
              _buildMetadataItem('Document Type', 'Product Record'),
            ],
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildMetadataItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfService.mediumGray,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfService.charcoalGray,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  /// Builds document title section with section number
  pw.Widget _buildDocumentTitle(dynamic product) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Section number with orange
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              '01',
              style: pw.TextStyle(
                fontSize: 48,
                fontWeight: pw.FontWeight.bold,
                color: PdfService.primaryAccent,
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PRODUCT OVERVIEW',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfService.primaryAccent,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: 80,
                    height: 2,
                    color: PdfService.primaryAccent,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 25),
        
        // Product name - large and bold
        pw.Text(
          product.name,
          style: pw.TextStyle(
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
            color: PdfService.charcoalGray,
            letterSpacing: 0.5,
          ),
        ),
        
        pw.SizedBox(height: 12),
        
        // Category badge
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfService.lightGray,
            border: pw.Border.all(color: PdfService.borderGray, width: 1),
          ),
          child: pw.Text(
            product.category.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfService.charcoalGray,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
  
  /// Builds key information in clean grid layout
  pw.Widget _buildKeyInformationBox(dynamic product) {
    final purchaseDate = utils.DateTimeUtils.parseISO(product.purchaseDate);
    final expiryDate = utils.DateTimeUtils.parseISO(product.expiryDate);
    
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfService.primaryAccent, width: 4),
        ),
        color: PdfService.lightGray,
      ),
      padding: const pw.EdgeInsets.all(30),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'KEY INFORMATION',
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfService.charcoalGray,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildInfoColumn(
                  'Purchase Date',
                  purchaseDate != null 
                      ? utils.DateTimeUtils.formatDisplayDate(purchaseDate)
                      : product.purchaseDate,
                ),
              ),
              if (product.category != 'House Rental')
                pw.Expanded(
                  child: _buildInfoColumn(
                    'Expiry Date',
                    expiryDate != null 
                        ? utils.DateTimeUtils.formatDisplayDate(expiryDate)
                        : product.expiryDate,
                  ),
                ),
              if (product.warrantyMonths != null)
                pw.Expanded(
                  child: _buildInfoColumn(
                    'Warranty Period',
                    '${product.warrantyMonths} Months',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildInfoColumn(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfService.mediumGray,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            color: PdfService.charcoalGray,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  /// Builds product details in professional table format
  pw.Widget _buildProductDetailsSection(dynamic product) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DETAILED SPECIFICATIONS',
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfService.charcoalGray,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        
        pw.SizedBox(height: 15),
        
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfService.borderGray, width: 1),
          ),
          child: pw.Column(
            children: [
              _buildCleanDetailRow('Product Name', product.name, true),
              _buildCleanDetailRow('Category', product.category, false),
              _buildCleanDetailRow(
                'Purchase Date',
                () {
                  final date = utils.DateTimeUtils.parseISO(product.purchaseDate);
                  return date != null 
                      ? utils.DateTimeUtils.formatDisplayDate(date)
                      : product.purchaseDate;
                }(),
                true,
              ),
              if (product.category != 'House Rental')
                _buildCleanDetailRow(
                  'Expiry Date',
                  () {
                    final date = utils.DateTimeUtils.parseISO(product.expiryDate);
                    return date != null 
                        ? utils.DateTimeUtils.formatDisplayDate(date)
                        : product.expiryDate;
                  }(),
                  false,
                ),
              if (product.warrantyMonths != null)
                _buildCleanDetailRow('Warranty Period', '${product.warrantyMonths} months', true),
            ],
          ),
        ),
      ],
    );
  }
  
  pw.Widget _buildCleanDetailRow(String label, String value, bool isAlternate) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: pw.BoxDecoration(
        color: isAlternate ? PdfService.lightGray : PdfColors.white,
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfService.mediumGray,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                color: PdfService.charcoalGray,
                fontWeight: pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds rental information section with section number
  pw.Widget _buildRentalInformationSection(RentalData rentalData) {
    final fields = <Map<String, String>>[];
    
    if (rentalData.tenantName != null) fields.add({'label': 'Tenant Name', 'value': rentalData.tenantName!});
    if (rentalData.tenantPhone != null) fields.add({'label': 'Contact Phone', 'value': rentalData.tenantPhone!});
    if (rentalData.tenantEmail != null) fields.add({'label': 'Email Address', 'value': rentalData.tenantEmail!});
    if (rentalData.propertyAddress != null) fields.add({'label': 'Property Address', 'value': rentalData.propertyAddress!});
    if (rentalData.propertyType != null) fields.add({'label': 'Property Type', 'value': rentalData.propertyType!});
    if (rentalData.monthlyRent != null) fields.add({'label': 'Monthly Rent', 'value': '₹${rentalData.monthlyRent}'});
    if (rentalData.securityDeposit != null) fields.add({'label': 'Security Deposit', 'value': '₹${rentalData.securityDeposit}'});
    if (rentalData.leaseStartDate != null) fields.add({'label': 'Lease Start Date', 'value': rentalData.leaseStartDate!});
    if (rentalData.leaseEndDate != null) fields.add({'label': 'Lease End Date', 'value': rentalData.leaseEndDate!});
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Section number
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              '02',
              style: pw.TextStyle(
                fontSize: 48,
                fontWeight: pw.FontWeight.bold,
                color: PdfService.primaryAccent,
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RENTAL DETAILS',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfService.primaryAccent,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: 80,
                    height: 2,
                    color: PdfService.primaryAccent,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 20),
        
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfService.borderGray, width: 1),
          ),
          child: pw.Column(
            children: fields.asMap().entries.map((entry) {
              return _buildCleanDetailRow(entry.value['label']!, entry.value['value']!, entry.key % 2 == 0);
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  /// Builds attachments summary in clean format
  pw.Widget _buildAttachmentsSummary(int imageCount, int pdfCount) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ATTACHMENTS',
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfService.charcoalGray,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        
        pw.SizedBox(height: 15),
        
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfService.primaryAccent, width: 4),
            ),
            color: PdfService.lightGray,
          ),
          padding: const pw.EdgeInsets.all(25),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (imageCount > 0)
                _buildAttachmentRow(
                  '$imageCount Product Image${imageCount > 1 ? 's' : ''}',
                  'Full-size images available on following pages',
                ),
              if (imageCount > 0 && pdfCount > 0)
                pw.SizedBox(height: 20),
              if (pdfCount > 0)
                _buildAttachmentRow(
                  '$pdfCount PDF Document${pdfCount > 1 ? 's' : ''}',
                  'Additional documents included in this export',
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  pw.Widget _buildAttachmentRow(String title, String description) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfService.charcoalGray,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          description,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfService.mediumGray,
          ),
        ),
      ],
    );
  }
  
  /// Builds notes section
  pw.Widget _buildNotesSection(List<dynamic> notes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'NOTES & OBSERVATIONS',
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfService.charcoalGray,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        
        pw.SizedBox(height: 15),
        
        ...notes.asMap().entries.map((entry) {
          final note = entry.value;
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 15),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfService.primaryAccent, width: 3),
              ),
              color: PdfService.lightGray,
            ),
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'NOTE ${entry.key + 1}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfService.primaryAccent,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  note.content,
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfService.charcoalGray,
                    height: 1.5,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  utils.DateTimeUtils.formatDisplayDate(
                    DateTime.parse(note.createdAt),
                  ),
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfService.mediumGray,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
  
  /// Builds minimal professional footer
  pw.Widget _buildProfessionalFooter(pw.Context context, pw.MemoryImage? logoImage) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfService.borderGray, width: 1)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  height: 18,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 12),
              ],
              pw.Text(
                AppConstants.appName,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfService.charcoalGray,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Text(
            'Page ${context.pageNumber}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfService.mediumGray,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds clean header for image pages
  pw.Widget _buildImagePageHeader(pw.MemoryImage? logoImage, int imageNumber, int totalImages, String productName) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(50, 30, 50, 25),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border(bottom: pw.BorderSide(color: PdfService.borderGray, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null)
                pw.Container(
                  height: 25,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                )
              else
                pw.Text(
                  AppConstants.appName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfService.charcoalGray,
                  ),
                ),
              pw.SizedBox(height: 8),
              pw.Container(
                constraints: const pw.BoxConstraints(maxWidth: 350),
                child: pw.Text(
                  productName,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfService.mediumGray,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfService.primaryAccent,
            ),
            child: pw.Text(
              'IMAGE $imageNumber/$totalImages',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds header for PDF pages
  pw.Widget _buildPDFPageHeader(pw.MemoryImage? logoImage, int pageNumber, String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(50, 30, 50, 25),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border(bottom: pw.BorderSide(color: PdfService.borderGray, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null)
                pw.Container(
                  height: 25,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                )
              else
                pw.Text(
                  AppConstants.appName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfService.charcoalGray,
                  ),
                ),
              pw.SizedBox(height: 8),
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfService.mediumGray,
                ),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfService.darkAccent,
            ),
            child: pw.Text(
              'PAGE $pageNumber',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds simple footer for image/PDF pages
  pw.Widget _buildSimpleFooter(pw.Context context) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfService.borderGray, width: 1)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            AppConstants.appName,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfService.charcoalGray,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfService.mediumGray,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds error box widget
  pw.Widget _buildErrorBox(String message) {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(40),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfService.borderGray, width: 2),
          color: PdfService.lightGray,
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              'ERROR',
              style: pw.TextStyle(
                fontSize: 11,
                color: PdfService.mediumGray,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Text(
              message,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfService.charcoalGray,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  /// Builds error page
  pw.Page _buildErrorPage(pw.MemoryImage? logoImage, String title, String message) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) {
        return pw.Column(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(50, 30, 50, 25),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border(bottom: pw.BorderSide(color: PdfService.borderGray, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      height: 25,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Text(
                      AppConstants.appName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfService.charcoalGray,
                      ),
                    ),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Center(
                child: pw.Container(
                  margin: const pw.EdgeInsets.all(60),
                  padding: const pw.EdgeInsets.all(50),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfService.borderGray, width: 2),
                    color: PdfService.lightGray,
                  ),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'ERROR',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfService.primaryAccent,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfService.charcoalGray,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 15),
                      pw.Text(
                        message,
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfService.mediumGray,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildSimpleFooter(context),
          ],
        );
      },
    );
  }
  
  Future<void> sharePdf(File pdfFile) async {
    await Printing.sharePdf(
      bytes: await pdfFile.readAsBytes(),
      filename: pdfFile.path.split('/').last,
    );
  }
  
  Future<void> printPdf(File pdfFile) async {
    await Printing.layoutPdf(
      onLayout: (format) => pdfFile.readAsBytes(),
    );
  }
}



