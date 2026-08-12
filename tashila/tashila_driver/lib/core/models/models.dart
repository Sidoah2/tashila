import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Canonical cabin types assigned to the driver (e.g. by admin); not editable in the app.
const String kTruckSingleCabin = 'single_cabin';
const String kTruckDoubleCabin = 'double_cabin';

bool isValidCabinTruckType(String truckType) {
  final t = truckType.trim();
  return t == kTruckSingleCabin || t == kTruckDoubleCabin;
}

/// Maps persisted legacy values to a valid cabin type for routing and display.
String migrateTruckType(String? raw) {
  final t = (raw ?? '').trim();
  if (isValidCabinTruckType(t)) return t;
  return kTruckSingleCabin;
}

enum DocumentType {
  drivingLicense,
  vehicleRegistration,

  /// Exterior photo of the truck (cargo area / vehicle).
  vehiclePhoto,
}

DocumentType? documentTypeFromApiKey(String key) {
  switch (key) {
    case 'drivingLicense':
      return DocumentType.drivingLicense;
    case 'vehicleRegistration':
      return DocumentType.vehicleRegistration;
    case 'vehiclePhoto':
      return DocumentType.vehiclePhoto;
    default:
      return null;
  }
}

List<DriverDocument> mergeServerDocuments(
  List<DriverDocument> existing,
  Map<String, dynamic>? serverDocuments,
) {
  final byType = {for (final doc in existing) doc.type: doc};
  if (serverDocuments != null) {
    for (final entry in serverDocuments.entries) {
      final type = documentTypeFromApiKey(entry.key);
      if (type == null) continue;
      final payload = entry.value;
      if (payload is! Map<String, dynamic>) continue;
      final url = payload['url'] as String?;
      if (url == null || url.trim().isEmpty) continue;
      byType[type] = DriverDocument(
        type: type,
        fileName: Uri.tryParse(url)?.pathSegments.last ?? '${entry.key}.jpg',
        remoteUrl: url,
        status: DocumentUploadStatus.uploaded,
      );
    }
  }
  return DocumentType.values
      .map((type) => byType[type] ?? DriverDocument(type: type))
      .toList(growable: false);
}

enum DocumentUploadStatus { pending, uploaded, failed }

enum AvailabilityStatus { offline, online }

enum TripStatus {
  idle,

  /// Stage 1: driver accepted — heading to client; cancel allowed; "arrived" advances.
  headingToClient,

  /// Stage 2: trip in progress — no cancel; "end trip" when done.
  tripInProgress,

  /// Stage 3: summary + confirm payment.
  tripCompletedSummary,

  /// After payment — rate client, then return to idle.
  awaitingClientRating,
}

bool _looksLikeRemoteUrl(String value) {
  final v = value.trim();
  return v.startsWith('http://') ||
      v.startsWith('https://') ||
      v.startsWith('//');
}

class DriverDocument {
  const DriverDocument({
    required this.type,
    this.fileName,
    this.localFilePath,
    this.remoteUrl,
    this.status = DocumentUploadStatus.pending,
  });

  final DocumentType type;

  /// Human-readable file name (never a remote URL).
  final String? fileName;

  /// On-device path for immediate preview after picking.
  final String? localFilePath;

  /// Cloud / CDN URL returned by the API after upload.
  final String? remoteUrl;
  final DocumentUploadStatus status;

  String? get displayRemoteUrl {
    final remote = remoteUrl?.trim();
    if (remote != null && remote.isNotEmpty) return remote;
    final legacy = fileName?.trim();
    if (legacy != null && legacy.isNotEmpty && _looksLikeRemoteUrl(legacy)) {
      return legacy;
    }
    return null;
  }

  bool get hasUploadedImage {
    if (status != DocumentUploadStatus.uploaded) return false;
    final local = localFilePath?.trim();
    if (local != null && local.isNotEmpty) return true;
    final remote = displayRemoteUrl;
    return remote != null && remote.isNotEmpty;
  }

  String? get displaySubtitle {
    if (!hasUploadedImage) return null;
    final name = fileName?.trim();
    if (name != null && name.isNotEmpty && !_looksLikeRemoteUrl(name)) {
      return name;
    }
    return null;
  }

