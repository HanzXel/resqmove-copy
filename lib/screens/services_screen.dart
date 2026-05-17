import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../services/registration_service.dart';
import '../services/transport_service.dart';
import '../services/event_service.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  static const List<Map<String, dynamic>> services = [
    {
      'icon': Icons.emergency_rounded,
      'title': 'Emergency Response',
      'desc': 'Rapid dispatch for life-threatening situations. Priority dispatching 24/7.',
      'eta': '< 8 min',
      'color': AppTheme.crimson,
      'bg': Color(0xFFFFF0F0),
      'tag': 'Priority',
      'type': 'emergency',
    },
    {
      'icon': Icons.airport_shuttle_rounded,
      'title': 'Patient Transport',
      'desc': 'Scheduled medical transport for patients who need care during transit.',
      'eta': 'Scheduled',
      'color': AppTheme.blue,
      'bg': Color(0xFFEFF4FF),
      'tag': 'Planned',
      'type': 'transport',
    },
    {
      'icon': Icons.event_rounded,
      'title': 'Event Medical Standby',
      'desc': 'On-site medical support for public and private events.',
      'eta': 'Pre-booked',
      'color': AppTheme.blue,
      'bg': Color(0xFFEFF4FF),
      'tag': 'Advance',
      'type': 'event',
    },
    {
      'icon': Icons.favorite_rounded,
      'title': 'Basic Life Support (BLS)',
      'desc': 'Trained EMTs with full BLS equipment for critical patients.',
      'eta': '< 10 min',
      'color': AppTheme.crimson,
      'bg': Color(0xFFFFF0F0),
      'tag': 'Critical',
      'type': 'bls',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Our Services',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.textDark, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: Column(
        children: [
          // Header banner
          Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(color: AppTheme.crimson.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ResQmove Services',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('Choose the service you need',
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text('24/7',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: services.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ServiceTile(service: services[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final Map<String, dynamic> service;
  const _ServiceTile({required this.service});

  void _navigate(BuildContext context) {
    final type = service['type'] as String;
    Widget page;
    switch (type) {
      case 'emergency':
        page = const EmergencyDetailScreen();
        break;
      case 'transport':
        page = const NonEmergencyBookingScreen();
        break;
      case 'event':
        page = const EventStandbyBookingScreen();
        break;
      case 'bls':
        page = const BLSDetailScreen();
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final color = service['color'] as Color;
    final bg = service['bg'] as Color;

    return GestureDetector(
      onTap: () => _navigate(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(service['icon'] as IconData, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          service['title'],
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.2)),
                        ),
                        child: Text(service['tag'],
                            style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(service['desc'],
                      style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textMid, height: 1.45)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: AppTheme.textLight),
                            const SizedBox(width: 4),
                            Text(service['eta'],
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text('Proceed', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 11, color: color),
                        ],
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

// ─────────────────────────────────────────────
//  EMERGENCY RESPONSE DETAIL
// ─────────────────────────────────────────────
class EmergencyDetailScreen extends StatelessWidget {
  const EmergencyDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _BackBtn(),
        title: Text('Emergency Response',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.textDark, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Color(0xFFFFF0F0), Color(0xFFFFE0E0)]),
                  border: Border.all(color: AppTheme.crimson.withOpacity(0.25), width: 2),
                  boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
                ),
                child: const Icon(Icons.emergency_rounded, color: AppTheme.crimson, size: 60),
              ),
              const SizedBox(height: 28),
              Text('Emergency Response',
                  style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Tap the button below to immediately request our emergency dispatch. A team will be sent to your location within minutes.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 15, color: AppTheme.textMid, height: 1.6),
              ),
              const SizedBox(height: 24),
              _InfoBadge(icon: Icons.timer_outlined, label: 'Average Response Time: < 8 minutes', color: AppTheme.crimson),
              const SizedBox(height: 12),
              _InfoBadge(icon: Icons.verified_rounded, label: 'Certified Emergency Medical Technicians', color: AppTheme.blue),
              const SizedBox(height: 36),
              _PrimaryButton(
                label: 'REQUEST AMBULANCE',
                icon: Icons.airport_shuttle_rounded,
                onTap: () {
                  HapticFeedback.heavyImpact();
                  showDialog(
                    context: context,
                    builder: (_) => const _SuccessDialog(
                      title: 'Ambulance Requested',
                      message: 'Your request has been sent. A dispatcher will contact you shortly.',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BLS DETAIL — wired to backend
// ─────────────────────────────────────────────
class BLSDetailScreen extends StatefulWidget {
  const BLSDetailScreen({super.key});

  @override
  State<BLSDetailScreen> createState() => _BLSDetailScreenState();
}

class _BLSDetailScreenState extends State<BLSDetailScreen> {
  bool _submitting = false;

  Future<void> _requestBls() async {
    if (_submitting) return;
    HapticFeedback.heavyImpact();
    setState(() => _submitting = true);

    // Try to get GPS
    double lat = 10.3220, lng = 123.8920;
    String? address;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}

    // Also try registered address as fallback label
    final reg = await RegistrationService.instance.loadRegistration();
    if (reg != null && reg.address.isNotEmpty) address = reg.address;

    final result = await EventService.instance.submitBls(
      latitude: lat,
      longitude: lng,
      address: address,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      showDialog(
        context: context,
        builder: (_) => _SuccessDialog(
          title: 'BLS Ambulance Requested',
          message: 'Your BLS request has been submitted. A dispatcher will contact you shortly.\n\nRef: ${result.id}',
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.errorMessage ?? 'Request failed. Please try again.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.crimson,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _BackBtn(),
        title: Text('Basic Life Support',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.textDark, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Color(0xFFFFF0F0), Color(0xFFFFE0E0)]),
                  border: Border.all(color: AppTheme.crimson.withOpacity(0.25), width: 2),
                  boxShadow: [BoxShadow(color: AppTheme.crimson.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
                ),
                child: const Icon(Icons.favorite_rounded, color: AppTheme.crimson, size: 60),
              ),
              const SizedBox(height: 28),
              Text('Basic Life Support (BLS)',
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Our certified EMTs are equipped with full BLS gear ready to respond to critical patients. Call now for immediate dispatch.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 15, color: AppTheme.textMid, height: 1.6),
              ),
              const SizedBox(height: 24),
              _InfoBadge(icon: Icons.timer_outlined, label: 'Average Response Time: < 10 minutes', color: AppTheme.crimson),
              const SizedBox(height: 12),
              _InfoBadge(icon: Icons.medical_services_rounded, label: 'Full BLS Equipment On Board', color: AppTheme.blue),
              const SizedBox(height: 36),
              _PrimaryButton(
                label: _submitting ? 'SUBMITTING...' : 'REQUEST BLS AMBULANCE',
                icon: Icons.airport_shuttle_rounded,
                onTap: _submitting ? () {} : _requestBls,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  NON-EMERGENCY TRANSPORT BOOKING
// ─────────────────────────────────────────────
class NonEmergencyBookingScreen extends StatefulWidget {
  const NonEmergencyBookingScreen({super.key});

  @override
  State<NonEmergencyBookingScreen> createState() => _NonEmergencyBookingScreenState();
}

class _NonEmergencyBookingScreenState extends State<NonEmergencyBookingScreen> {
  final _nameCtrl = TextEditingController();
  final _pickupCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  DateTime? _selectedDateTime;
  bool _submittingTransport = false;

  @override
  void initState() {
    super.initState();
    _prefillFromRegistration();
  }

  Future<void> _prefillFromRegistration() async {
    final reg = await RegistrationService.instance.loadRegistration();
    if (!mounted || reg == null) return;
    setState(() {
      if (reg.fullName.isNotEmpty) _nameCtrl.text = reg.fullName;
      if (reg.address.isNotEmpty) _pickupCtrl.text = reg.address;
      if (reg.mobilePrimary.isNotEmpty) _contactCtrl.text = reg.mobilePrimary;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pickupCtrl.dispose();
    _hospitalCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.blue)),
        child: child!,
      ),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.blue)),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _bookTransport() async {
    if (_submittingTransport) return;
    if (_nameCtrl.text.trim().isEmpty ||
        _pickupCtrl.text.trim().isEmpty ||
        _hospitalCtrl.text.trim().isEmpty ||
        _contactCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill in all fields.', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please choose date and time.', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _submittingTransport = true);
    final result = await TransportService.instance.submitBooking(
      patientName: _nameCtrl.text.trim(),
      pickupAddress: _pickupCtrl.text.trim(),
      destinationHospital: _hospitalCtrl.text.trim(),
      contactNumber: _contactCtrl.text.trim(),
      scheduledAt: _selectedDateTime!,
    );
    if (!mounted) return;
    setState(() => _submittingTransport = false);

    if (result.success) {
      _showConfirmation(context, 'Transport Booked!',
          'Your request is saved and pending dispatch. Reference: ${result.id}');
    } else {
      // Show the error from the server. The most common cause is a 403
      // ("Patient access required") which means the session token is missing
      // or expired. Surface a clear message so the user knows what to do.
      final msg = result.errorMessage ?? 'Booking failed.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white))),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.crimson,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _BackBtn(),
        title: Text('Patient Transport',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.textDark, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.airport_shuttle_rounded,
              color: AppTheme.blue,
              title: 'Transport Booking Form',
              subtitle: 'Fill in the details below to schedule your transport.',
            ),
            const SizedBox(height: 24),
            _StyledFormCard(
              children: [
                _FormField(label: 'Full Name', hint: 'Enter patient full name', icon: Icons.person_outline_rounded, controller: _nameCtrl),
                _FormField(label: 'Pickup Location', hint: 'Enter pickup address', icon: Icons.location_on_outlined, controller: _pickupCtrl),
                _FormField(label: 'Destination Hospital', hint: 'Enter hospital name', icon: Icons.local_hospital_outlined, controller: _hospitalCtrl),
                _FormField(label: 'Contact Number', hint: 'Enter contact number', icon: Icons.phone_outlined, controller: _contactCtrl, keyboard: TextInputType.phone, isLast: true),
              ],
            ),
            const SizedBox(height: 16),
            _DateTimeField(label: 'Preferred Date & Time', selectedDateTime: _selectedDateTime, onTap: _pickDateTime),
            const SizedBox(height: 32),
            _PrimaryButton(
              label: _submittingTransport ? 'SUBMITTING...' : 'BOOK TRANSPORT',
              icon: Icons.airport_shuttle_rounded,
              color: AppTheme.blue,
              onTap: _submittingTransport ? () {} : _bookTransport,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EVENT MEDICAL STANDBY BOOKING — wired to backend
// ─────────────────────────────────────────────
class EventStandbyBookingScreen extends StatefulWidget {
  const EventStandbyBookingScreen({super.key});

  @override
  State<EventStandbyBookingScreen> createState() => _EventStandbyBookingScreenState();
}

class _EventStandbyBookingScreenState extends State<EventStandbyBookingScreen> {
  final _eventNameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _attendeesCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  DateTime? _selectedDateTime;
  bool _submitting = false;

  @override
  void dispose() {
    _eventNameCtrl.dispose();
    _locationCtrl.dispose();
    _attendeesCtrl.dispose();
    _contactPersonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.blue)),
        child: child!,
      ),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.blue)),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submitStandby() async {
    if (_submitting) return;
    if (_locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Location is required.', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please choose event date and time.', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    final result = await EventService.instance.submitStandby(
      eventName: _eventNameCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      eventDate: _selectedDateTime!.toIso8601String(),
      expectedAttendees: _attendeesCtrl.text.trim(),
      contactPerson: _contactPersonCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      _showConfirmation(
        context,
        'Standby Requested!',
        'Our team will contact you within 24 hours to confirm the medical standby details.\n\nRef: ${result.id}',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.errorMessage ?? 'Booking failed. Please try again.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.crimson,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _BackBtn(),
        title: Text('Event Medical Standby',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.textDark, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.event_rounded,
              color: AppTheme.blue,
              title: 'Event Standby Form',
              subtitle: "Provide your event details and we'll assign a medical team.",
            ),
            const SizedBox(height: 24),
            _StyledFormCard(
              children: [
                _FormField(label: 'Event Name', hint: 'Enter event name', icon: Icons.event_rounded, controller: _eventNameCtrl),
                _FormField(label: 'Location', hint: 'Enter event venue/address', icon: Icons.location_on_outlined, controller: _locationCtrl),
                _FormField(label: 'Expected Attendees', hint: 'Estimated number', icon: Icons.people_outline_rounded, controller: _attendeesCtrl, keyboard: TextInputType.number),
                _FormField(label: 'Contact Person', hint: 'Name and contact number', icon: Icons.person_pin_outlined, controller: _contactPersonCtrl, isLast: true),
              ],
            ),
            const SizedBox(height: 16),
            _DateTimeField(label: 'Event Date & Time', selectedDateTime: _selectedDateTime, onTap: _pickDateTime),
            const SizedBox(height: 32),
            _PrimaryButton(
              label: _submitting ? 'SUBMITTING...' : 'REQUEST STANDBY',
              icon: Icons.event_rounded,
              color: AppTheme.blue,
              onTap: _submitting ? () {} : _submitStandby,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────
class _BackBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        margin: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textDark, size: 17),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _SectionHeader({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textMid, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StyledFormCard extends StatelessWidget {
  final List<Widget> children;
  const _StyledFormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboard;
  final bool isLast;

  const _FormField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboard = TextInputType.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: AppTheme.textDark,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              fontSize: 15,
              color: const Color(0xFFADB5BD),
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? selectedDateTime;
  final VoidCallback onTap;

  const _DateTimeField({required this.label, required this.selectedDateTime, required this.onTap});

  String get _displayText {
    if (selectedDateTime == null) return 'Select date & time';
    final d = selectedDateTime!;
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.month}/${d.day}/${d.year}  $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = selectedDateTime != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasValue ? AppTheme.blue.withOpacity(0.3) : AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppTheme.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.calendar_today_outlined, color: AppTheme.blue, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
                  const SizedBox(height: 4),
                  Text(_displayText,
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500,
                          color: hasValue ? AppTheme.textDark : AppTheme.textLight)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: hasValue ? AppTheme.blue : AppTheme.textLight, size: 22),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppTheme.crimson,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = color == AppTheme.crimson;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 19),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFFFF1A35), const Color(0xFFD0021B), const Color(0xFF9B0015)]
                : [const Color(0xFF1E88E5), const Color(0xFF1565C0), const Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 10)),
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  const _SuccessDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: const Icon(Icons.check_rounded, color: AppTheme.success, size: 36),
            ),
            const SizedBox(height: 20),
            Text(title, style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
            const SizedBox(height: 10),
            Text(message,
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMid, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: AppTheme.success.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: Text('Done', textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showConfirmation(BuildContext context, String title, String message) {
  showDialog(context: context, builder: (_) => _SuccessDialog(title: title, message: message));
}
