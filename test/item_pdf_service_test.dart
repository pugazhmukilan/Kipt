import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/data/models/item.dart';
import 'package:warranty_vault/data/models/item_field.dart';
import 'package:warranty_vault/data/models/item_with_details.dart';
import 'package:warranty_vault/data/repositories/item_pdf_service.dart';

void main() {
  final service = ItemPdfService();

  ItemWithDetails buildDetails() {
    return ItemWithDetails(
      item: Item(
        id: 1,
        title: 'Netflix',
        categoryId: 1,
        tags: const ['Streaming', 'Annual'],
        notes: 'Renew before it lapses.',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 6, 15),
      ),
      categoryName: 'Tech',
      fields: const [
        ItemField(
          id: 1,
          itemId: 1,
          label: 'Username',
          fieldType: FieldType.text,
          value: 'me@example.com',
          sortOrder: 0,
        ),
        ItemField(
          id: 2,
          itemId: 1,
          label: 'Password',
          fieldType: FieldType.password,
          value: 'secure-ref',
          sortOrder: 1,
        ),
        ItemField(
          id: 3,
          itemId: 1,
          label: 'Renewal',
          fieldType: FieldType.date,
          value: '2026-12-31',
          reminderEnabled: true,
          sortOrder: 2,
        ),
      ],
      attachments: const [],
    );
  }

  void expectPdfMagic(Uint8List bytes) {
    expect(bytes, isNotEmpty);
    const magic = [0x25, 0x50, 0x44, 0x46]; // "%PDF"
    expect(
      bytes.length >= 4 &&
          magic.asMap().entries.every((e) => bytes[e.key] == e.value),
      isTrue,
    );
  }

  test('generates a valid PDF export', () async {
    final bytes = await service.buildItemPdf(buildDetails());
    expectPdfMagic(bytes);
  });

  test('generates a valid PDF when decrypted password values are supplied',
      () async {
    final bytes = await service.buildItemPdf(
      buildDetails(),
      passwordValues: const {2: 'MySecretPass123'},
    );
    expectPdfMagic(bytes);
  });

  test('creates a bounded safe filename for PDF previews', () {
    final name = service.fileNameForTitle(
      'A' * 120 + r' / warranty:receipt?*',
    );

    expect(name, endsWith('.pdf'));
    expect(name.length, lessThanOrEqualTo(84));
    expect(name, isNot(contains('/')));
    expect(name, isNot(contains(':')));
  });

  test(
      'fieldRows includes every field — passwords masked when no values given',
      () {
    final rows = ItemPdfService.fieldRows(buildDetails().fields, null);

    expect(rows.length, 3);
    expect(
      rows.map((r) => r.fieldLabel),
      containsAll(['Username', 'Password', 'Renewal']),
    );
    expect(rows.every((r) => !r.valueHidden), isFalse, reason: 'needs masked row');
    final password = rows.firstWhere((r) => r.isPassword);
    expect(password.valueHidden, isTrue);
    expect(password.value, contains('protected'));
  });

  test('fieldRows includes decrypted password values when provided', () {
    final rows =
        ItemPdfService.fieldRows(buildDetails().fields, const {2: 'MySecretPass123'});

    final password = rows.firstWhere((r) => r.isPassword);
    expect(password.valueHidden, isFalse);
    expect(password.value, 'MySecretPass123');

    final username = rows.firstWhere((r) => !r.isPassword && r.fieldLabel == 'Username');
    expect(username.value, 'me@example.com');

    final renewal = rows.firstWhere((r) => r.fieldLabel == 'Renewal');
    expect(renewal.value, 'Dec 31, 2026');
  });
}