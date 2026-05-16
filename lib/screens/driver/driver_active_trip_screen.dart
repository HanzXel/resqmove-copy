import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../config/app_config.dart';
import '../../theme/app_theme.dart';
import '../../services/driver_service.dart';
import '../../services/tracking_service.dart';
import '../../services/background_location_service.dart';
import '../../services/notification_service.dart';
import 'driver_hospital_screen.dart';

class DriverActiveTripScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const DriverActiveTripScreen({super.key, required this.request});

  @override
  State<DriverActiveTripScreen> createState() => _DriverActiveTripScreenState();
}

class _DriverActiveTripScreenState extends State<DriverActiveTripScreen> {
  int _currentStatus = 0;
  Timer? _locationTimer;

  final List<Map<String, dynamic>> _statusSteps = [
    {'label': 'En Route to Patient', 'icon': Icons.airport_shuttle_rounded, 'color': AppTheme.warning},
    {'label': 'Patient Picked Up', 'icon': Icons.person_add_rounded, 'color': AppTheme.blue},
    {'label': 'Arriving at Hospital', 'icon': Icons.local_hospital_rounded, 'color': AppTheme.success},
    {'label': 'Trip Completed', 'icon': Icons.check_circle_rounded, 'color': AppTheme.success},
  ];

  String? get _requestId => widget.request['id']?.toString();

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    final id = _requestId;
    if (AppConfig.useMockApi) return;

    // Initialize background service with a location-push callback
    await BackgroundLocationService.instance.init(
      onLocation: (data) {
        TrackingService.instance.pushDriverLocation(
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
          activeRequestId: data['request_id']?.toString(),
        );
      },
    );

    if (id != null && id.isNotEmpty) {
      await BackgroundLocationService.instance.start(requestId: id);
    }

