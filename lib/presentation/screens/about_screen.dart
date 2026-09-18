import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Logo and Name
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/Kpit_for_darktheme.png'
                        : 'assets/Kpit_for_lighttheme.png',
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: colorScheme.primary,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 8),
                Text(
                  'Version ${AppConstants.appVersion}',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // What is the app
          _buildSection(
            context,
            icon: Icons.lightbulb_outline,
            title: 'What is this app?',
            content: 'This is your item vault. One card for every important thing you own — warranty, receipt, ID, or note — stored securely and offline on your device.',
          ),
          
          const SizedBox(height: 24),
          
          // Key Features
          _buildSection(
            context,
            icon: Icons.star_outline,
            title: 'Key Features',
            content: null,
            children: [
              _buildFeatureItem(
                context,
                icon: Icons.camera_alt_outlined,
                title: 'Smart Receipt Scanning',
                description: 'Capture bills and receipts with your camera. OCR technology automatically extracts dates and key details.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.notifications_outlined,
                title: 'Expiry Reminders',
                description: 'Get timely notifications before your items expire — warranties, IDs, subscriptions and more.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.backup_outlined,
                title: 'Backup & Restore',
                description: 'Safely export all your data as a ZIP file. Share or restore your warranties anytime. Your data is encrypted and secure.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.category_outlined,
                title: 'Smart Categories',
                description: 'Organize items into categories: Electronics, Appliances, IDs, Documents, and more. Filter and search easily.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.lock_outline,
                title: 'Biometric Security',
                description: 'Protect your data with fingerprint or PIN authentication. Your sensitive information stays private.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.cloud_off_outlined,
                title: '100% Offline',
                description: 'Works completely offline. No internet required. Your data never leaves your device unless you explicitly export it.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.attach_file_outlined,
                title: 'Multiple Attachments',
                description: 'Store multiple photos and PDFs per item — receipts, warranty cards, IDs, and more.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.home_work_outlined,
                title: 'Rental Management',
                description: 'Special mode for rental properties with tenant details, monthly rent tracking, deposit management, and lease dates.',
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // How to Use
          _buildSection(
            context,
            icon: Icons.help_outline,
            title: 'How to Use',
            content: null,
            children: [
              _buildStepItem(context, '1', 'Add an Item', 'Tap the + button on the home screen. Enter the item name and details or scan a receipt to auto-fill information.'),
              _buildStepItem(context, '2', 'Attach Documents', 'Add photos and PDFs of your receipt, warranty card, or ID. Multiple attachments supported.'),
              _buildStepItem(context, '3', 'Set Category & Expiry', 'Choose a category and set the warranty expiry date. The app will automatically calculate and track it.'),
              _buildStepItem(context, '4', 'Get Reminders', 'Enable notifications in Settings to receive alerts before warranties expire.'),
              _buildStepItem(context, '5', 'Search & Filter', 'Use the search bar or category filters on the home screen to quickly find any item.'),
              _buildStepItem(context, '6', 'View Details', 'Tap any item card to view complete details, edit information, or add notes.'),
              _buildStepItem(context, '7', 'Backup Regularly', 'Go to Settings > Backup & Restore > Create Backup to export all your data as a ZIP file.'),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Categories Explained
          _buildSection(
            context,
            icon: Icons.dashboard_outlined,
            title: 'Item Categories',
            content: null,
            children: [
              _buildCategoryItem(context, 'All', 'View all items across all categories'),
              _buildCategoryItem(context, 'Electronics', 'Phones, laptops, cameras, headphones, etc.'),
              _buildCategoryItem(context, 'Appliances', 'Washing machines, refrigerators, air conditioners, etc.'),
              _buildCategoryItem(context, 'Home Appliances', 'Kitchen appliances, vacuum cleaners, water purifiers, etc.'),
              _buildCategoryItem(context, 'Furniture', 'Beds, sofas, tables, wardrobes, etc.'),
              _buildCategoryItem(context, 'Vehicles', 'Cars, bikes, scooters and more'),
              _buildCategoryItem(context, 'Tools', 'Power tools, hand tools, equipment'),
              _buildCategoryItem(context, 'Rentals', 'Rental properties with tenant and lease management'),
              _buildCategoryItem(context, 'Others', 'Any other items you want to track'),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Settings & Options
          _buildSection(
            context,
            icon: Icons.settings_outlined,
            title: 'Settings & Customization',
            content: null,
            children: [
              _buildInfoItem(context, 'Theme', 'Choose between Light, Dark, or System theme'),
              _buildInfoItem(context, 'Default Warranty', 'Set the default warranty duration (12-60 months) for new items'),
              _buildInfoItem(context, 'App Lock', 'Enable biometric or PIN security'),
              _buildInfoItem(context, 'Notifications', 'Configure expiry reminder notifications'),
              _buildInfoItem(context, 'Backup/Restore', 'Export or import your complete data'),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Tips & Best Practices
          _buildSection(
            context,
            icon: Icons.tips_and_updates_outlined,
            title: 'Tips & Best Practices',
            content: null,
            children: [
              _buildTipItem(context, '📸', 'Take clear photos of receipts in good lighting'),
              _buildTipItem(context, '🗓️', 'Add items right after purchase'),
              _buildTipItem(context, '💾', 'Create regular backups of your data'),
              _buildTipItem(context, '📝', 'Use the notes feature to track service history'),
              _buildTipItem(context, '🔔', 'Enable notifications to never miss expiry dates'),
              _buildTipItem(context, '🏷️', 'Use categories to organize items efficiently'),
              _buildTipItem(context, '🔒', 'Enable app lock for sensitive information'),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Privacy & Security
          _buildSection(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & Security',
            content: 'Your privacy is our priority. This app is completely offline - your data never leaves your device. All information is stored locally on your phone. Backups are encrypted ZIP files that you control. No tracking, no analytics, no cloud storage. Your data is yours alone.',
          ),
          
          const SizedBox(height: 32),
          
          // Footer
          Center(
            child: Text(
              '© 2025 — your item vault',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? content,
    List<Widget>? children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 24, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (content != null)
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        if (children != null) ...children,
      ],
    );
  }
  
  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStepItem(
    BuildContext context,
    String number,
    String title,
    String description,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryItem(BuildContext context, String name, String description) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              fontSize: 20,
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(BuildContext context, String title, String description) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, size: 20, color: colorScheme.primary),
          const SizedBox(width: 4),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTipItem(BuildContext context, String emoji, String tip) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
