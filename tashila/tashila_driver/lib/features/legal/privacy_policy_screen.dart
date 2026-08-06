import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../home/driver_home_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const Map<String, String> _titles = {
    'en': 'Privacy Policy',
    'ar': 'سياسة الخصوصية – تطبيق تسهيلة (Tashila)',
    'fr': 'Politique de confidentialité',
  };

  static const Map<String, String> _subtitles = {
    'en':
        'We attach great importance to the privacy of our users and are committed to protecting the personal information collected during the use of the app. This Privacy Policy explains how we collect, use, and protect user data when using Tashila. By using the app, you agree to the practices described in this policy.',
    'ar':
        'نحن نولي أهمية كبيرة لخصوصية مستخدمينا ونلتزم بحماية المعلومات الشخصية التي يتم جمعها أثناء استخدام التطبيق. توضح سياسة الخصوصية هذه كيفية جمع واستخدام وحماية بيانات المستخدمين عند استخدام تطبيق تسهيلة. باستخدامك للتطبيق، فإنك توافق على الممارسات الموضحة في هذه السياسة.',
    'fr':
        "Nous accordons une grande importance à la vie privée de nos utilisateurs et nous nous engageons à protéger les informations personnelles collectées. Cette politique explique comment nous collectons, utilisons et protégeons vos données. En utilisant l'application, vous acceptez les pratiques décrites.",
  };

  static const Map<String, String> _ackButtons = {
    'en': 'Acknowledge',
    'ar': 'أفهم وأوافق',
    'fr': 'Compris',
  };

  static const Map<String, List<Map<String, String>>> _sections = {
    'ar': [
      {
        'title': '1. من نحن؟',
        'content':
            'تسهيلة (Tashila) هي منصة رقمية تهدف إلى ربط الزبائن الذين يحتاجون إلى خدمات النقل المحلي بأصحاب الشاحنات الصغيرة المسجلين في المنصة داخل المناطق التي تغطيها الخدمة. تسهيلة تعمل كوسيط تقني لتنظيم عملية التواصل بين المستخدمين ومقدمي الخدمة.',
      },
      {
        'title': '2. المعلومات التي نقوم بجمعها',
        'content':
            'أ) معلومات الزبائن: قد نقوم بجمع الاسم الكامل، رقم الهاتف، صورة الملف الشخصي (اختياري)، اللغة المفضلة، معلومات الرحلات السابقة، وتقييمات وتجارب الاستخدام.\n\nب) معلومات السائقين: بالإضافة إلى بيانات الحساب، قد نقوم بجمع الاسم الكامل، رقم الهاتف، الصورة الشخصية، معلومات المركبة (نوع الشاحنة، بيانات المركبة، صور الوثائق المطلوبة للتحقق)، معلومات الرحلات المنجزة، التقييمات، وبيانات الأرباح والعمولات.\n\nج) معلومات الموقع: قد نطلب الوصول إلى الموقع الجغرافي من أجل تحديد موقع المستخدم أثناء إنشاء الطلب، مساعدة السائق على الوصول إلى نقطة الخدمة، وتحسين تجربة استخدام التطبيق. يتم استخدام بيانات الموقع فقط لتقديم وظائف التطبيق المرتبطة بالنقل.',
      },
      {
        'title': '3. كيف نستخدم المعلومات؟',
        'content':
            'نستخدم البيانات من أجل:\n• تقديم الخدمة: إنشاء الحسابات، ربط الزبائن بالسائقين، إدارة الرحلات، وإرسال الإشعارات المتعلقة بالخدمة.\n• تحسين التطبيق: تحليل استخدام التطبيق، تطوير الأداء، واكتشاف المشاكل التقنية.\n• الأمان: التحقق من هوية المستخدمين، منع الاحتيال والاستخدام غير المصرح به.',
      },
      {
        'title': '4. مشاركة المعلومات',
        'content':
            'قد تتم مشاركة بعض المعلومات الضرورية بين المستخدمين لتقديم الخدمة:\n• بين الزبون والسائق: الاسم، رقم الهاتف (عند الحاجة)، ومعلومات الرحلة.\n• مع فريق الإدارة: بيانات الحسابات، وثائق السائقين، ومعلومات الرحلات.\nلا تقوم تسهيلة ببيع أو تأجير البيانات الشخصية للمستخدمين إلى أطراف خارجية.',
      },
      {
        'title': '5. خدمات الطرف الثالث',
        'content':
            'قد يستخدم التطبيق خدمات خارجية للمساعدة في تشغيله، مثل: خدمات الخرائط والموقع، خدمات إرسال الرسائل SMS، خدمات الإشعارات، خدمات تخزين الصور، وخدمات الاستضافة وقواعد البيانات. تخضع هذه الخدمات لسياسات الخصوصية الخاصة بها.',
      },
      {
        'title': '6. حماية البيانات',
        'content':
            'نستخدم إجراءات تقنية وتنظيمية مناسبة لحماية معلومات المستخدمين، مثل حماية الاتصال بين التطبيق والخادم، إدارة صلاحيات الوصول، وحماية حسابات الإدارة. ومع ذلك، لا توجد وسيلة إلكترونية آمنة بنسبة 100%، لذلك لا يمكن ضمان الحماية المطلقة للبيانات.',
      },
      {
        'title': '7. مدة الاحتفاظ بالبيانات',
        'content':
            'نحتفظ بالمعلومات طالما كانت ضرورية من أجل تشغيل الحساب، تقديم الخدمات، والالتزام بالمتطلبات القانونية.',
      },
      {
        'title': '8. حذف الحساب',
        'content':
            'يمكن للمستخدم طلب حذف حسابه من خلال التطبيق أو التواصل مع الدعم. عند حذف الحساب، يتم حذف أو تعطيل البيانات المرتبطة بالحساب حسب الإجراءات المعتمدة، وقد يتم الاحتفاظ ببعض البيانات الضرورية لأسباب قانونية أو أمنية.',
      },
      {
        'title': '9. حقوق المستخدم',
        'content':
            'للمستخدم الحق في: معرفة البيانات التي يتم جمعها عنه، تحديث معلوماته، طلب حذف حسابه، والتواصل معنا بشأن استخدام بياناته.',
      },
      {
        'title': '10. خصوصية الأطفال',
        'content':
            'الخدمة غير موجهة للأطفال تحت السن القانوني لاستخدام الخدمات الرقمية. لا نقوم بجمع بيانات الأطفال بشكل متعمد.',
      },
      {
        'title': '11. تحديث سياسة الخصوصية',
        'content':
            'قد نقوم بتحديث هذه السياسة عند إضافة خدمات جديدة أو إجراء تغييرات على التطبيق. سيتم نشر النسخة الجديدة داخل التطبيق مع تحديث تاريخ آخر تعديل.',
      },
      {
        'title': '12. التواصل معنا',
        'content':
            'لأي استفسار حول سياسة الخصوصية أو البيانات الشخصية:\n• البريد الإلكتروني: tashilaapp@gmail.com\n• رقم الهاتف: +213791453050',
      },
    ],
    'en': [
      {
        'title': '1. Who We Are',
        'content':
            'Tashila is a digital platform connecting local transport clients with registered pickup truck owners within serviced areas.',
      },
      {
        'title': '2. Information We Collect',
        'content':
            'a) Clients: Full name, phone, optional avatar, language, trip history, ratings.\n\nb) Drivers: Name, phone, photo, truck details (type, specs, registration documents), completed trips, earnings, ratings.\n\nc) Location: Real-time GPS for matching, route guidance, and fare calculations.',
      },
      {
        'title': '3. How We Use Information',
        'content':
            'To provide the service (account setup, client matching, trip updates, notifications), improve the app (usage analytics, performance, debugging), and maintain safety (identity checks, fraud prevention).',
      },
      {
        'title': '4. Information Sharing',
        'content':
            'Necessary trip data is shared between client and driver (name, phone if needed, locations) and with platform support. We never sell or rent your personal data.',
      },
      {
        'title': '5. Third-Party Services',
        'content':
            'The app integrates maps, SMS providers, push notifications, storage, and database services subject to their own policies.',
      },
      {
        'title': '6. Data Protection',
        'content':
            'We employ secure connections and access control measures. No digital storage or transfer is 100% secure; absolute protection cannot be guaranteed.',
      },
      {
        'title': '7. Data Retention',
        'content':
            'We retain data as long as necessary to run the account, deliver services, or comply with legal requirements.',
      },
      {
        'title': '8. Account Deletion',
        'content':
            'Users can request account deletion via the settings menu. Stored data is removed or anonymized except where required by law.',
      },
      {
        'title': '9. User Rights',
        'content':
            'You have the right to review collected details, update credentials, request deletion, or contact support about data usage.',
      },
      {
        'title': '10. Children\'s Privacy',
        'content':
            'The platform is not intended for children under the legal age.',
      },
      {
        'title': '11. Updates to this Policy',
        'content':
            'We may update this policy periodically. The updated version will be posted directly in the app.',
      },
      {
        'title': '12. Contact Us',
        'content': 'Email: tashilaapp@gmail.com, Phone: +213791453050',
      },
    ],
    'fr': [
      {
        'title': '1. Qui sommes-nous',
        'content':
            'Tashila est une plateforme numérique reliant les clients de transport local aux propriétaires de camionnettes enregistrés.',
      },
      {
        'title': '2. Informations collectées',
        'content':
            'a) Clients: Nom, téléphone, avatar, langue, historique de trajet, avis.\n\nb) Chauffeurs: Nom, téléphone, photo, détails du véhicule (type, documents, immatriculation), trajets effectués, revenus, évaluations.\n\nc) Localisation: Accès GPS en temps réel pour le jumelage, le guidage et le calcul du tarif.',
      },
      {
        'title': '3. Utilisation des informations',
        'content':
            'Pour fournir le service (comptes, jumelage, notifications), améliorer l\'application (analyses, performances) et assurer la sécurité (vérification d\'identité, lutte contre la fraude).',
      },
      {
        'title': '4. Partage des informations',
        'content':
            'Les données de trajet nécessaires sont partagées entre le client et le chauffeur, ainsi qu\'avec le support. Nous ne vendons ni ne louons vos données.',
      },
      {
        'title': '5. Services tiers',
        'content':
            'L\'application utilise des services de cartographie, SMS, notifications et hébergement soumis à leurs propres conditions.',
      },
      {
        'title': '6. Protection des données',
        'content':
            'Nous appliquons des mesures de sécurité pour protéger vos données, bien qu\'aucune méthode de transmission ne soit totalement sûre.',
      },
      {
        'title': '7. Rétention des données',
        'content':
            'Conservées aussi longtemps que nécessaire pour le fonctionnement du compte ou les exigences légales.',
      },
      {
        'title': '8. Suppression du compte',
        'content':
            'L\'utilisateur peut demander la suppression de son compte via les paramètres. Les données sont effacées sauf obligation légale.',
      },
      {
        'title': '9. Vos droits',
        'content':
            'Droit d\'accès, de mise à jour, de suppression ou de contact concernant l\'utilisation des données.',
      },
      {
        'title': '10. Vie privée des enfants',
        'content': 'Le service n\'est pas destiné aux mineurs.',
      },
      {
        'title': '11. Mises à jour',
        'content':
            'Cette politique peut être mise à jour et la nouvelle version sera publiée dans l\'application.',
      },
      {
        'title': '12. Nous contacter',
        'content': 'Email: tashilaapp@gmail.com, Téléphone: +213791453050',
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final displayLang = ['ar', 'en', 'fr'].contains(lang) ? lang : 'en';
    final title = _titles[displayLang] ?? _titles['en']!;
    final subtitle = _subtitles[displayLang] ?? _subtitles['en']!;
    final sections = _sections[displayLang] ?? _sections['en']!;
    final btnText = _ackButtons[displayLang] ?? _ackButtons['en']!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          'privacy_policy'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      drawer: const DriverDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const Divider(height: 24),
                  ...sections.map(
                    (sec) =>
                        _buildSection(sec['title'] ?? '', sec['content'] ?? ''),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: Text(
                  btnText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
