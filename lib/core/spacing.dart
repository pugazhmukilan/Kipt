/// Google Material Design 3 spacing system (4dp base unit).
/// https://m3.material.io/styles/layout/spacing
import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4;    // 1×
  static const double sm = 8;    // 2×
  static const double md = 12;   // 3×
  static const double lg = 16;   // 4× — standard inset / horizontal page margin
  static const double xl = 20;   // 5×
  static const double xxl = 24;  // 6× — section gap / card vertical padding
  static const double xxxl = 32; // 8× — large section gap
  static const double huge = 40; // 10×
  static const double massive = 48; // 12×
  static const double giant = 56;   // 14×
  static const double colossal = 64; // 16×

  // Semantic aliases for common use-cases
  static const double pageMargin = lg;        // 16
  static const double cardPadding = lg;       // 16
  static const double cardInnerGap = md;      // 12
  static const double listItemGap = lg;       // 16 between list items
  static const double sectionGap = xxl;       // 24 between major sections
  static const double inlineGap = sm;         // 8 between inline elements
  static const double chipGap = sm;           // 8 between chips
  static const double iconTextGap = sm;       // 8 icon↔text
  static const double formFieldGap = lg;      // 16 between form fields
  static const double bottomSheetPadding = xl; // 20 bottom sheet content
  static const double fabMargin = lg;         // 16 FAB from screen edge
  static const double searchBarVertical = md; // 12 above/below search bar
  static const double appBarTitleSpacing = lg; // 16 logo↔title
}

extension Spacing on num {
  EdgeInsets get all => EdgeInsets.all(toDouble());
  EdgeInsets get h => EdgeInsets.symmetric(horizontal: toDouble());
  EdgeInsets get v => EdgeInsets.symmetric(vertical: toDouble());
  EdgeInsets get hPage => EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin);
  EdgeInsets get vSection => EdgeInsets.symmetric(vertical: AppSpacing.sectionGap);
  EdgeInsets get onlyT => EdgeInsets.only(top: toDouble());
  EdgeInsets get onlyB => EdgeInsets.only(bottom: toDouble());
  EdgeInsets get onlyL => EdgeInsets.only(left: toDouble());
  EdgeInsets get onlyR => EdgeInsets.only(right: toDouble());
  EdgeInsets get tl => EdgeInsets.only(top: toDouble(), left: AppSpacing.pageMargin);
  EdgeInsets get tr => EdgeInsets.only(top: toDouble(), right: AppSpacing.pageMargin);
  EdgeInsets get bl => EdgeInsets.only(bottom: toDouble(), left: AppSpacing.pageMargin);
  EdgeInsets get br => EdgeInsets.only(bottom: toDouble(), right: AppSpacing.pageMargin);
  EdgeInsets get horizontalPage => EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin);
  EdgeInsets get verticalSection => EdgeInsets.symmetric(vertical: AppSpacing.sectionGap);
  SizedBox get w => SizedBox(width: toDouble());
  SizedBox get hBox => SizedBox(height: toDouble());
}