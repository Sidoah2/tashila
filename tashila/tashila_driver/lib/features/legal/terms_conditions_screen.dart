import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../home/driver_home_screen.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  static const Map<String, String> _titles = {
    'en': 'Terms of Use',
    'ar': 'شروط الاستخدام – تطبيق تسهيلة (Tashila)',
    'fr': "Conditions d'utilisation",
  };

  static const Map<String, String> _subtitles = {
    'en': 'Welcome to Tashila. Tashila is a digital platform designed to facilitate communication and connection between individuals who need local transport services and pickup truck owners available to provide this service. By using Tashila, you agree to be bound by the following Terms of Use.',
    'ar': 'مرحبًا بك في تطبيق تسهيلة (Tashila). تسهيلة هي منصة رقمية تهدف إلى تسهيل التواصل والربط بين الأشخاص الذين يحتاجون إلى خدمات النقل المحلي وأصحاب الشاحنات الصغيرة المتوفرين لتقديم هذه الخدمة. باستخدامك لتتطبيق تسهيلة، فإنك توافق على الالتزام بشروط الاستخدام التالية.',
    'fr': "Bienvenue sur Tashila. Tashila est une plateforme numérique visant à faciliter la communication et la mise en relation entre les personnes ayant besoin de services de transport local et les propriétaires de camionnettes disponibles pour fournir ce service. En utilisant Tashila, vous acceptez de vous conformer aux conditions d'utilisation suivantes.",
  };

  static const Map<String, String> _agreeButtons = {
    'en': 'I Understand & Agree',
    'ar': 'لقد قرأت الشروط وأوافق عليها',
    'fr': 'Je comprends et j\'accepte',
  };

  static const Map<String, List<Map<String, String>>> _sections = {
    'ar': [
      {'title': '1. تعريف الخدمة', 'content': 'تطبيق تسهيلة هو منصة وسيطة تقوم بـ:\n• ربط الزبائن بالسائقين المسجلين في المنصة.\n• تسهيل إرسال واستقبال طلبات النقل.\n• توفير أدوات لتنظيم عملية التواصل وإدارة الرحلات.\nتسهيلة لا تعتبر شركة نقل ولا تمتلك الشاحنات المستخدمة في تنفيذ الخدمات، وإنما توفر منصة للربط بين الطرفين.'},
      {'title': '2. إنشاء الحساب', 'content': 'لاستخدام التطبيق، يجب على المستخدم:\n• تقديم معلومات صحيحة ودقيقة.\n• استخدام رقم هاتف شخصي صالح.\n• المحافظة على سرية بيانات الدخول.\n• عدم استخدام حساب شخص آخر.\nيحق لتسهيلة تعليق أو حذف أي حساب يحتوي على معلومات غير صحيحة أو يستخدم التطبيق بطريقة مخالفة.'},
      {'title': '3. شروط تسجيل السائقين', 'content': 'يجب على السائق:\n• امتلاك مركبة مناسبة وقانونية لتقديم خدمات النقل.\n• تقديم معلومات صحيحة عن المركبة.\n• تقديم الوثائق المطلوبة للتحقق.\n• الالتزام بالقوانين المرورية المعمول بها.\nتحتفظ تسهيلة بحق مراجعة وقبول أو رفض حساب أي سائق.'},
      {'title': '4. مسؤوليات السائق', 'content': 'السائق مسؤول عن:\n• سلامة المركبة.\n• احترام قوانين المرور.\n• المحافظة على ممتلكات الزبون أثناء النقل.\n• التعامل باحترام ومهنية مع الزبائن.\n• تنفيذ الرحلات التي قبل بها.\nتسهيلة لا تتحمل مسؤولية الأضرار الناتجة عن تصرفات السائق أو حالة المركبة.'},
      {'title': '5. مسؤوليات الزبون', 'content': 'يلتزم الزبون بـ:\n• تقديم معلومات صحيحة حول مكان التحميل والوصول.\n• وصف طبيعة الأغراض المنقولة بشكل صحيح.\n• عدم طلب نقل مواد ممنوعة أو غير قانونية.\n• احترام السائق أثناء تقديم الخدمة.'},
      {'title': '6. الأسعار والدفع', 'content': 'يتم تحديد سعر الخدمة حسب إعدادات المنصة والعوامل المعتمدة.\nالدفع يتم حاليًا بشكل نقدي مباشرة بين الزبون والسائق.\nتسهيلة قد تقوم مستقبلاً بإضافة طرق دفع أخرى.'},
      {'title': '7. إلغاء الرحلات', 'content': 'يمكن للزبون أو السائق إلغاء الطلب قبل بدء الخدمة.\nقد يتم اتخاذ إجراءات ضد الحسابات التي تقوم بالإلغاء المتكرر بطريقة تضر بالخدمة.'},
      {'title': '8. التقييمات والمراجعات', 'content': 'يمكن للمستخدمين تقمير تجربة الخدمة. يمنع:\n• نشر تقييمات كاذبة.\n• استخدام عبارات مسيئة.\n• محاولة التأثير على تقييمات المستخدمين الآخرين.'},
      {'title': '9. استخدام التطبيق بشكل ممنوع', 'content': 'يُمنع استخدام التطبيق من أجل:\n• أي نشاط غير قانوني.\n• تقديم معلومات مزورة.\n• محاولة اختراق أو تعطيل النظام.\n• استخدام التطبيق للإعلانات غير المصرح بها.\n• إنشاء حسابات وهمية.'},
      {'title': '10. البيانات والخصوصية', 'content': 'تقوم تسهيلة بجمع بعض المعلومات الضرورية لتقديم الخدمة، مثل: الاسم، رقم الهاتف، صورة الحساب، معلومات المركبة للسائق، والموقع أثناء تقديم الخدمة. يتم استخدام هذه البيانات بهدف تشغيل التطبيق، تحسين الخدمة، وحماية المستخدمين. لن يتم بيع بيانات المستخدمين لأطراف خارجية.'},
      {'title': '11. حدود المسؤولية', 'content': 'تسهيلة تعمل كمنصة تقنية للربط بين المستخدمين. لا تتحمل مسؤولية جودة الخدمة المقدمة من السائق، التأخير الناتج عن ظروف خارجة عن السيطرة، الأضرار الناتجة عن نقل الأغراض، أو الاتفاقات خارج التطبيق.'},
      {'title': '12. إيقاف الحساب', 'content': 'يمكن لتسهيلة تعليق أو حذف الحساب في الحالات التالية: مخالفة شروط الاستخدام، تقديم معلومات غير صحيحة، إساءة استخدام المنصة، أو وجود شكاوى متكررة مثبتة.'},
      {'title': '13. تعديل شروط الاستخدام', 'content': 'تحتفظ تسهيلة بحق تعديل هذه الشروط عند الحاجة. سيتم إعلام المستخدمين بأي تغييرات مهمة عبر التطبيق.'},
      {'title': '14. التواصل والدعم', 'content': 'في حال وجود أي استفسار أو مشكلة يمكن التواصل مع فريق دعم تسهيلة عبر:\n• الهاتف: +213791453050\n• البريد الإلكتروني: tashilaapp@gmail.com'},
      {'title': '15. قبول الشروط', 'content': 'باستخدام تطبيق تسهيلة وإنشاء حساب، يقر المستخدم بأنه قرأ وفهم ووافق على شروط الاستخدام هذه.'}
    ],
    'en': [
      {'title': '1. Service Definition', 'content': 'Tashila is an intermediary platform that:\n• Connects clients with registered drivers on the platform.\n• Facilitates sending and receiving transport requests.\n• Provides tools to organize communication and manage trips.\nTashila is not a transport company and does not own the trucks used; it only provides a platform to connect the two parties.'},
      {'title': '2. Account Creation', 'content': 'To use the app, the user must:\n• Provide true and accurate information.\n• Use a valid personal phone number.\n• Maintain credentials confidentiality.\n• Not use another person\'s account.\nTashila reserves the right to suspend or delete any account containing incorrect information or using the app in violation.'},
      {'title': '3. Driver Registration Terms', 'content': 'The driver must:\n• Own an appropriate and legal vehicle for transport services.\n• Provide correct vehicle information.\n• Submit required documents for verification.\n• Comply with applicable traffic laws.\nTashila reserves the right to review and accept or reject any driver\'s account.'},
      {'title': '4. Driver Responsibilities', 'content': 'The driver is responsible for:\n• Vehicle safety.\n• Respecting traffic laws.\n• Preserving client property during transit.\n• Acting respectfully and professionally with clients.\n• Executing accepted trips.\nTashila is not responsible for damages resulting from driver conduct or vehicle condition.'},
      {'title': '5. Client Responsibilities', 'content': 'The client agrees to:\n• Provide correct pickup and destination details.\n• Describe transport items accurately.\n• Not request transport of prohibited or illegal items.\n• Respect the driver during service delivery.'},
      {'title': '6. Pricing and Payment', 'content': 'Pricing is set according to platform settings and approved factors.\nPayments are currently made in cash directly between the client and driver.\nTashila may introduce other payment methods in the future.'},
      {'title': '7. Trip Cancellation', 'content': 'The client or driver can cancel a request before service begins.\nAction may be taken against accounts that cancel repeatedly to the detriment of the service.'},
      {'title': '8. Ratings and Reviews', 'content': 'Users can rate their service experience. Publishing false reviews, using offensive language, or attempting to influence other users\' ratings is prohibited.'},
      {'title': '9. Prohibited Use', 'content': 'The app must not be used for:\n• Any illegal activity.\n• Providing falsified information.\n• Attempting to hack or disrupt the system.\n• Unauthorized advertising.\n• Creating fake accounts.'},
      {'title': '10. Data and Privacy', 'content': 'Tashila collects necessary information to provide the service, such as:\n• Name.\n• Phone number.\n• Profile photo.\n• Driver vehicle details.\n• Location during service delivery.\nThis data is used to operate the app, improve service, and protect users. Data will not be sold to third parties.'},
      {'title': '11. Limitation of Liability', 'content': 'Tashila acts as a technical connection platform. It is not responsible for service quality provided by the driver, delays due to circumstances beyond control, damages to cargo, or agreements made outside the app.'},
      {'title': '12. Account Suspension', 'content': 'Tashila may suspend or delete an account for violating terms of use, providing incorrect information, platform abuse, or repeated verified complaints.'},
      {'title': '13. Amendment of Terms', 'content': 'Tashila reserves the right to modify these terms. Users will be notified of significant changes via the app.'},
      {'title': '14. Support & Contact', 'content': 'For questions or issues, contact support via:\n• Phone: +213791453050\n• Email: tashilaapp@gmail.com'},
      {'title': '15. Acceptance of Terms', 'content': 'By using the Tashila app and creating an account, the user acknowledges that they have read, understood, and agreed to these Terms of Use.'}
    ],
    'fr': [
      {'title': '1. Définition du service', 'content': 'Tashila est une plateforme intermédiaire qui:\n• Connecte les clients avec les chauffeurs enregistrés sur la plateforme.\n• Facilite l\'envoi et la réception des demandes de transport.\n• Fournit des outils pour organiser la communication et gérer les trajets.\nTashila n\'est pas une entreprise de transport et ne possède pas les camions utilisés; elle fournit uniquement une plateforme pour relier les deux parties.'},
      {'title': '2. Création de compte', 'content': 'Pour utiliser l\'application, l\'utilisateur doit:\n• Fournir des informations véridiques et précises.\n• Utiliser un numéro de téléphone personnel valide.\n• Préserver la confidentialité des identifiants.\n• Ne pas utiliser le compte d\'une autre personne.\nTashila se réserve le droit de suspendre ou de supprimer tout compte contenant des informations incorrectes ou utilisant l\'application en violation des règles.'},
      {'title': '3. Conditions d\'inscription des chauffeurs', 'content': 'Le chauffeur doit:\n• Posséder un véhicule approprié et légal pour les services de transport.\n• Fournir des informations correctes sur le véhicule.\n• Soumettre les documents requis pour vérification.\n• Se conformer aux lois sur la circulation en vigueur.\nTashila se réserve le droit de réviser, d\'accepter ou de rejeter tout compte de chauffeur.'},
      {'title': '4. Responsabilités du chauffeur', 'content': 'Le chauffeur est responsable de:\n• La sécurité du véhicule.\n• Le respect des lois sur la circulation.\n• La préservation des biens du client pendant le transport.\n• Le comportement respectueux et professionnel avec les clients.\n• L\'exécution des trajets acceptés.\nTashila n\'est pas responsable des dommages résultant de la conduite du chauffeur ou de l\'état du véhicule.'},
      {'title': '5. Responsabilités du client', 'content': 'Le client s\'engage à:\n• Fournir des détails corrects sur le point de chargement et de destination.\n• Décrire précisément les objets transportés.\n• Ne pas demander le transport d\'objets interdits ou illégaux.\n• Respecter le chauffeur lors de la prestation du service.'},
      {'title': '6. Tarification et paiement', 'content': 'Le prix du service est déterminé selon les paramètres de la plateforme et les facteurs approuvés.\nLe paiement s\'effectue actuellement en espèces directement entre le client et le chauffeur.\nTashila pourrait introduire d\'autres méthodes de paiement à l\'avenir.'},
      {'title': '7. Annulation de trajet', 'content': 'Le client ou le chauffeur peut annuler une demande avant le début du service.\nDes mesures peuvent être prises contre les comptes qui annulent de manière répétée au détriment du service.'},
      {'title': '8. Évaluations et avis', 'content': 'Les utilisateurs peuvent évaluer leur expérience de service. Il est interdit de publier de fausses évaluations, d\'utiliser un langage offensant ou de tenter d\'influencer les évaluations d\'autres utilisateurs.'},
      {'title': '9. Utilisation interdite', 'content': 'L\'application ne doit pas être utilisée pour:\n• Toute activité illégale.\n• La fourniture de fausses informations.\n• La tentative de pirater ou d\'interrompre le système.\n• La publicité non autorisée.\n• La création de faux comptes.'},
      {'title': '10. Données et confidentialité', 'content': 'Tashila collecte les informations nécessaires pour fournir le service, telles que: Nom, numéro de téléphone, photo de profil, détails du véhicule du chauffeur et localisation pendant la prestation. Ces données sont utilisées pour faire fonctionner l\'application, améliorer le service et protéger les utilisateurs. Les données ne seront pas vendues à des tiers.'},
      {'title': '11. Limitation de responsabilité', 'content': 'Tashila agit en tant que plateforme de connexion technique. Elle n\'est pas responsable de la qualité du service fourni par le chauffeur, des retards dus à des circonstances indépendantes de sa volonté, des dommages causés aux marchandises ou des accords conclus en dehors de l\'application.'},
      {'title': '12. Suspension du compte', 'content': 'Tashila peut suspendre ou supprimer un compte pour violation des conditions d\'utilisation, fourniture d\'informations incorrectes, abus de la plateforme ou plaintes répétées et vérifiées.'},
      {'title': '13. Modification des conditions', 'content': 'Tashila se réserve le droit de modifier ces conditions. Les utilisateurs seront informés des changements importants via l\'application.'},
      {'title': '14. Contact & Support', 'content': 'Pour toute question ou problème, contactez le support via:\n• Téléphone: +213791453050\n• E-mail: tashilaapp@gmail.com'},
      {'title': '15. Acceptation des conditions', 'content': 'En utilisant l\'application Tashila et en créant un compte, l\'utilisateur reconnaît avoir lu, compris et accepté ces Conditions d\'utilisation.'}
    ]
  };

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final displayLang = ['ar', 'en', 'fr'].contains(lang) ? lang : 'en';
    final title = _titles[displayLang] ?? _titles['en']!;
    final subtitle = _subtitles[displayLang] ?? _subtitles['en']!;
    final sections = _sections[displayLang] ?? _sections['en']!;
    final btnText = _agreeButtons[displayLang] ?? _agreeButtons['en']!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 24),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          'terms_and_conditions'.tr(),
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  ...sections.map((sec) => _buildSection(
                        sec['title'] ?? '',
                        sec['content'] ?? '',
                      )),
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
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