  DriverDocument copyWith({
    String? fileName,
    String? localFilePath,
    String? remoteUrl,
    DocumentUploadStatus? status,
    bool clearLocalFilePath = false,
  }) {
    return DriverDocument(
      type: type,
      fileName: fileName ?? this.fileName,
      localFilePath: clearLocalFilePath
          ? null
          : (localFilePath ?? this.localFilePath),
      remoteUrl: remoteUrl ?? this.remoteUrl,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'fileName': fileName,
    'localFilePath': localFilePath,
    'remoteUrl': remoteUrl,
    'status': status.name,
  };

  static DriverDocument fromJson(Map<String, dynamic> json) {
    var fileName = json['fileName'] as String?;
    var remoteUrl = json['remoteUrl'] as String?;
    if (fileName != null &&
        _looksLikeRemoteUrl(fileName) &&
        (remoteUrl == null || remoteUrl.isEmpty)) {
      remoteUrl = fileName;
      fileName = Uri.tryParse(fileName)?.pathSegments.last;
    }
    return DriverDocument(
      type: _typeFromJson(json['type']),
      fileName: fileName,
      localFilePath: json['localFilePath'] as String?,
      remoteUrl: remoteUrl,
      status: DocumentUploadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DocumentUploadStatus.pending,
      ),
    );
  }

  static DocumentType _typeFromJson(Object? raw) {
    final name = raw as String?;
    if (name == null) return DocumentType.drivingLicense;
    if (name == 'idCard' || name == 'vehicleInsurance') {
      return DocumentType.vehiclePhoto;
    }
    for (final t in DocumentType.values) {
      if (t.name == name) return t;
    }
    return DocumentType.drivingLicense;
  }
}

class DriverProfile {
  const DriverProfile({
    required this.name,
    required this.phone,
    required this.truckType,
    required this.documents,
    this.documentsApproved = false,
    this.approvalStatus = 'pending',
    this.profilePhotoPath,
    this.avatarUrl,
    this.email = '',
    this.vehiclePlate = '',
    this.vehicleColor = '',
    this.vehicleModel = '',
  });

  final String name;
  final String phone;
  final String email;
  final String truckType;
  final List<DriverDocument> documents;
  final bool documentsApproved;
  /// 'pending' | 'approved' | 'rejected'
  final String approvalStatus;
  final String? profilePhotoPath;
  final String? avatarUrl;
  final String vehiclePlate;
  final String vehicleColor;
  final String vehicleModel;

  bool get isComplete {
    if (name.trim().isEmpty ||
        phone.trim().isEmpty ||
        !isValidCabinTruckType(truckType)) {
      return false;
    }
    for (final t in DocumentType.values) {
      DriverDocument? doc;
      for (final d in documents) {
        if (d.type == t) {
          doc = d;
          break;
        }
      }
      if (doc == null || !doc.hasUploadedImage) {
        return false;
      }
    }
    return true;
  }

  bool get isReadyForDashboard => isComplete && documentsApproved;

  DriverProfile copyWith({
    String? name,
    String? phone,
    String? truckType,
    List<DriverDocument>? documents,
    bool? documentsApproved,
    String? approvalStatus,
    String? profilePhotoPath,
    String? avatarUrl,
    String? email,
    String? vehiclePlate,
    String? vehicleColor,
    String? vehicleModel,
    bool clearProfilePhoto = false,
  }) {
    final String? nextPhoto;
    if (clearProfilePhoto) {
      nextPhoto = null;
    } else if (profilePhotoPath != null) {
      nextPhoto = profilePhotoPath;
    } else {
      nextPhoto = this.profilePhotoPath;
    }
    return DriverProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      truckType: truckType ?? this.truckType,
      documents: documents ?? this.documents,
      documentsApproved: documentsApproved ?? this.documentsApproved,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      profilePhotoPath: nextPhoto,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleModel: vehicleModel ?? this.vehicleModel,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'truckType': truckType,
    'documents': documents.map((d) => d.toJson()).toList(),
    'documentsApproved': documentsApproved,
    'approvalStatus': approvalStatus,
    'profilePhotoPath': profilePhotoPath,
    'avatarUrl': avatarUrl,
    'email': email,
    'vehiclePlate': vehiclePlate,
    'vehicleColor': vehicleColor,
    'vehicleModel': vehicleModel,
  };

