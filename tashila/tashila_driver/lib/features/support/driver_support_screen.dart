import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/config/support_config.dart';

import '../home/driver_home_screen.dart';

class DriverSupportScreen extends StatelessWidget {
  const DriverSupportScreen({super.key});

  Future<void> _openWhatsApp() async {
    final url = Uri.parse('https://wa.me/$kSupportWhatsAppDigits?text=${Uri.encodeComponent('Hello Tashila Support, I need assistance.')}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      await launchUrl(url);
    }
  }

  Future<void> _callSupport() async {
    final url = Uri.parse('tel:+$kSupportWhatsAppDigits');
    if (!await launchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'support_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 24),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: const DriverDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // WhatsApp Highlight Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'whatsapp_support_title'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'whatsapp_support_desc'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2E7D32),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.chat_rounded),
                      label: Text(
                        'open_whatsapp'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: StadiumBorder(),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Call Support Tile
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.phone_rounded, color: AppColors.brandOrange),
                ),
                title: Text(
                  'call_support_center'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                subtitle: Text('available_24_7'.tr(), style: const TextStyle(fontSize: 12)),
                trailing: ElevatedButton(
                  onPressed: _callSupport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: Text('call_now'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // FAQ Accordion Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'faq_title'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ExpansionTile(
                    title: Text('faq_q1'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text('faq_a1'.tr(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3)),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  ExpansionTile(
                    title: Text('faq_q2'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text('faq_a2'.tr(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
