// Trilingual i18n Dictionary for Tashila (AR, FR, EN)
const i18nData = {
  ar: {
    // Document Title & Brand
    doc_title: "تسهيلة - المنصة الأولى لنقل البضائع في تمنراست",
    brand_name: "تسهيلة",
    legal_hub: "المنصة الرسمية",
    legal_privacy: "سياسة الخصوصية",
    legal_terms: "شروط الخدمة",
    legal_delete: "حذف الحساب",

    // Navigation
    nav_home: "الرئيسية",
    nav_fleet: "أسطول الشاحنات",
    nav_features: "المميزات",
    nav_how: "كيف يعمل",
    nav_drivers: "انضم كسائق",
    nav_privacy: "سياسة الخصوصية",
    nav_terms: "الشروط والأحكام",
    nav_delete: "حذف الحساب",
    nav_download: "تحميل التطبيق",

    // Hero
    badge_algeria: "المنصة الأولى لنقل البضائع في تمنراست",
    hero_title: "انقل بضائعك و تنقل بكل امان و سهولة بضغطة زر واحدة",
    hero_subtitle: "تطبيق تسهيلة يربطك بأقرب سائق شاحنة صغيرة نفعية معتمد في تمنراست. كابينة مفردة أو مزدوجة، بأسعار واضحة وأمان تام.",
    hero_title_driver: "تملك شاحنة نفعية؟ ضاعف دخلك اليومي مع تسهيلة",
    hero_subtitle_driver: "اعمل بحرية تامة في أوقات فراغك، استقبل طلبات نقل مستمرة في تمنراست، واستلم أرباحك مباشرة نقداً بعد كل رحلة بدون وسيط.",
    hero_badge_driver: "🚚 انضم لشبكة شركائنا السائقين المعتمدين في تمنراست",
    btn_download_client: "تحميل تطبيق الزبون",
    btn_download_driver: "تحميل تطبيق السائق",
    tab_client: "تطبيق الزبائن",
    tab_driver: "تطبيق السائقين",
    app_store_desc: "متوفر على",
    app_store_name: "App Store",
    google_play_desc: "احصل عليه من",
    google_play_name: "Google Play",
    rating_badge: "★ 4.9 من أكثر من 5,000 تقييم",
    verified_badge: "سائقون معتمدون ومفحوصون 100%",
    speed_badge: "وصول خلال 10 دقائق في المتوسط",

    // Hero Floating Badges
    float_fast_resp: "استجابة سريعة",
    float_instant_dispatch: "توجيه فوري ذكي",
    float_safe_cargo: "حمولة آمنة ومضمونة",
    float_live_tracking: "تتبع مباشر ولحظي",

    // Phone Mockup
    mockup_trip_type: "طلب شاحنة صغيرة نفعية",
    mockup_single: "كابينة فردية",
    mockup_double: "كابينة مزدوجة",
    mockup_fare_label: "السعر التقديري الثابت",
    mockup_pickup: "حي سرسوف، تمنراست",
    mockup_dropoff: "وسط المدينة، تمنراست",
    mockup_pin: "📍 تمنراست",
    mockup_price: "2,500 دج",
    mockup_driver_name: "أحمد ب. • ★ 4.9",
    mockup_status: "السائق في الطريق إليك (4 دقائق)",
    mockup_avatar: "أ.ب",

    // Fleet Section (No tonnage & no passenger numbers)
    fleet_badge: "أسطولنا المتنوع",
    fleet_title: "شاحنات نفعية تناسب كافة احتياجاتك",
    fleet_subtitle: "نوفر لك خيارات نقل مرنة بمواصفات متعددة تناسب الأفراد، التجار والمؤسسات في تمنراست.",
    single_cabin_title: "شاحنة كابينة فردية",
    single_cabin_desc: "الخيار الأمثل للأحمال والبضائع التجارية بمساحة تحميل مفتوحة ورحبة.",
    single_spec_1: "حوض تحميل متين ومفتوح للأحمال الكبيرة",
    single_spec_2: "حوض تحميل واسع (طول 2.4م × عرض 1.6م)",
    single_spec_3: "مرونة وسهولة في التنقل والوصول إلى كافة الأحياء",
    single_spec_4: "مثالية لنقل البضائع والمعدات ومواد البناء",
    double_cabin_title: "شاحنة كابينة مزدوجة",
    double_cabin_desc: "المزيج المثالي بين نقل البضائع والمرافقة مع حوض تحميل متين لنقل فريق العمل والمساعدين.",
    double_spec_1: "حوض تحميل مخصص ومحمي لمختلف أنواع البضائع",
    double_spec_2: "مقصورة مريحة وواسعة لمرافقة شحنتك",
    double_spec_3: "مثالية لنقل البضائع مع فرق التحميل والمرافقة",
    double_spec_4: "راحة وأمان تام داخل ولاية تمنراست وضواحيها",

    // Features Section
    feat_badge: "لماذا تسهيلة؟",
    feat_title: "خدمة نقل لوجستي حديثة وموثوقة",
    feat_subtitle: "صممنا تسهيلة لتجاوز صعوبات البحث العشوائي عن الشاحنات وتقديم تجربة سلسة وعصرية في تمنراست.",
    feat_1_title: "توجيه وحجز فوري عبر الخريطة",
    feat_1_desc: "خوارزمية ذكية تحدد موقعك وتبث طلبك لأقرب السائقين المتاحين في ثوانٍ معدودة.",
    feat_2_title: "أسعار عادلة وشفافة",
    feat_2_desc: "السعر يُحسب تلقائياً بدقة قبل انطلاق الرحلة حسب الكيلومترات ونوع الشاحنة. لا مزيد من المساومة.",
    feat_3_title: "سائقون معتمدون ومرخصون",
    feat_3_desc: "كل سائق يخضع للتحقق الصارم من رخصة السياقة، البطاقة الرمادية، السوابق العدلية وحالة الشاحنة.",
    feat_4_title: "تتبع مسار الحمولة بالخريطة",
    feat_4_desc: "تابع حركة شاحنتك على الخريطة لحظة بلحظة مع إمكانية مشاركة رابط التتبع مع المستلم.",
    feat_5_title: "اتصال وتواصل هاتفي مباشر",
    feat_5_desc: "اتصال هاتفي مباشر برقم السائق لتنسيق تفاصيل النقل ومتابعة وصول الشاحنة بسهولة ودون تعقيد.",
    feat_6_title: "دعم فني محلي 24/7",
    feat_6_desc: "فريق دعم محلي متواجد على مدار الساعة للرد على استفساراتك ومتابعة رحلاتك في أي وقت.",

    // How It Works
    how_badge: "بساطة وسرعة",
    how_title: "كيف يعمل تطبيق تسهيلة؟",
    how_step_1_title: "1. حدد المسار ونوع الشاحنة",
    how_step_1_desc: "افتح التطبيق، اختر موقع الانطلاق والوصول، وحدد نوع الشاحنة الصغيرة كابينة مفردة أو مزدوجة.",
    how_step_2_title: "2. اعرف السعر وتأكيد الطلب",
    how_step_2_desc: "اطلع على السعر الثابت بدقة واضغط طلب ليتم إرساله لأقرب السائقين في محيطك فوراً.",
    how_step_3_title: "3. وصول السائق وتسليم آمن",
    how_step_3_desc: "يصلك السائق لموقعك، يتم تحميل بضائعك، ونقلها بأمان حتى وجهتها النهائية مع الدفع نقداً.",

    // Driver CTA
    driver_badge: "انضم لشبكة شركائنا",
    driver_cta_title: "تملك شاحنة نفعية؟ ضاعف دخلك اليومي مع تسهيلة",
    driver_cta_desc: "اعمل بحرية تامة في أوقات فراغك، استقبل طلبات نقل مستمرة في تمنراست، واستلم أرباحك مباشرة بعد كل رحلة بدون وسيط.",
    driver_feat_1: "حرية اختيار ساعات العمل ومناطق النشاط",
    driver_feat_2: "طلبات نقل مؤكدة ومستمرة يومياً",
    driver_feat_3: "استلام مستحقاتك نقداً وفورياً من الزبون",
    btn_driver_join: "سجّل الآن كسائق شاحنة",

    // FAQ Section
    faq_badge: "الأسئلة الشائعة",
    faq_title: "كل ما تريد معرفته عن تسهيلة",
    faq_q1: "كيف يتم حساب تكلفة الرحلة في تسهيلة؟",
    faq_a1: "يتم احتساب السعر تلقائياً عبر نظامنا الذكي بناءً على المسافة الفعلية ونوع الشاحنة المختارة، ويكون السعر معلناً وواضحاً قبل تأكيد الطلب.",
    faq_q2: "هل الخدمة متوفرة في ولاية تمنراست؟",
    faq_a2: "نعم، خدمة تسهيلة متوفرة ومخصصة لولاية تمنراست، وتتيح نقل البضائع والشحنات داخل المدينة والمناطق المجاورة بكل سلاسة وأمان.",
    faq_q3: "كيف يمكنني التسجيل كسائق في تسهيلة؟",
    faq_a3: "حمّل تطبيق 'تسهيلة سائق' من متجر Google Play، أنشئ حسابك برقم هاتفك، وارفع وثائق الشاحنة ورخصة السياقة. يقوم فريقنا بتفعيل حسابك بسرعة.",
    faq_q4: "ما هي طرق الدفع المتاحة؟",
    faq_a4: "طريقة الدفع المعتمدة حالياً هي الدفع نقداً مباشرة للسائق عند الوصول.",
    faq_q5: "هل بضائعي في أمان مع سائقي تسهيلة؟",
    faq_a5: "نعم، جميع سائقينا يخضعون للتحقق الدقيق، وتتم متابعة الرحلة مع السائق لضمان سلامة وصول البضائع.",

    // Footer & Links
    footer_desc: "تسهيلة هي المنصة الرقمية الاولى في تمنراست لربط الزبائن و اصحاب البضائع بشاحنات صغيرة نفعية بذكاء و أمان",
    footer_quick_links: "روابط سريعة",
    footer_legal: "الشؤون القانونية",
    footer_contact: "تواصل معنا",
    footer_rights: "© 2026 تسهيلة. جميع الحقوق محفوظة.",
    footer_algeria: "صنع بكل فخر في الجزائر 🇩🇿"
  },

  fr: {
    // Document Title & Brand
    doc_title: "Tashila - 1ère plateforme de transport de marchandises à Tamanrasset",
    brand_name: "Tashila",
    legal_hub: "Plateforme Officielle",
    legal_privacy: "Politique de Confidentialité",
    legal_terms: "Conditions Générales",
    legal_delete: "Suppression de Compte",

    // Navigation
    nav_home: "Accueil",
    nav_fleet: "Flotte",
    nav_features: "Fonctionnalités",
    nav_how: "Comment ça marche",
    nav_drivers: "Devenir Chauffeur",
    nav_privacy: "Confidentialité",
    nav_terms: "Conditions d'utilisation",
    nav_delete: "Supprimer le compte",
    nav_download: "Télécharger",

    // Hero
    badge_algeria: "1ère plateforme de transport de marchandises à Tamanrasset",
    hero_title: "Transportez vos marchandises et déplacez-vous en toute sécurité d'un simple clic",
    hero_subtitle: "L'application Tashila vous connecte au chauffeur de petite camionnette utilitaire le plus proche à Tamanrasset. Simple ou double cabine, prix transparents et sécurité garantie.",
    hero_title_driver: "Vous possédez une camionnette ? Boostez vos revenus avec Tashila",
    hero_subtitle_driver: "Travaillez librement selon vos disponibilités, recevez des courses quotidiennes à Tamanrasset et encaissez directement en espèces sans intermédiaire.",
    hero_badge_driver: "🚚 Rejoignez le réseau des chauffeurs partenaires à Tamanrasset",
    btn_download_client: "Télécharger Tashila Client",
    btn_download_driver: "Télécharger Tashila Chauffeur",
    tab_client: "Application Client",
    tab_driver: "Application Chauffeur",
    app_store_desc: "Disponible sur",
    app_store_name: "App Store",
    google_play_desc: "DISPONIBLE SUR",
    google_play_name: "Google Play",
    rating_badge: "★ 4.9 sur +5 000 avis",
    verified_badge: "Chauffeurs vérifiés à 100%",
    speed_badge: "Prise en charge en 10 min",

    // Hero Floating Badges
    float_fast_resp: "Réponse Rapide",
    float_instant_dispatch: "Attribution Immédiate",
    float_safe_cargo: "Cargaison Sécurisée",
    float_live_tracking: "Suivi Direct",

    // Phone Mockup
    mockup_trip_type: "Demande de Camionnette",
    mockup_single: "Simple Cabine",
    mockup_double: "Double Cabine",
    mockup_fare_label: "Tarif Estimé Garanti",
    mockup_pickup: "Sersouf, Tamanrasset",
    mockup_dropoff: "Centre-Ville, Tamanrasset",
    mockup_pin: "📍 Tamanrasset",
    mockup_price: "2 500 DZD",
    mockup_driver_name: "Ahmed B. • ★ 4.9",
    mockup_status: "Chauffeur en route (4 min)",
    mockup_avatar: "A.B",

    // Fleet Section (No tonnage & no passenger numbers)
    fleet_badge: "Notre Flotte",
    fleet_title: "Des utilitaires adaptés à tous vos besoins",
    fleet_subtitle: "Nous offrons des véhicules utilitaires adaptés pour les particuliers et professionnels à Tamanrasset.",
    single_cabin_title: "Camionnette Simple Cabine",
    single_cabin_desc: "Idéale pour les gros volumes et marchandises avec plateau de chargement spacieux.",
    single_spec_1: "Plateau de chargement robuste et ouvert pour gros volumes",
    single_spec_2: "Plateau spacieux (Longueur 2.4m × Largeur 1.6m)",
    single_spec_3: "Maniabilité optimale dans toutes les ruelles et quartiers",
    single_spec_4: "Parfait pour marchandises et matériaux divers",
    double_cabin_title: "Camionnette Double Cabine",
    double_cabin_desc: "La combinaison parfaite entre capacité de transport de marchandises et accompagnement pour votre équipe.",
    double_spec_1: "Espace de chargement dédié et sécurisé pour tous types de marchandises",
    double_spec_2: "Habitacle spacieux et tout confort pour vous et vos accompagnateurs",
    double_spec_3: "Idéal pour le transport de marchandises avec accompagnateurs",
    double_spec_4: "Confort et sécurité à Tamanrasset et ses environs",

    // Features Section
    feat_badge: "Pourquoi Tashila ?",
    feat_title: "Une logistique moderne et fiable",
    feat_subtitle: "Fini la recherche aléatoire de camionnettes au bord des routes. Tout est digitalisé et sécurisé à Tamanrasset.",
    feat_1_title: "Réservation instantanée sur carte",
    feat_1_desc: "Un algorithme intelligent localise et alerte les camionnettes les plus proches en quelques secondes.",
    feat_2_title: "Tarifs clairs et équitables",
    feat_2_desc: "Prix calculé automatiquement avant le départ selon la distance et le véhicule. Zéro négociation pénible.",
    feat_3_title: "Chauffeurs certifiés et contrôlés",
    feat_3_desc: "Chaque chauffeur fait l'objet d'un contrôle rigoureux : permis, carte grise, casier judiciaire et état du véhicule.",
    feat_4_title: "Suivi GPS en temps réel",
    feat_4_desc: "Suivez la position exacte de votre cargaison en direct sur la carte jusqu'à la livraison finale.",
    feat_5_title: "Contact téléphonique direct",
    feat_5_desc: "Appel téléphonique direct avec votre chauffeur pour coordonner les détails du transport et du chargement en toute simplicité.",
    feat_6_title: "Assistance client locale 24h/24 et 7j/7",
    feat_6_desc: "Une équipe locale dédiée pour vous accompagner et résoudre vos besoins à tout moment.",

    // How It Works
    how_badge: "Simple et Rapide",
    how_title: "Comment fonctionne Tashila ?",
    how_step_1_title: "1. Définissez trajet et véhicule",
    how_step_1_desc: "Ouvrez l'application, choisissez les points de départ et d'arrivée, et sélectionnez le type de petite camionnette (simple ou double cabine).",
    how_step_2_title: "2. Visualisez le prix et commandez",
    how_step_2_desc: "Consultez le tarif garanti et validez. Votre demande est diffusée immédiatement aux chauffeurs à proximité.",
    how_step_3_title: "3. Prise en charge et livraison",
    how_step_3_desc: "Le chauffeur arrive sur place, charge vos biens et livre à destination. Vous réglez directement en espèces.",

    // Driver CTA
    driver_badge: "Rejoignez le réseau",
    driver_cta_title: "Vous possédez une camionnette ? Boostez vos revenus avec Tashila",
    driver_cta_desc: "Travaillez librement selon vos disponibilités, recevez des courses quotidiennes à Tamanrasset et encaissez directement sans intermédiaire.",
    driver_feat_1: "Liberté totale de vos horaires et zones de travail",
    driver_feat_2: "Des dizaines de demandes de transport chaque jour",
    driver_feat_3: "Paiement en espèces direct et immédiat par le client",
    btn_driver_join: "Devenir Chauffeur Partenaire",

    // FAQ Section
    faq_badge: "FAQ",
    faq_title: "Questions fréquentes",
    faq_q1: "Comment est calculé le prix de la course ?",
    faq_a1: "Le prix est calculé automatiquement selon la distance réelle parcourue et le type de camionnette choisi, affiché avant confirmation.",
    faq_q2: "Le service est-il disponible à Tamanrasset ?",
    faq_a2: "Oui, Tashila est disponible et dédié à la wilaya de Tamanrasset pour tous vos transports de marchandises en toute sécurité.",
    faq_q3: "Comment s'inscrire en tant que chauffeur ?",
    faq_a3: "Téléchargez l'application 'Tashila Chauffeur' sur Google Play, inscrivez-vous avec votre numéro et soumettez vos documents.",
    faq_q4: "Quels sont les modes de paiement disponibles ?",
    faq_a4: "Le règlement s'effectue en espèces (Cash) directement auprès du chauffeur à l'arrivée.",
    faq_q5: "Mes marchandises sont-elles en sécurité ?",
    faq_a5: "Oui, nos chauffeurs sont vérifiés et chaque trajet est suivi pour garantir la sécurité de votre cargaison.",

    // Footer & Links
    footer_desc: "Tashila est la 1ère plateforme numérique à Tamanrasset reliant clients et transporteurs de petites camionnettes avec intelligence et sécurité.",
    footer_quick_links: "Liens Rapides",
    footer_legal: "Légal & Sécurité",
    footer_contact: "Contactez-nous",
    footer_rights: "© 2026 Tashila. Tous droits réservés.",
    footer_algeria: "Conçu avec fierté en Algérie 🇩🇿"
  },

  en: {
    // Document Title & Brand
    doc_title: "Tashila - #1 Utility Truck & Cargo Platform in Tamanrasset",
    brand_name: "Tashila",
    legal_hub: "Official Platform",
    legal_privacy: "Privacy Policy",
    legal_terms: "Terms of Service",
    legal_delete: "Delete Account",

    // Navigation
    nav_home: "Home",
    nav_fleet: "Fleet",
    nav_features: "Features",
    nav_how: "How It Works",
    nav_drivers: "Become a Driver",
    nav_privacy: "Privacy Policy",
    nav_terms: "Terms of Service",
    nav_delete: "Delete Account",
    nav_download: "Download App",

    // Hero
    badge_algeria: "The #1 Cargo Transportation Platform in Tamanrasset",
    hero_title: "Transport your goods and move safely and easily with a single tap",
    hero_subtitle: "Tashila connects you with the nearest certified small utility truck driver in Tamanrasset. Single or double cabin, transparent pricing, and total security.",
    hero_title_driver: "Own a Utility Truck? Maximize Your Daily Income with Tashila",
    hero_subtitle_driver: "Work on your own terms, receive consistent delivery requests in Tamanrasset, and get paid directly in cash without middlemen.",
    hero_badge_driver: "🚚 Join Our Partner Driver Network in Tamanrasset",
    btn_download_client: "Download Tashila Client",
    btn_download_driver: "Download Tashila Driver",
    tab_client: "Client App",
    tab_driver: "Driver App",
    app_store_desc: "Download on the",
    app_store_name: "App Store",
    google_play_desc: "GET IT ON",
    google_play_name: "Google Play",
    rating_badge: "★ 4.9 from 5,000+ reviews",
    verified_badge: "100% Verified Drivers",
    speed_badge: "Average 10 min dispatch",

    // Hero Floating Badges
    float_fast_resp: "Fast Response",
    float_instant_dispatch: "Instant Smart Dispatch",
    float_safe_cargo: "Safe & Insured Cargo",
    float_live_tracking: "Live Tracking",

    // Phone Mockup
    mockup_trip_type: "Small Utility Truck Request",
    mockup_single: "Single Cabin",
    mockup_double: "Double Cabin",
    mockup_fare_label: "Upfront Fixed Fare",
    mockup_pickup: "Sersouf, Tamanrasset",
    mockup_dropoff: "City Center, Tamanrasset",
    mockup_pin: "📍 Tamanrasset",
    mockup_price: "2,500 DZD",
    mockup_driver_name: "Ahmed B. • ★ 4.9",
    mockup_status: "Driver arriving in 4 min",
    mockup_avatar: "A.B",

    // Fleet Section (No tonnage & no passenger numbers)
    fleet_badge: "Our Fleet",
    fleet_title: "Utility Trucks Tailored to Your Needs",
    fleet_subtitle: "Choose the perfect vehicle capacity for personal cargo, commerce, or enterprise logistics in Tamanrasset.",
    single_cabin_title: "Single Cabin Utility Truck",
    single_cabin_desc: "Engineered for maximum cargo volume with an open, spacious flatbed.",
    single_spec_1: "Heavy-duty open cargo bed for bulky goods",
    single_spec_2: "Spacious cargo bed (2.4m length × 1.6m width)",
    single_spec_3: "Agile navigation through city streets and all neighborhoods",
    single_spec_4: "Ideal for goods, commercial freight & building materials",
    double_cabin_title: "Double Cabin Utility Truck",
    double_cabin_desc: "The optimal mix of cargo space and crew transport to accompany your cargo alongside your team.",
    double_spec_1: "Dedicated secure loading area for all types of goods",
    double_spec_2: "Spacious and comfortable cabin for you and your helpers",
    double_spec_3: "Perfect for goods transport with helper teams",
    double_spec_4: "Maximum comfort and safety across Tamanrasset and surrounding areas",

    // Features Section
    feat_badge: "Why Tashila?",
    feat_title: "Modern, Reliable On-Demand Logistics",
    feat_subtitle: "No more roadside bargaining or unverified trucks. Everything is digitized, verified, and seamless in Tamanrasset.",
    feat_1_title: "Instant Map-Based Dispatch",
    feat_1_desc: "Smart algorithm alerts the closest available truck drivers in seconds, saving time and fuel.",
    feat_2_title: "Transparent, Upfront Pricing",
    feat_2_desc: "Fares are calculated upfront based on real kilometers and vehicle type. Zero painful negotiation.",
    feat_3_title: "Verified & Licensed Drivers",
    feat_3_desc: "Every driver undergoes strict identity, driver's license, vehicle registration, and background checks.",
    feat_4_title: "Real-time Live Tracking",
    feat_4_desc: "Direct tracking with your driver until safe delivery at destination.",
    feat_5_title: "Direct Phone Call Contact",
    feat_5_desc: "Direct phone call with your driver to seamlessly coordinate cargo loading and delivery details.",
    feat_6_title: "24/7 Dedicated Local Support",
    feat_6_desc: "Local customer support available around the clock to assist you with any questions or special requests.",

    // How It Works
    how_badge: "Simple & Fast",
    how_title: "How Tashila Works",
    how_step_1_title: "1. Set Pickup & Vehicle",
    how_step_1_desc: "Open the app, select pickup and drop-off locations, and choose the small utility truck type: single or double cabin.",
    how_step_2_title: "2. View Fare & Confirm",
    how_step_2_desc: "See the upfront fixed price and tap confirm. The nearest drivers receive the request instantly.",
    how_step_3_title: "3. Safe Pickup & Delivery",
    how_step_3_desc: "Your driver arrives, loads your goods, and delivers safely to destination with cash on delivery.",

    // Driver CTA
    driver_badge: "Partner Network",
    driver_cta_title: "Own a Utility Truck? Maximize Your Daily Income with Tashila",
    driver_cta_desc: "Work on your own terms, receive continuous cargo requests in Tamanrasset, and get paid directly in cash without middlemen.",
    driver_feat_1: "Complete freedom over your working hours and locations",
    driver_feat_2: "Dozens of verified ride offers every day",
    driver_feat_3: "Direct cash payment upon delivery from clients",
    btn_driver_join: "Join as a Partner Driver",

    // FAQ Section
    faq_badge: "FAQ",
    faq_title: "Frequently Asked Questions",
    faq_q1: "How is the trip price calculated?",
    faq_a1: "Fares are calculated automatically based on exact distance and selected truck type, shown upfront before you book.",
    faq_q2: "Is Tashila available in Tamanrasset?",
    faq_a2: "Yes! Tashila is dedicated to the wilaya of Tamanrasset for seamless, safe freight and cargo delivery.",
    faq_q3: "How do I register as a driver?",
    faq_a3: "Download the 'Tashila Driver' app on Google Play, enter your phone number, and upload your documents. Approvals take minutes.",
    faq_q4: "What payment methods are supported?",
    faq_a4: "Payment is made in cash directly to the driver upon delivery. Additional electronic payment options are coming soon.",
    faq_q5: "Is my cargo safe with Tashila drivers?",
    faq_a5: "Yes. All drivers are verified with legal credentials, and every trip is tracked with your driver from start to delivery.",

    // Footer & Links
    footer_desc: "Tashila is the premier digital platform in Tamanrasset connecting clients and cargo owners with small utility trucks smartly and safely.",
    footer_quick_links: "Quick Links",
    footer_legal: "Legal & Privacy",
    footer_contact: "Contact Us",
    footer_rights: "© 2026 Tashila. All rights reserved.",
    footer_algeria: "Proudly built in Algeria 🇩🇿"
  }
};