  static DriverProfile fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      truckType: migrateTruckType(json['truckType'] as String?),
      documents: _documentsFromJson(json['documents'] as List<dynamic>?),
      documentsApproved: json['documentsApproved'] as bool? ?? false,
      approvalStatus: json['approvalStatus'] as String? ?? 'pending',
      profilePhotoPath: json['profilePhotoPath'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      email: json['email'] as String? ?? '',
      vehiclePlate: json['vehiclePlate'] as String? ?? '',
      vehicleColor: json['vehicleColor'] as String? ?? '',
      vehicleModel: json['vehicleModel'] as String? ?? '',
    );
  }

  static DriverProfile empty() {
    return DriverProfile(
      name: '',
      phone: '',
      truckType: '',
      documents: DocumentType.values
          .map((type) => DriverDocument(type: type))
          .toList(),
    );
  }

  static List<DriverDocument> _documentsFromJson(List<dynamic>? raw) {
    final parsed = (raw ?? const [])
        .map((e) => DriverDocument.fromJson(e as Map<String, dynamic>))
        .toList();
    if (parsed.length >= DocumentType.values.length) {
      return parsed;
    }
    return DocumentType.values.map((type) {
      try {
        return parsed.firstWhere((d) => d.type == type);
      } catch (_) {
        return DriverDocument(type: type);
      }
    }).toList();
  }
}

class IncomingOffer {
  IncomingOffer({
    required this.request,
    required this.expiresAt,
    DateTime? offeredAt,
    this.offerGeneration,
    this.pickupDistanceKm,
  }) : offeredAt = offeredAt ?? DateTime.now().toUtc();

  static const int defaultTtlSeconds = 180; // 3 minutes (180 seconds)

  final TripRequest request;
  final DateTime expiresAt;
  final DateTime offeredAt;
  final int? offerGeneration;
  final double? pickupDistanceKm;

  Duration get remaining => expiresAt.difference(DateTime.now().toUtc());

  int get remainingSeconds => remaining.inSeconds.clamp(0, 3600);

  int get ttlSeconds {
    final secs = expiresAt.difference(offeredAt).inSeconds;
    return secs > 0 ? secs : defaultTtlSeconds;
  }

  static DateTime _parseOfferedAt(String? raw, DateTime expiresAt) {
    if (raw != null && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed.isUtc ? parsed : parsed.toUtc();
      }
    }
    return expiresAt.subtract(const Duration(seconds: defaultTtlSeconds));
  }

  static DateTime parseExpiresAt(String? raw) {
    final now = DateTime.now().toUtc();
    if (raw == null || raw.isEmpty) {
      return now.add(const Duration(seconds: defaultTtlSeconds));
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return now.add(const Duration(seconds: defaultTtlSeconds));
    }
    return parsed.isUtc ? parsed : parsed.toUtc();
  }

  static IncomingOffer? fromSocketPayload(Map<String, dynamic> data) {
    final tripId = data['tripId'] as String?;
    if (tripId == null || tripId.isEmpty) return null;
    final pickup = data['pickup'] as Map<String, dynamic>? ?? {};
    final dropoff = data['dropoff'] as Map<String, dynamic>? ?? {};
    final client = data['client'] as Map<String, dynamic>? ?? {};
    final pickupLat = ((pickup['lat'] as num?) ?? 0).toDouble();
    final pickupLng = ((pickup['lng'] as num?) ?? 0).toDouble();
    final dropoffLat = ((dropoff['lat'] as num?) ?? 0).toDouble();
    final dropoffLng = ((dropoff['lng'] as num?) ?? 0).toDouble();
    final distanceKm = ((data['distanceKm'] as num?) ?? 0).toDouble();
    final minutes = (data['estimatedDurationMinutes'] as num?)?.toInt();
    final expiresAt = parseExpiresAt(data['expiresAt'] as String?);
    final offeredAt = _parseOfferedAt(data['offeredAt'] as String?, expiresAt);
    return IncomingOffer(
      request: TripRequest(
        id: tripId,
        clientName: client['name'] as String? ?? '',
        clientPhone: client['phone'] as String? ?? '',
        pickup: pickup['address'] as String? ?? '$pickupLat,$pickupLng',
        dropOff: dropoff['address'] as String? ?? '$dropoffLat,$dropoffLng',
        fare: ((data['fare'] as num?) ?? 0).toDouble(),
        distanceKm: distanceKm,
        estimatedDurationMinutes: minutes,
        pickupLatLng: LatLng(pickupLat, pickupLng),
        dropOffLatLng: LatLng(dropoffLat, dropoffLng),
        truckType: migrateTruckType(data['truckType'] as String?),
        clientRating:
            ((client['rating'] as num?) ?? (data['clientRating'] as num?))
                ?.toDouble(),
        clientAvatar:
            client['avatarUrl'] as String? ?? data['clientAvatar'] as String?,
      ),
      expiresAt: expiresAt,
      offeredAt: offeredAt,
      offerGeneration: (data['offerGeneration'] as num?)?.toInt(),
      pickupDistanceKm: (data['pickupDistanceKm'] as num?)?.toDouble(),
    );
  }
}

