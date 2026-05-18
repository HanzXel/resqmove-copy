import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Simple model for a transport booking
// ─────────────────────────────────────────────────────────────────────────────
class _TransportBooking {
  final String id;
  final String patientName;
  final String pickupAddress;
  final String destinationHospital;
  final String? contactNumber;
  final String scheduledAt;
  String status;

  _TransportBooking({
    required this.id,
    required this.patientName,
    required this.pickupAddress,
    required this.destinationHospital,
    this.contactNumber,
    required this.scheduledAt,
    required this.status,
  });

  factory _TransportBooking.fromJson(Map<String, dynamic> j) {
    return _TransportBooking(
      id: j['id']?.toString() ?? '',
      patientName: j['patient_name']?.toString() ?? 'Patient',
      pickupAddress: j['pickup_address']?.toString() ?? '',
      destinationHospital: j['destination_hospital']?.toString() ?? '',
      contactNumber: j['contact_number']?.toString(),
      scheduledAt: j['scheduled_at']?.toString() ?? '',
      status: j['status']?.toString() ?? 'pending',
    );
  }

  String get formattedSchedule {
    try {
      final dt = DateTime.parse(scheduledAt).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.month}/${dt.day}/${dt.year}  $h:$min $ampm';
    } catch (_) {
      return scheduledAt;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DriverTransportScreen — shows pending non-emergency transport bookings
// ─────────────────────────────────────────────────────────────────────────────
class DriverTransportScreen extends StatefulWidget {
  const DriverTransportScreen({super.key});

  @override
  State<DriverTransportScreen> createState() => _DriverTransportScreenState();
}

class _DriverTransportScreenState extends State<DriverTransportScreen> {
  List<_TransportBooking> _bookings = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await ApiClient.instance.get('/driver/transport');
      if (!mounted) return;
      final list = response.data?['bookings'] as List<dynamic>? ?? [];
      setState(() {
        _loading = false;
        _error = null;
        _bookings = list
            .whereType<Map<String, dynamic>>()
            .map(_TransportBooking.fromJson)
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load transport bookings.';
      });
    }
  }

  Future<void> _acceptBooking(_TransportBooking booking) async {
    HapticFeedback.heavyImpact();
    try {
      await ApiClient.instance.post('/driver/transport/${booking.id}/accept');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Transport booking accepted!',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
      setState(() => _bookings.removeWhere((b) => b.id == booking.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to accept booking.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.crimson,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _callContact(String? number) async {
    if (number == null || number.isEmpty) return;
    HapticFeedback.heavyImpact();
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppTheme.border),
            ),
            title: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00A86B), Color(0xFF00C851)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.success.withOpacity(0.38),
                          blurRadius: 12,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: const Icon(Icons.airport_shuttle_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transport Bookings',
                        style: GoogleFonts.outfit(
                            fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                    Text('Non-emergency scheduled trips',
                        style: GoogleFonts.outfit(
                            fontSize: 10.5, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() => _loading = true);
                    _load();
                  },
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMid),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Summary banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A86B), Color(0xFF009952)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.success.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pending Bookings',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                          Text(
                            _loading
                                ? 'Loading...'
                                : '${_bookings.length} transport request(s) awaiting pickup',
                            style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _loading ? '-' : '${_bookings.length}',
                        style: GoogleFonts.outfit(
                            fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 48),
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          else if (_bookings.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(Icons.airport_shuttle_rounded,
                        color: AppTheme.textLight, size: 34),
                  ),
                  const SizedBox(height: 18),
                  Text('No pending transport bookings',
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                  const SizedBox(height: 8),
                  Text(
                    'Scheduled patient transport requests\nwill appear here when submitted.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textLight, height: 1.5),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) return const SizedBox(height: 16);
                  final booking = _bookings[index - 1];
                  return _TransportCard(
                    booking: booking,
                    onAccept: () => _acceptBooking(booking),
                    onCall: () => _callContact(booking.contactNumber),
                  );
                },
                childCount: _bookings.length + 1,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Transport Booking Card
// ─────────────────────────────────────────────────────────────────────────────
class _TransportCard extends StatelessWidget {
  final _TransportBooking booking;
  final VoidCallback onAccept;
  final VoidCallback onCall;

  const _TransportCard({
    required this.booking,
    required this.onAccept,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.success.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
                color: AppTheme.success.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppTheme.success.withOpacity(0.22)),
                    ),
                    child: const Icon(Icons.airport_shuttle_rounded,
                        color: AppTheme.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking.patientName,
                            style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textDark)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.blue.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.blue.withOpacity(0.2)),
                          ),
                          child: Text('Non-Emergency Transport',
                              style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.blue)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
                height: 1,
                color: AppTheme.border,
                margin: const EdgeInsets.symmetric(horizontal: 16)),

            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Scheduled',
                    value: booking.formattedSchedule,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.location_on_rounded,
                    label: 'Pickup',
                    value: booking.pickupAddress,
                    color: AppTheme.crimson,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.local_hospital_rounded,
                    label: 'Destination',
                    value: booking.destinationHospital,
                    color: AppTheme.blue,
                  ),
                  if (booking.contactNumber != null &&
                      booking.contactNumber!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(
                      icon: Icons.phone_rounded,
                      label: 'Contact',
                      value: booking.contactNumber!,
                      color: AppTheme.success,
                    ),
                  ],
                ],
              ),
            ),

            Container(
                height: 1,
                color: AppTheme.border,
                margin: const EdgeInsets.symmetric(horizontal: 16)),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (booking.contactNumber != null &&
                      booking.contactNumber!.isNotEmpty)
                    GestureDetector(
                      onTap: onCall,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.09),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: AppTheme.success.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_rounded,
                                color: AppTheme.success, size: 17),
                            const SizedBox(width: 6),
                            Text('Call',
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.success)),
                          ],
                        ),
                      ),
                    ),
                  if (booking.contactNumber != null &&
                      booking.contactNumber!.isNotEmpty)
                    const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onAccept,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF00A86B),
                              Color(0xFF00C851),
                              Color(0xFF009952)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: AppTheme.success.withOpacity(0.40),
                                blurRadius: 16,
                                offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('ACCEPT TRANSPORT',
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: AppTheme.textLight,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
            ],
          ),
        ),
      ],
    );
  }
}
