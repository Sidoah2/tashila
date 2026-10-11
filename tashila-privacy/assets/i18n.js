// Trilingual i18n Dictionary for Tashila (AR, FR, EN)
const i18nData = {
  ar: {
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
    legal_hub: "المنصة الرسمية",

    // Hero
    badge_algeria: "🇩🇿 المنصة الأولى لنقل البضائع والعفش في الجزائر • 58 ولاية",
    hero_title: "انقل بضائعك وعفشك بكل أمان وسهولة بضغطة زر واحدة",
    hero_subtitle: "تطبيق تسهيلة يربطك مباشرة بأقرب سائق شاحنة نفعية معتمد في ولايتك. كابينة فردية أو مزدوجة مع تتبع حي عبر GPS وأسعار واضحة وعادلة بدون مساومة.",
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

    // Phone Mockup
    mockup_trip_type: "طلب شاحنة نفعية",
    mockup_single: "كابينة فردية (1.5 طن)",
    mockup_double: "كابينة مزدوجة (1.0 طن)",
    mockup_pickup: "حي النخيل، وهران",
    mockup_dropoff: "وسط المدينة، سيدي بلعباس",
    mockup_price: "3,800 دج",
    mockup_driver_name: "أحمد ب. • ★ 4.9",
    mockup_status: "السائق في الطريق إليك (4 دقائق)",

    // Stats
    stat_wilayas: "ولاية مغطاة بالكامل",
    stat_wilayas_num: "58",
    stat_deliveries: "نقلة بضائع ناجحة",
    stat_deliveries_num: "+15,000",
    stat_drivers: "سائق شاحنة معتمد ومفحوص",
    stat_drivers_num: "+1,200",
    stat_rating: "معدل الرضا العام",
    stat_rating_num: "4.9/5",

    // Fleet Section
    fleet_badge: "أسطولنا المتنوع",
    fleet_title: "شاحنات نفعية تناسب كافة احتياجاتك",
    fleet_subtitle: "نوفر لك خيارات نقل مرنة بحمولات ومواصفات مختلفة تناسب الأفراد، التجار والمؤسسات.",
    single_cabin_title: "شاحنة كابينة فردية (Single Cabin)",
    single_cabin_desc: "الخيار الأمثل للأحمال الكبيرة والأثاث والبضائع التجارية بحمولة تصل إلى 1.5 طن ومساحة تحميل مفتوحة ورحبة.",
    single_spec_1: "حمولة استيعابية حتى 1,500 كغ (1.5 طن)",
    single_spec_2: "حوض تحميل واسع (طول 2.4م × عرض 1.6م)",
    single_spec_3: "مقعدان (السائق + مرافق واحد)",
    single_spec_4: "مثالية لنقل الأثاث، الأجهزة، البضائع ومواد البناء",
    double_cabin_title: "شاحنة كابينة مزدوجة (Double Cabin)",
    double_cabin_desc: "المزيج المثالي بين نقل البضائع ونقل الركاب. تتسع لـ 5 أشخاص مع حوض تحميل متين لنقل فريق العمل والمساعدين مع العفش.",
    double_spec_1: "حمولة استيعابية حتى 1,000 كغ (1.0 طن)",
    double_spec_2: "مقصورة ركاب واسعة تتسع لـ 5 أشخاص",
    double_spec_3: "مثالية للترحيل المنزلي مع فرق التحميل والمرافقة",
    double_spec_4: "راحة وأمان تام على الطرق الطويلة بين الولايات",

    // Features Section
    feat_badge: "لماذا تسهيلة؟",
    feat_title: "خدمة نقل لوجستي حديثة وموثوقة",
    feat_subtitle: "صممنا تسهيلة لتجاوز صعوبات البحث العشوائي عن الشاحنات وتقديم تجربة سلسة وعصرية.",
    feat_1_title: "توجيه وحجز فوري عبر الخريطة",
    feat_1_desc: "خوارزمية ذكية تحدد موقعك وتبث طلبك لأقرب السائقين المتاحين في ثوانٍ معدودة.",
    feat_2_title: "أسعار عادلة وشفافة",
    feat_2_desc: "السعر يُحسب تلقائياً بدقة قبل انطلاق الرحلة حسب الكيلومترات ونوع الشاحنة. لا مزيد من المساومة.",
    feat_3_title: "سائقون معتمدون ومرخصون",
    feat_3_desc: "كل سائق يخضع للتحقق الصارم من رخصة السياقة، البطاقة الرمادية، السوابق العدلية وحالة الشاحنة.",
    feat_4_title: "تتبع مسار الحمولة بالـ GPS",
    feat_4_desc: "تابع حركة شاحنتك على الخريطة لحظة بلحظة مع إمكانية مشاركة رابط التتبع مع المستلم.",
    feat_5_title: "إشعارات فورية وتواصل مباشر",
    feat_5_desc: "اتصال هاتفي مباشر ودردشة داخل التطبيق مع إشعارات Push تنبهك بكل مرحلة من مراحل النقل.",
    feat_6_title: "دعم فني جزائري 24/7",
    feat_6_desc: "فريق دعم محلي متواجد على مدار الساعة للرد على استفساراتك ومتابعة رحلاتك في أي وقت.",

    // How It Works
    how_badge: "بساطة وسرعة",
    how_title: "كيف يعمل تطبيق تسهيلة؟",
    how_step_1_title: "1. حدد المسار ونوع الشاحنة",
    how_step_1_desc: "افتح التطبيق، اختر موقع الانطلاق والوصول، وحدد شاحنة كابينة فردية أو مزدوجة.",
    how_step_2_title: "2. اعرف السعر وتأكيد الطلب",
    how_step_2_desc: "اطلع على السعر الثابت بدقة واضغط طلب ليتم إرساله لأقرب السائقين في محيطك فوراً.",
    how_step_3_title: "3. وصول السائق وتسليم آمن",
    how_step_3_desc: "يصلك السائق لموقعك، يتم تحميل بضائعك، ونقلها بأمان حتى وجهتها النهائية مع الدفع نقداً.",

    // Driver CTA
    driver_badge: "انضم لشبكة شركائنا",
    driver_cta_title: "تملك شاحنة نفعية؟ ضاعف دخلك اليومي مع تسهيلة",
    driver_cta_desc: "اعمل بحرية تامة في أوقات فراغك، استقبل طلبات نقل مستمرة في ولايتك، واستلم أرباحك مباشرة بعد كل رحلة بدون وسيط.",
    driver_feat_1: "حرية اختيار ساعات العمل ومناطق النشاط",
    driver_feat_2: "طلبات نقل مؤكدة ومستمرة يومياً",
    driver_feat_3: "استلام مستحقاتك نقداً وفورياً من الزبون",
    btn_driver_join: "سجّل الآن كسائق شاحنة",

    // FAQ Section
    faq_badge: "الأسئلة الشائعة",
    faq_title: "كل ما تريد معرفته عن تسهيلة",
    faq_q1: "كيف يتم حساب تكلفة الرحلة في تسهيلة؟",
    faq_a1: "يتم احتساب السعر تلقائياً عبر نظامنا الذكي بناءً على المسافة الفعلية بالكيلومتر ونوع الشاحنة المختارة (كابينة فردية أو مزدوجة)، ويكون السعر معلناً وواضحاً قبل تأكيد الطلب.",
    faq_q2: "هل الخدمة متوفرة في جميع ولايات الجزائر؟",
    faq_a2: "نعم، تغطي شبكة تسهيلة كافة ولايات الوطن الـ 58، وتتيح النقل داخل نفس المدينة أو بين الولايات المختلفة بكل سلاسة.",
    faq_q3: "كيف يمكنني التسجيل كسائق في تسهيلة؟",
    faq_a3: "حمّل تطبيق 'تسهيلة سائق' من متجر Google Play، أنشئ حسابك برقم هاتفك، وارفع صور رخصة السياقة والبطاقة الرمادية. يقوم فريقنا بمراجعة وثائقك وتفعيل حسابك خلال دقائق.",
    faq_q4: "ما هي طرق الدفع المتاحة؟",
    faq_a4: "طريقة الدفع المعتمدة حالياً هي الدفع نقداً (Cash) مباشرة للسائق عند الوصول، مع إمكانية توفير وسائل دفع إلكترونية مستقبلاً.",
    faq_q5: "هل بضائعي في أمان مع سائقي تسهيلة؟",
    faq_a5: "نعم، جميع سائقينا يخضعون للتحقق الأمني والميداني، ويمكنك تتبع الشاحنة مباشرة عبر الخريطة من بداية الرحلة حتى التسليم، مع وجود دعم فني مستمر.",

    // Footer & Links
    footer_desc: "تسهيلة هي المنصة الرقمية الرائدة في الجزائر لربط الزبائن وأصحاب البضائع بشاحنات النقل النفعية بذكاء وأمان.",
    footer_quick_links: "روابط سريعة",
    footer_legal: "الشؤون القانونية",
    footer_contact: "تواصل معنا",
    footer_rights: "© 2026 تسهيلة (Tashila Logistics). جميع الحقوق محفوظة.",
    footer_algeria: "صنع بكل فخر في الجزائر 🇩🇿"
  },

  fr: {
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
    legal_hub: "Plateforme Officielle",

    // Hero
    badge_algeria: "🇩🇿 1ère plateforme de transport de fret & déménagement en Algérie • 58 Wilayas",
    hero_title: "Transportez vos marchandises et déménagez en toute sérénité d'un simple clic",
    hero_subtitle: "Tashila vous met en relation instantanée avec des chauffeurs de camionnettes utilitaires certifiés. Simple ou double cabine, suivi GPS en direct et tarifs transparents sans marchandage.",
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

    // Phone Mockup
    mockup_trip_type: "Demande de Camionnette",
    mockup_single: "Simple Cabine (1.5 Tonne)",
    mockup_double: "Double Cabine (1.0 Tonne)",
    mockup_pickup: "Cité Les Palmiers, Oran",
    mockup_dropoff: "Centre-Ville, Sidi Bel Abbès",
    mockup_price: "3 800 DZD",
    mockup_driver_name: "Ahmed B. • ★ 4.9",
    mockup_status: "Chauffeur en route (4 min)",

    // Stats
    stat_wilayas: "Wilayas couvertes",
    stat_wilayas_num: "58",
    stat_deliveries: "Livraisons réussies",
    stat_deliveries_num: "+15 000",
    stat_drivers: "Chauffeurs partenaires vérifiés",
    stat_drivers_num: "+1 200",
    stat_rating: "Note moyenne de satisfaction",
    stat_rating_num: "4.9/5",

    // Fleet Section
    fleet_badge: "Notre Flotte",
    fleet_title: "Des utilitaires adaptés à tous vos besoins",
    fleet_subtitle: "Nous offrons des véhicules utilitaires de capacités variées pour les particuliers, artisans et commerçants.",
    single_cabin_title: "Camionnette Simple Cabine",
    single_cabin_desc: "Idéale pour les gros volumes, meubles et matériaux lourds. Charge utile jusqu'à 1,5 tonne avec plateau de chargement spacieux.",
    single_spec_1: "Charge utile jusqu'à 1 500 kg (1,5 tonne)",
    single_spec_2: "Plateau spacieux (Longueur 2.4m × Largeur 1.6m)",
    single_spec_3: "2 places assises (Chauffeur + 1 passager)",
    single_spec_4: "Parfait pour meubles, électroménager et marchandises",
    double_cabin_title: "Camionnette Double Cabine",
    double_cabin_desc: "La combinaison parfaite entre capacité de chargement et transport d'équipe. 5 places assises pour transporter vos aides et déménageurs.",
    double_spec_1: "Charge utile jusqu'à 1 000 kg (1,0 tonne)",
    double_spec_2: "Habitacle spacieux de 5 places assises",
    double_spec_3: "Idéal pour les déménagements avec équipe de porteurs",
    double_spec_4: "Confort et sécurité sur les trajets inter-wilayas",

    // Features Section
    feat_badge: "Pourquoi Tashila ?",
    feat_title: "Une logistique moderne et fiable",
    feat_subtitle: "Fini la recherche aléatoire de camionnettes au bord des routes. Tout est digitalisé et sécurisé.",
    feat_1_title: "Réservation instantanée sur carte",
    feat_1_desc: "Un algorithme intelligent localise et alerte les camionnettes les plus proches en quelques secondes.",
    feat_2_title: "Tarifs clairs et équitables",
    feat_2_desc: "Prix calculé automatiquement avant le départ selon la distance et le véhicule. Zéro négociation pénible.",
    feat_3_title: "Chauffeurs certifiés et contrôlés",
    feat_3_desc: "Chaque chauffeur fait l'objet d'un contrôle rigoureux : permis, carte grise, casier judiciaire et état du véhicule.",
    feat_4_title: "Suivi GPS en temps réel",
    feat_4_desc: "Suivez la position exacte de votre cargaison en direct sur la carte jusqu'à la livraison finale.",
    feat_5_title: "Notifications push et contact direct",
    feat_5_desc: "Appels directs, chat intégré et notifications instantanées à chaque étape de votre transport.",
    feat_6_title: "Assistance client 24h/24 et 7j/7",
    feat_6_desc: "Une équipe locale dédiée pour vous accompagner et résoudre vos besoins à tout moment.",

    // How It Works
    how_badge: "Simple et Rapide",
    how_title: "Comment fonctionne Tashila ?",
    how_step_1_title: "1. Définissez trajet et véhicule",
    how_step_1_desc: "Ouvrez l'application, indiquez l'adresse de départ et d'arrivée, puis choisissez simple ou double cabine.",
    how_step_2_title: "2. Visualisez le prix et commandez",
    how_step_2_desc: "Consultez le tarif garanti et validez. Votre demande est diffusée immédiatement aux chauffeurs à proximité.",
    how_step_3_title: "3. Prise en charge et livraison",
    how_step_3_desc: "Le chauffeur arrive sur place, charge vos biens et livre à destination. Vous réglez directement en espèces.",

    // Driver CTA
    driver_badge: "Rejoignez le réseau",
    driver_cta_title: "Vous possédez une camionnette ? Boostez vos revenus avec Tashila",
    driver_cta_desc: "Travaillez librement selon vos disponibilités, recevez des courses quotidiennes dans votre wilaya et encaissez directement sans intermédiaire.",
    driver_feat_1: "Liberté totale de vos horaires et zones de travail",
    driver_feat_2: "Des dizaines de demandes de transport chaque jour",
    driver_feat_3: "Paiement en espèces direct et immédiat par le client",
    btn_driver_join: "Devenir Chauffeur Partenaire",

    // FAQ Section
    faq_badge: "FAQ",
    faq_title: "Questions fréquentes",
    faq_q1: "Comment est calculé le prix de la course ?",
    faq_a1: "Le prix est calculé automatiquement selon la distance réelle parcourue et le type de camionnette choisi (simple ou double cabine), affiché avant confirmation.",
    faq_q2: "Le service est-il disponible dans toute l'Algérie ?",
    faq_a2: "Oui, Tashila est disponible à travers les 58 wilayas d'Algérie, que ce soit pour des trajets intra-muros ou inter-wilayas.",
    faq_q3: "Comment s'inscrire en tant que chauffeur ?",
    faq_a3: "Téléchargez l'application 'Tashila Chauffeur' sur Google Play, inscrivez-vous avec votre numéro et soumettez vos documents. Validation en quelques minutes.",
    faq_q4: "Quels sont les modes de paiement disponibles ?",
    faq_a4: "Le règlement s'effectue en espèces (Cash) directement auprès du chauffeur à l'arrivée.",
    faq_q5: "Mes marchandises sont-elles en sécurité ?",
    faq_a5: "Oui, nos chauffeurs sont vérifiés et chaque trajet est tracé par GPS du point de départ jusqu'à la livraison.",

    // Footer & Links
    footer_desc: "Tashila est la plateforme logistique innovante en Algérie pour transporter marchandises et déménager facilement et en toute sécurité.",
    footer_quick_links: "Liens Rapides",
    footer_legal: "Légal & Sécurité",
    footer_contact: "Contactez-nous",
    footer_rights: "© 2026 Tashila (Tashila Logistics). Tous droits réservés.",
    footer_algeria: "Conçu avec fierté en Algérie 🇩🇿"
  },

  en: {
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
    legal_hub: "Official Platform",

    // Hero
    badge_algeria: "🇩🇿 Algeria's #1 On-Demand Freight & Utility Truck App • 58 Wilayas Covered",
    hero_title: "Fast, Reliable & Transparent Cargo & Truck Transport Across Algeria",
    hero_subtitle: "Tashila connects you instantly with verified utility truck drivers in your wilaya. Single or double cabin, live GPS tracking, and guaranteed upfront pricing with zero bargaining.",
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

    // Phone Mockup
    mockup_trip_type: "Utility Truck Request",
    mockup_single: "Single Cabin (1.5 Ton)",
    mockup_double: "Double Cabin (1.0 Ton)",
    mockup_pickup: "Les Palmiers, Oran",
    mockup_dropoff: "City Center, Sidi Bel Abbès",
    mockup_price: "3,800 DZD",
    mockup_driver_name: "Ahmed B. • ★ 4.9",
    mockup_status: "Driver arriving in 4 min",

    // Stats
    stat_wilayas: "Wilayas Fully Covered",
    stat_wilayas_num: "58",
    stat_deliveries: "Successful Cargo Deliveries",
    stat_deliveries_num: "+15,000",
    stat_drivers: "Verified Partner Drivers",
    stat_drivers_num: "+1,200",
    stat_rating: "Average Satisfaction Rating",
    stat_rating_num: "4.9/5",

    // Fleet Section
    fleet_badge: "Our Fleet",
    fleet_title: "Utility Trucks Tailored to Your Needs",
    fleet_subtitle: "Choose the perfect vehicle capacity for personal moving, commerce, or enterprise logistics.",
    single_cabin_title: "Single Cabin Utility Truck",
    single_cabin_desc: "Engineered for maximum cargo volume and heavy loads. Up to 1.5 ton capacity with an open, spacious flatbed.",
    single_spec_1: "Payload capacity up to 1,500 kg (1.5 ton)",
    single_spec_2: "Spacious cargo bed (2.4m length × 1.6m width)",
    single_spec_3: "2 seats (Driver + 1 passenger)",
    single_spec_4: "Ideal for furniture, appliances, bulk goods & building materials",
    double_cabin_title: "Double Cabin Utility Truck",
    double_cabin_desc: "The optimal mix of cargo space and passenger transport. Seats 5 people to transport your moving crew and helpers alongside your goods.",
    double_spec_1: "Payload capacity up to 1,000 kg (1.0 ton)",
    double_spec_2: "Spacious 5-passenger crew cabin",
    double_spec_3: "Perfect for household relocations with helper teams",
    double_spec_4: "Maximum comfort and safety on long inter-wilaya routes",

    // Features Section
    feat_badge: "Why Tashila?",
    feat_title: "Modern, Reliable On-Demand Logistics",
    feat_subtitle: "No more roadside bargaining or unverified trucks. Everything is digitized, verified, and seamless.",
    feat_1_title: "Instant Map-Based Dispatch",
    feat_1_desc: "Smart algorithm alerts the closest available truck drivers in seconds, saving time and fuel.",
    feat_2_title: "Transparent, Upfront Pricing",
    feat_2_desc: "Fares are calculated upfront based on real kilometers and vehicle type. Zero painful negotiation.",
    feat_3_title: "Verified & Licensed Drivers",
    feat_3_desc: "Every driver undergoes strict identity, driver's license, vehicle registration, and background checks.",
    feat_4_title: "Real-time Live GPS Tracking",
    feat_4_desc: "Monitor your cargo's live location on the map in real time until it reaches the destination.",
    feat_5_title: "Instant Push Alerts & Direct Call",
    feat_5_desc: "Direct in-app calling, chat, and high-priority push notifications at every stage of the delivery.",
    feat_6_title: "24/7 Dedicated Algerian Support",
    feat_6_desc: "Local customer support available around the clock to assist you with any questions or special requests.",

    // How It Works
    how_badge: "Simple & Fast",
    how_title: "How Tashila Works",
    how_step_1_title: "1. Set Pickup & Vehicle",
    how_step_1_desc: "Open the app, choose pickup and drop-off points, and select single or double cabin truck.",
    how_step_2_title: "2. View Fare & Confirm",
    how_step_2_desc: "See the upfront fixed price and tap confirm. The nearest drivers receive the request instantly.",
    how_step_3_title: "3. Safe Pickup & Delivery",
    how_step_3_desc: "Your driver arrives, loads your goods, and delivers safely to destination with cash on delivery.",

    // Driver CTA
    driver_badge: "Partner Network",
    driver_cta_title: "Own a Utility Truck? Maximize Your Daily Income with Tashila",
    driver_cta_desc: "Work on your own terms, receive consistent delivery requests in your wilaya, and get paid directly in cash without middlemen.",
    driver_feat_1: "Complete freedom over your working hours and locations",
    driver_feat_2: "Dozens of verified ride offers every day",
    driver_feat_3: "Direct cash payment upon delivery from clients",
    btn_driver_join: "Join as a Partner Driver",

    // FAQ Section
    faq_badge: "FAQ",
    faq_title: "Frequently Asked Questions",
    faq_q1: "How is the trip price calculated?",
    faq_a1: "Fares are calculated automatically based on exact distance in kilometers and selected truck type, shown upfront before you book.",
    faq_q2: "Is Tashila available across all 58 Wilayas?",
    faq_a2: "Yes! Tashila covers all 58 wilayas across Algeria for both intra-city deliveries and long-distance inter-wilaya trips.",
    faq_q3: "How do I register as a driver?",
    faq_a3: "Download the 'Tashila Driver' app on Google Play, enter your phone number, and upload your driver's license and vehicle documents. Approvals take minutes.",
    faq_q4: "What payment methods are supported?",
    faq_a4: "Payment is made in cash directly to the driver upon delivery. Additional electronic payment options are coming soon.",
    faq_q5: "Is my cargo safe with Tashila drivers?",
    faq_a5: "Yes. All drivers are verified with legal credentials, and every trip is live-tracked via GPS from start to delivery.",

    // Footer & Links
    footer_desc: "Tashila is Algeria's premier digital platform connecting businesses and individuals with on-demand utility truck transport.",
    footer_quick_links: "Quick Links",
    footer_legal: "Legal & Privacy",
    footer_contact: "Contact Us",
    footer_rights: "© 2026 Tashila (Tashila Logistics). All rights reserved.",
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