class TripRequest {
  const TripRequest({
    required this.id,
    required this.clientName,
    required this.pickup,
    required this.dropOff,
    required this.fare,
    required this.distanceKm,
    this.estimatedDurationMinutes,
    required this.pickupLatLng,
    required this.dropOffLatLng,
    this.expiresAt,
    this.clientPhone = '',
    this.truckType = '',
    this.clientRating,
    this.clientAvatar,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String clientName;
  final String clientPhone;
  final String truckType;
  final String pickup;
  final String dropOff;
  final double fare;
  final double distanceKm;
  final double? clientRating;
  final String? clientAvatar;

  /// Route ETA in minutes from the platform (null if unknown).
  final int? estimatedDurationMinutes;
  final LatLng pickupLatLng;
  final LatLng dropOffLatLng;
  final DateTime? expiresAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  TripRequest copyWith({
    String? id,
    String? clientName,
    String? clientPhone,
    String? truckType,
    String? pickup,
    String? dropOff,
    double? fare,
    double? distanceKm,
    double? clientRating,
    String? clientAvatar,
    int? estimatedDurationMinutes,
    LatLng? pickupLatLng,
    LatLng? dropOffLatLng,
    DateTime? expiresAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return TripRequest(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      truckType: truckType ?? this.truckType,
      pickup: pickup ?? this.pickup,
      dropOff: dropOff ?? this.dropOff,
      fare: fare ?? this.fare,
      distanceKm: distanceKm ?? this.distanceKm,
      clientRating: clientRating ?? this.clientRating,
      clientAvatar: clientAvatar ?? this.clientAvatar,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      pickupLatLng: pickupLatLng ?? this.pickupLatLng,
      dropOffLatLng: dropOffLatLng ?? this.dropOffLatLng,
      expiresAt: expiresAt ?? this.expiresAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class TripRecord {
  const TripRecord({
    required this.id,
    required this.clientName,
    required this.pickup,
    required this.dropOff,
    required this.distanceKm,
    required this.fare,
    this.estimatedDurationMinutes,
    this.startedAt,
    required this.completedAt,
    this.rating,
    this.comment = '',
    this.goodTraits = const [],
    this.badTraits = const [],
    this.cashConfirmed = false,
    this.status = 'completed',
  });

  final String id;
  final String clientName;
  final String pickup;
  final String dropOff;
  final double distanceKm;
  final double fare;
  final int? estimatedDurationMinutes;
  final DateTime? startedAt;
  final DateTime completedAt;
  final int? rating;
  final String comment;
  final List<String> goodTraits;
  final List<String> badTraits;
  final bool cashConfirmed;
  final String status;

  bool get isCompleted =>
      status == 'completed' ||
      status == 'awaitingCash' ||
      status == 'awaitingPayment';
  bool get isCancelled => status.contains('cancel');

  TripRecord copyWith({
    int? rating,
    String? comment,
    List<String>? goodTraits,
    List<String>? badTraits,
    bool? cashConfirmed,
    int? estimatedDurationMinutes,
    String? status,
  }) {
    return TripRecord(
      id: id,
      clientName: clientName,
      pickup: pickup,
      dropOff: dropOff,
      distanceKm: distanceKm,
      fare: fare,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      startedAt: startedAt,
      completedAt: completedAt,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      goodTraits: goodTraits ?? this.goodTraits,
      badTraits: badTraits ?? this.badTraits,
      cashConfirmed: cashConfirmed ?? this.cashConfirmed,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientName': clientName,
    'pickup': pickup,
    'dropOff': dropOff,
    'distanceKm': distanceKm,
    'fare': fare,
    'estimatedDurationMinutes': estimatedDurationMinutes,
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'rating': rating,
    'comment': comment,
    'goodTraits': goodTraits,
    'badTraits': badTraits,
    'cashConfirmed': cashConfirmed,
    'status': status,
  };

  /// Maps a trip document from `GET /drivers/me/trips`.
  static TripRecord? fromApiTrip(Map<String, dynamic> json) {
    final id = json['id'] ?? json['_id'];
    if (id == null) return null;
    final pickup = json['pickup'] as Map<String, dynamic>? ?? {};
    final dropoff = json['dropoff'] as Map<String, dynamic>? ?? {};
    final status = json['status'] as String? ?? 'completed';
    final completedRaw =
        json['completedAt'] as String? ?? json['updatedAt'] as String?;
    final completedAt = DateTime.tryParse(completedRaw ?? '') ?? DateTime.now();
    final startedRaw = json['startedAt'] as String?;
    return TripRecord(
      id: id.toString(),
      clientName: json['clientName'] as String? ?? '',
      pickup:
          pickup['address'] as String? ?? '${pickup['lat']},${pickup['lng']}',
      dropOff:
          dropoff['address'] as String? ??
          '${dropoff['lat']},${dropoff['lng']}',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      fare: ((json['finalFare'] as num?) ?? (json['fare'] as num?) ?? 0)
          .toDouble(),
      estimatedDurationMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
      startedAt: startedRaw != null ? DateTime.tryParse(startedRaw) : null,
      completedAt: completedAt,
      rating: (json['clientRating'] as num?)?.toInt(),
      comment: json['clientRatingComment'] as String? ?? '',
      cashConfirmed: status == 'completed' || status == 'awaitingCash',
      status: status,
    );
  }

  static TripRecord fromJson(Map<String, dynamic> json) {
    return TripRecord(
      id: json['id'] as String,
      clientName: json['clientName'] as String,
      pickup: json['pickup'] as String? ?? '',
      dropOff: json['dropOff'] as String? ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      fare: (json['fare'] as num).toDouble(),
      estimatedDurationMinutes: json['estimatedDurationMinutes'] as int?,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      rating: json['rating'] as int?,
      comment: json['comment'] as String? ?? '',
      goodTraits: (json['goodTraits'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      badTraits: (json['badTraits'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      cashConfirmed: json['cashConfirmed'] as bool? ?? false,
      status: json['status'] as String? ?? 'completed',
    );
  }
}

class EarningsSummary {
  const EarningsSummary({
    required this.todayTotal,
    required this.weekTotal,
    required this.todayTrips,
    required this.weekTrips,
  });

  final double todayTotal;
  final double weekTotal;
  final int todayTrips;
  final int weekTrips;
}

/// Platform earnings from `GET /drivers/me/earnings`.
class DriverPlatformEarnings {
  const DriverPlatformEarnings({
    this.totalEarnedDzd = 0,
    this.platformDueDzd = 0,
    this.paidDzd = 0,
  });

  final double totalEarnedDzd;
  final double platformDueDzd;
  final double paidDzd;

  double get netDzd => totalEarnedDzd - platformDueDzd;

  static DriverPlatformEarnings fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DriverPlatformEarnings();
    double read(String key) => (json[key] as num?)?.toDouble() ?? 0;

    return DriverPlatformEarnings(
      totalEarnedDzd: read('totalEarnedDzd'),
      platformDueDzd: read('platformDueDzd'),
      paidDzd: read('paidDzd'),
    );
  }
}

String encodeTrips(List<TripRecord> trips) =>
    jsonEncode(trips.map((t) => t.toJson()).toList());

List<TripRecord> decodeTrips(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((e) => TripRecord.fromJson(e as Map<String, dynamic>))
      .toList();
}