// Language Controller
(function() {
  const STORAGE_KEY = 'tashila_preferred_lang';
  let currentLang = localStorage.getItem(STORAGE_KEY) || 'ar'; // Default to Arabic for Algeria

  function applyLanguage(lang) {
    if (!i18nData[lang]) lang = 'ar';
    currentLang = lang;
    localStorage.setItem(STORAGE_KEY, lang);

    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';

    // Update all i18n data elements
    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.getAttribute('data-i18n');
      if (i18nData[lang] && i18nData[lang][key]) {
        el.textContent = i18nData[lang][key];
      }
    });

    // If driver tab is active, ensure driver-specific hero copy is shown
    if (window.currentAppTab === 'driver' && i18nData[lang]) {
      const heroTitle = document.querySelector('[data-i18n="hero_title"]');
      const heroSubtitle = document.querySelector('[data-i18n="hero_subtitle"]');
      const heroBadge = document.querySelector('[data-i18n="badge_algeria"]');
      if (heroTitle && i18nData[lang].hero_title_driver) heroTitle.textContent = i18nData[lang].hero_title_driver;
      if (heroSubtitle && i18nData[lang].hero_subtitle_driver) heroSubtitle.textContent = i18nData[lang].hero_subtitle_driver;
      if (heroBadge && i18nData[lang].hero_badge_driver) heroBadge.textContent = i18nData[lang].hero_badge_driver;
    }

    // Update document title for landing page
    if (i18nData[lang] && i18nData[lang].doc_title && (window.location.pathname.endsWith('index.html') || window.location.pathname === '/' || window.location.pathname === '')) {
      document.title = i18nData[lang].doc_title;
    }

    // Update active state in language selector pills/dropdown
    document.querySelectorAll('[data-lang-btn]').forEach(btn => {
      const btnLang = btn.getAttribute('data-lang-btn');
      if (btnLang === lang) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });

    const activeLabel = document.getElementById('currentLangLabel');
    if (activeLabel) {
      if (lang === 'ar') activeLabel.textContent = 'العربية 🇩🇿';
      else if (lang === 'fr') activeLabel.textContent = 'Français 🇫🇷';
      else activeLabel.textContent = 'English 🇬🇧';
    }
  }

  window.setLanguage = applyLanguage;
  window.i18nData = i18nData;
  window.getCurrentLang = () => currentLang;

  document.addEventListener('DOMContentLoaded', () => {
    applyLanguage(currentLang);

    // Bind language selector buttons
    document.querySelectorAll('[data-lang-btn]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        const lang = btn.getAttribute('data-lang-btn');
        applyLanguage(lang);
      });
    });
  });
})();