    // Foreground fallback: also push every 12 s when app is open
    _locationTimer = Timer.periodic(const Duration(seconds: 12), (_) => _pushGps());
    unawaited(_pushGps());
  }

  Future<void> _pushGps() async {
    final id = _requestId;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      await TrackingService.instance.pushDriverLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        activeRequestId: id,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    if (!AppConfig.useMockApi) {
      unawaited(BackgroundLocationService.instance.stop());
    }
    super.dispose();
  }

  Future<void> _advanceStatus() async {
    HapticFeedback.heavyImpact();
    if (_currentStatus == 1) {
      if (!mounted) return;
      // Notify patient that ambulance is picking up
      unawaited(NotificationService.instance.notifyStatusUpdate('Ambulance has arrived — patient being picked up.'));
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => DriverHospitalScreen(request: widget.request)));
      return;
    }
    if (_currentStatus < _statusSteps.length - 1) {
      setState(() => _currentStatus++);
      // Fire status notification
      final label = _statusSteps[_currentStatus]['label'] as String;
      unawaited(NotificationService.instance.notifyStatusUpdate(label));
      return;
    }
    // Final step: complete trip on server
    final id = _requestId;
    if (id != null && id.isNotEmpty && !AppConfig.useMockApi) {
      final res = await DriverService.instance.completeTrip(id);
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? 'Could not complete trip.',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            backgroundColor: AppTheme.crimson,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _cancelTrip() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CancelSheet(
        onConfirm: (reason) {
          Navigator.pop(ctx);
          Navigator.popUntil(context, (route) => route.isFirst);
        },
      ),
    );
  }

  String get _actionLabel {
    switch (_currentStatus) {
      case 0: return 'ARRIVED AT PATIENT';
      case 1: return 'PATIENT PICKED UP';
      case 2: return 'ARRIVED AT HOSPITAL';
      case 3: return 'COMPLETE TRIP';
      default: return 'NEXT';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _statusSteps[_currentStatus];
    final stepColor = currentStep['color'] as Color;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Active Trip', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.textDark, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('IN PROGRESS', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.success)),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status banner ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [stepColor, stepColor.withOpacity(0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: stepColor.withOpacity(0.40), blurRadius: 24, offset: const Offset(0, 10)),
                  BoxShadow(color: stepColor.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: Icon(currentStep['icon'] as IconData, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Status',
                            style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
                        Text(
                          currentStep['label'],
                          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text('Step ${_currentStatus + 1} of ${_statusSteps.length}',
                              style: GoogleFonts.outfit(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── ETA Row ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  _ETAItem(icon: Icons.timer_outlined, label: 'ETA', value: '0', color: AppTheme.warning),
                  _VertDivider(),
                  _ETAItem(icon: Icons.near_me_rounded, label: 'Distance', value: '0', color: AppTheme.blue),
                  _VertDivider(),
                  _ETAItem(icon: Icons.speed_rounded, label: 'Speed', value: '0', color: AppTheme.success),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Patient Details ──
            Row(
              children: [
                Container(width: 3, height: 16,
                  decoration: BoxDecoration(color: AppTheme.crimson, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 9),
                Text('Patient Details', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  _PatientInfoRow(icon: Icons.emergency_rounded, label: 'Emergency',
                      value: (widget.request['emergencyType'] ?? widget.request['emergency_type'] ?? 'Not provided').toString(), color: AppTheme.crimson),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: AppTheme.border, height: 1),
                  ),
                  _PatientInfoRow(icon: Icons.location_on_rounded, label: 'Location',
                      value: (widget.request['location'] ?? 'Not provided').toString(), color: AppTheme.blue),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: AppTheme.border, height: 1),
                  ),
                  _PatientInfoRow(icon: Icons.phone_rounded, label: 'Contact',
                      value: widget.request['contact'] ?? 'Not provided', color: AppTheme.success),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Progress Steps ──
            Row(
              children: [
                Container(width: 3, height: 16,
                  decoration: BoxDecoration(color: AppTheme.blue, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 9),
                Text('Trip Progress', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: List.generate(_statusSteps.length, (i) {
                  final done = i < _currentStatus;
                  final active = i == _currentStatus;
                  final step = _statusSteps[i];
                  final color = done ? AppTheme.success : (active ? (step['color'] as Color) : AppTheme.textLight);
                  final isLast = i == _statusSteps.length - 1;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: done ? AppTheme.success.withOpacity(0.12) : (active ? color.withOpacity(0.12) : AppTheme.surfaceLight),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: done ? AppTheme.success.withOpacity(0.35) : (active ? color.withOpacity(0.4) : AppTheme.border),
                              ),
                            ),
                            child: Icon(
                              done ? Icons.check_rounded : step['icon'] as IconData,
                              color: done ? AppTheme.success : color,
                              size: 18,
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2, height: 28,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: done ? AppTheme.success.withOpacity(0.3) : AppTheme.border,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 28, top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  step['label'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                                    color: active ? AppTheme.textDark : (done ? AppTheme.textMid : AppTheme.textLight),
                                  ),
                                ),
                              ),
                              if (done)
                                const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18)
                              else if (active)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: color.withOpacity(0.25)),
                                  ),
                                  child: Text('Active',
                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),

            const SizedBox(height: 24),

            // ── Action Button ──
            GestureDetector(
              onTap: _advanceStatus,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 19),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      stepColor,
                      Color.lerp(stepColor, Colors.black, 0.18)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: stepColor.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 10)),
                    BoxShadow(color: stepColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(currentStep['icon'] as IconData, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Text(_actionLabel,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 1.0)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Cancel ──
            GestureDetector(
              onTap: _cancelTrip,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel_outlined, color: AppTheme.crimson, size: 19),
                    const SizedBox(width: 9),
                    Text('Cancel Trip',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.crimson)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 44,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.transparent, AppTheme.border, Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  );
}

class _ETAItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ETAItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          Text(label, style: GoogleFonts.outfit(fontSize: 10.5, color: AppTheme.textLight)),
        ],
      ),
    );
  }
}

class _PatientInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _PatientInfoRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CancelSheet extends StatefulWidget {
  final Function(String) onConfirm;
  const _CancelSheet({required this.onConfirm});

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  String? _selectedReason;
  static const List<String> _reasons = [
    'Patient condition stabilized',
    'Wrong location provided',
    'Vehicle breakdown',
    'Patient refused service',
    'Other emergency priority',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 44, height: 4,
            decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.crimson.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppTheme.crimson.withOpacity(0.2)),
                ),
                child: const Icon(Icons.cancel_outlined, color: AppTheme.crimson, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cancel Trip', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                  Text('Select a reason for cancellation', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textLight)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._reasons.map((r) => GestureDetector(
            onTap: () => setState(() => _selectedReason = r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _selectedReason == r ? AppTheme.crimson.withOpacity(0.06) : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedReason == r ? AppTheme.crimson.withOpacity(0.4) : AppTheme.border,
                  width: _selectedReason == r ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedReason == r ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    color: _selectedReason == r ? AppTheme.crimson : AppTheme.textLight,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(r,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark))),
                ],
              ),
            ),
          )),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _selectedReason != null ? () => widget.onConfirm(_selectedReason!) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color: _selectedReason != null ? AppTheme.crimson : AppTheme.surfaceMid,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _selectedReason != null
                    ? [BoxShadow(color: AppTheme.crimson.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 7))]
                    : [],
              ),
              child: Text(
                'Confirm Cancellation',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: _selectedReason != null ? Colors.white : AppTheme.textLight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
