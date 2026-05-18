import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/request_service.dart';
import '../services/tracking_service.dart';
import '../services/notification_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();

  bool _loading = true;
  AmbulanceRequestModel? _request;
  TrackingSnapshot? _snapshot;
  StreamSubscription<TrackingSnapshot>? _sub;
  String? _driverContactNumber;
  Timer? _pollTimer;

  // Track status transitions to show modals
  RequestStatus? _prevStatus;
  bool _acceptedModalShown = false;
  bool _arrivedModalShown = false;

  LatLng get _pickup {
    final r = _request;
    if (r == null) return const LatLng(10.3157, 123.8854);
    return LatLng(r.pickupLocation.latitude, r.pickupLocation.longitude);
  }

  LatLng? get _ambulance {
    final loc = _snapshot?.driverLocation;
    if (loc == null) return null;
    return LatLng(loc.latitude, loc.longitude);
  }

  LatLng get _mapCenter {
    final a = _ambulance;
    if (a == null) return _pickup;
    return LatLng(
      (a.latitude + _pickup.latitude) / 2,
      (a.longitude + _pickup.longitude) / 2,
    );
  }

  _TrackingUiState get _state => _buildUiState();

  _TrackingUiState _buildUiState() {
    final r = _request;
    if (r == null) {
      return const _TrackingUiState(
        status: 'NO ACTIVE REQUEST',
        statusColor: AppTheme.textLight,
        eta: '--',
        unitId: '—',
        subtitle: 'When you have an active ambulance request, live tracking appears here.',
        distance: '—',
        stepsDone: [false, false, false],
        stepsActive: [false, false, false],
      );
    }
    final st = _snapshot?.status ?? r.status;
    String statusLabel;
    Color statusColor;
    switch (st) {
      case RequestStatus.pending:
        statusLabel = 'WAITING FOR DRIVER';
        statusColor = AppTheme.warning;
        break;
      case RequestStatus.accepted:
        statusLabel = 'AMBULANCE EN ROUTE';
        statusColor = AppTheme.blue;
        break;
      case RequestStatus.inProgress:
        statusLabel = 'AMBULANCE ARRIVED';
        statusColor = AppTheme.success;
        break;
      case RequestStatus.completed:
        statusLabel = 'COMPLETED';
        statusColor = AppTheme.success;
        break;
      case RequestStatus.cancelled:
        statusLabel = 'CANCELLED';
        statusColor = AppTheme.textLight;
        break;
      case RequestStatus.declined:
        statusLabel = 'DECLINED';
        statusColor = AppTheme.textLight;
        break;
    }

    final eta = (_snapshot?.etaMinutes != null)
        ? '${_snapshot!.etaMinutes} min'
        : '--';

    final addr = r.pickupLocation.address?.trim();
    final subtitle = (addr != null && addr.isNotEmpty)
        ? addr
        : 'Pickup: ${r.pickupLocation.latitude.toStringAsFixed(4)}, ${r.pickupLocation.longitude.toStringAsFixed(4)}';

    final done1 = st != RequestStatus.pending;
    final done2 = st == RequestStatus.inProgress ||
        st == RequestStatus.completed ||
        st == RequestStatus.cancelled;
    final done3 = st == RequestStatus.completed;

    return _TrackingUiState(
      status: statusLabel,
      statusColor: statusColor,
      eta: eta,
      unitId: 'Ambulance',
      subtitle: subtitle,
      distance: '--',
      stepsDone: [true, done1 && done2, done3],
      stepsActive: [
        st == RequestStatus.pending,
        st == RequestStatus.accepted,
        st == RequestStatus.inProgress,
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollActiveRequest());
  }

  Future<void> _bootstrap() async {
    final res = await RequestService.instance.getActiveRequest();
    if (!mounted) return;

    if (!res.success || res.request == null || res.request!.id == null) {
      setState(() {
        _loading = false;
        _request = null;
      });
      return;
    }

    final id = res.request!.id!;
    setState(() {
      _loading = false;
      _request = res.request;
      _prevStatus = res.request!.status;
      // Reset modal flags for this request
      _acceptedModalShown = false;
      _arrivedModalShown = false;
    });

    final driverId = res.request!.assignedDriverId;
    if (driverId != null && driverId.isNotEmpty) {
      unawaited(_fetchDriverContact(driverId));
    }

    TrackingService.instance.startTracking(id);
    _sub = TrackingService.instance.trackingStream.listen((snap) {
      if (!mounted) return;

      final newStatus = snap.status;
      final oldStatus = _prevStatus;

      setState(() {
        _snapshot = snap;
        _prevStatus = newStatus;
      });

      // Show acceptance modal when status transitions to accepted
      if (!_acceptedModalShown &&
          oldStatus == RequestStatus.pending &&
          newStatus == RequestStatus.accepted) {
        _acceptedModalShown = true;
        unawaited(NotificationService.instance.showLocal(
          title: '🚑 Request Accepted!',
          body: 'A driver has accepted your emergency request and is on the way.',
        ));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAcceptedModal();
        });
      }

      // Show arrived modal when status transitions to in_progress
      if (!_arrivedModalShown &&
          (oldStatus == RequestStatus.accepted || oldStatus == RequestStatus.pending) &&
          newStatus == RequestStatus.inProgress) {
        _arrivedModalShown = true;
        unawaited(NotificationService.instance.showLocal(
          title: '📍 Ambulance Arrived!',
          body: 'The ambulance has arrived at your location. Please confirm when ready.',
        ));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showArrivedModal();
        });
      }

      // Handle completion — reset tracking page
      if (newStatus == RequestStatus.completed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleTripCompleted();
        });
      }

      final newDriverId = _request?.assignedDriverId;
      if (_driverContactNumber == null &&
          newDriverId != null &&
          newDriverId.isNotEmpty) {
        unawaited(_fetchDriverContact(newDriverId));
      }
    });
  }

  Future<void> _pollActiveRequest() async {
    if (_loading) return;
    final res = await RequestService.instance.getActiveRequest();
    if (!mounted) return;

    // If no active request and we had one — it was completed/cancelled externally
    if (!res.success || res.request == null) {
      if (_request != null &&
          (_request!.status == RequestStatus.completed ||
           _request!.status == RequestStatus.cancelled)) {
        _resetForNewRequest();
      }
      return;
    }

    final newStatus = res.request!.status;
    final oldStatus = _prevStatus;

    if (_request == null) {
      setState(() {
        _request = res.request;
        _prevStatus = newStatus;
        _acceptedModalShown = false;
        _arrivedModalShown = false;
      });
      unawaited(_bootstrap());
      return;
    }

    setState(() { _request = res.request; });

    if (!_acceptedModalShown &&
        oldStatus == RequestStatus.pending &&
        newStatus == RequestStatus.accepted) {
      _acceptedModalShown = true;
      setState(() => _prevStatus = newStatus);
      unawaited(NotificationService.instance.showLocal(
        title: '🚑 Request Accepted!',
        body: 'A driver has accepted your emergency request and is on the way.',
      ));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAcceptedModal();
      });
    } else if (!_arrivedModalShown &&
        (oldStatus == RequestStatus.accepted || oldStatus == RequestStatus.pending) &&
        newStatus == RequestStatus.inProgress) {
      _arrivedModalShown = true;
      setState(() => _prevStatus = newStatus);
      unawaited(NotificationService.instance.showLocal(
        title: '📍 Ambulance Arrived!',
        body: 'The ambulance has arrived at your location. Please confirm when ready.',
      ));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showArrivedModal();
      });
    } else if (newStatus == RequestStatus.completed && oldStatus != RequestStatus.completed) {
      setState(() => _prevStatus = newStatus);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleTripCompleted();
      });
    } else if (newStatus != oldStatus) {
      setState(() => _prevStatus = newStatus);
    }

    final driverId = res.request!.assignedDriverId;
    if (_driverContactNumber == null &&
        driverId != null &&
        driverId.isNotEmpty) {
      unawaited(_fetchDriverContact(driverId));
    }
  }

  /// Called when the driver completes the trip — resets the tracking page
  /// so the patient is ready to submit a new request.
  void _handleTripCompleted() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A86B), Color(0xFF009952)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.success.withOpacity(0.40),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              Text(
                'Trip Completed!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your trip has been completed. Thank you for using ResQMove!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid, height: 1.5),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _resetForNewRequest();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00A86B), Color(0xFF009952)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.success.withOpacity(0.40),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Text(
                    'DONE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resets state so the tracking screen is clean for a new request
  void _resetForNewRequest() {
    _sub?.cancel();
    _sub = null;
    TrackingService.instance.stopTracking();
    if (mounted) {
      setState(() {
        _request = null;
        _snapshot = null;
        _prevStatus = null;
        _acceptedModalShown = false;
        _arrivedModalShown = false;
        _driverContactNumber = null;
      });
    }
  }

  // Modal that notifies the user their request has been accepted
  void _showAcceptedModal() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.blue.withOpacity(0.40),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.airport_shuttle_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              Text(
                'Request Accepted!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A driver has accepted your emergency request and is on the way to your location.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid, height: 1.5),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.blue.withOpacity(0.22)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppTheme.blue, size: 16),
                    const SizedBox(width: 7),
                    Text(
                      'Track the ambulance below',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.blue.withOpacity(0.40),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Text(
                    'GOT IT',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modal shown when the driver marks arrived (status → in_progress).
  /// User taps "CONFIRM ARRIVED" which resets the page for a new request.
  void _showArrivedModal() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFE53935)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.40),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              Text(
                'Ambulance Arrived!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The ambulance has arrived at your location. Please go to the vehicle and confirm when you are ready.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid, height: 1.5),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                  // Reset tracking page so it's ready for a new request
                  _resetForNewRequest();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00A86B), Color(0xFF009952)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.success.withOpacity(0.40),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Text(
                    'CONFIRM ARRIVED',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchDriverContact(String driverId) async {
    try {
      final response = await ApiClient.instance.get('/driver/$driverId/contact');
      final contact = response.data?['contact_number']?.toString();
      if (contact != null && contact.isNotEmpty && mounted) {
        setState(() => _driverContactNumber = contact);
      }
    } catch (_) {}
  }

  Future<void> _callDriver() async {
    HapticFeedback.heavyImpact();
    final number = _driverContactNumber ?? AppConfig.hotlineNumber;
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pollTimer?.cancel();
    TrackingService.instance.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_request == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FC),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined,
                      size: 72, color: AppTheme.textLight.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  Text('No active trip',
                      style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 10),
                  Text(
                    'When you submit an emergency request and a unit is assigned, you can follow the ambulance here in real time.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: AppTheme.textMid, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final amb = _ambulance;
    final pickup = _pickup;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                // ── Map ──
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(32)),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: 14.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.resqmove.app',
                      ),
                      if (amb != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [amb, pickup],
                              color: AppTheme.crimson,
                              strokeWidth: 5,
                              borderColor: AppTheme.crimson.withOpacity(0.2),
                              borderStrokeWidth: 10,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pickup,
                            width: 56,
                            height: 56,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.blue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppTheme.blue.withOpacity(0.5),
                                      blurRadius: 16,
                                      spreadRadius: 3)
                                ],
                              ),
                              child: const Icon(Icons.person_pin_rounded,
                                  color: Colors.white, size: 26),
                            ),
                          ),
                          if (amb != null)
                            Marker(
                              point: amb,
                              width: 64,
                              height: 64,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF1A35),
                                      AppTheme.crimson
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppTheme.crimson.withOpacity(0.6),
                                        blurRadius: 22,
                                        spreadRadius: 4)
                                  ],
                                ),
                                child: const Icon(Icons.airport_shuttle_rounded,
                                    color: Colors.white, size: 28),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Top overlay bar ──
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          _MapPill(
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppTheme.warning.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.timer_rounded,
                                      color: AppTheme.warning, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ETA',
                                        style: GoogleFonts.outfit(
                                            fontSize: 9.5,
                                            color: AppTheme.textLight,
                                            fontWeight: FontWeight.w500)),
                                    Text(_state.eta,
                                        style: GoogleFonts.outfit(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.warning)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _callDriver,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 11),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00C851),
                                    Color(0xFF00962D)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          AppTheme.success.withOpacity(0.45),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_rounded,
                                      color: Colors.white, size: 17),
                                  const SizedBox(width: 7),
                                  Text(
                                    _driverContactNumber != null
                                        ? 'Call Driver'
                                        : 'Call Hotline',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 18,
                  left: 16,
                  child: _MapPill(
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.crimson,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: AppTheme.crimson.withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1)
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Live Tracking',
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textDark)),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  bottom: 18,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      _mapController.move(_mapCenter, 14.5);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10)
                        ],
                      ),
                      child: const Icon(Icons.my_location_rounded,
                          color: AppTheme.blue, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom panel ──
          _TrackingPanel(state: _state),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MAP PILL WIDGET
// ─────────────────────────────────────────────
class _MapPill extends StatelessWidget {
  final Widget child;
  const _MapPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 14)
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
//  TRACKING PANEL
// ─────────────────────────────────────────────
class _TrackingPanel extends StatelessWidget {
  final _TrackingUiState state;
  const _TrackingPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppTheme.border.withOpacity(0.6)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 32, offset: Offset(0, -8))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 18),

          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: state.statusColor.withOpacity(0.09),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: state.statusColor.withOpacity(0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulsingStatusDot(color: state.statusColor),
                  const SizedBox(width: 10),
                  Text(state.status,
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: state.statusColor,
                          letterSpacing: 0.8)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.surfaceLight, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF0F0), Color(0xFFFFDFDF)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppTheme.crimson.withOpacity(0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.crimson.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Icon(Icons.airport_shuttle_rounded,
                      color: AppTheme.crimson, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.unitId,
                          style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark)),
                      const SizedBox(height: 3),
                      Text(state.subtitle,
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textLight,
                              height: 1.3)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.success.withOpacity(0.25)),
                      ),
                      child: Text(state.distance,
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Column(
              children: [
                _ProgressStep(
                  icon: Icons.check_circle_rounded,
                  label: 'Booking Confirmed',
                  time: state.stepsDone[0] ? 'Done' : 'Pending',
                  done: state.stepsDone[0],
                  active: state.stepsActive[0],
                  isLast: false,
                ),
                _ProgressStep(
                  icon: Icons.airport_shuttle_rounded,
                  label: 'Ambulance Dispatched',
                  time: state.stepsDone[1] ? 'Done' : 'Pending',
                  done: state.stepsDone[1],
                  active: state.stepsActive[1],
                  isLast: false,
                ),
                _ProgressStep(
                  icon: Icons.location_on_rounded,
                  label: state.stepsActive[2]
                      ? 'Ambulance Arrived — Confirm to proceed'
                      : 'Arriving at Your Location',
                  time: state.stepsDone[2] ? 'Done' : 'Pending',
                  done: state.stepsDone[2],
                  active: state.stepsActive[2],
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  DATA
// ─────────────────────────────────────────────
class _TrackingUiState {
  final String status;
  final Color statusColor;
  final String eta;
  final String unitId;
  final String subtitle;
  final String distance;
  final List<bool> stepsDone;
  final List<bool> stepsActive;

  const _TrackingUiState({
    required this.status,
    required this.statusColor,
    required this.eta,
    required this.unitId,
    required this.subtitle,
    required this.distance,
    required this.stepsDone,
    required this.stepsActive,
  });
}

// ─────────────────────────────────────────────
//  PULSING DOT
// ─────────────────────────────────────────────
class _PulsingStatusDot extends StatefulWidget {
  final Color color;
  const _PulsingStatusDot({required this.color});

  @override
  State<_PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<_PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.25 + _ctrl.value * 0.4),
              blurRadius: 3 + _ctrl.value * 6,
              spreadRadius: _ctrl.value * 2,
            )
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PROGRESS STEP
// ─────────────────────────────────────────────
class _ProgressStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final bool done;
  final bool active;
  final bool isLast;

  const _ProgressStep({
    required this.icon,
    required this.label,
    required this.time,
    this.done = false,
    this.active = false,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        done ? AppTheme.success : (active ? AppTheme.warning : AppTheme.textLight);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: color.withOpacity(done || active ? 0.35 : 0.15)),
                ),
                child: Icon(
                  done ? Icons.check_rounded : icon,
                  color: color,
                  size: 18,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 16,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        done ? AppTheme.success.withOpacity(0.3) : AppTheme.border,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w400,
                        color: active
                            ? AppTheme.textDark
                            : (done ? AppTheme.textMid : AppTheme.textLight)),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.18)),
                  ),
                  child: Text(time,
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
