// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Event Standby & BLS Booking Routes
//  routes/events.js
//
//  POST  /api/v1/events/standby   — book event medical standby
//  GET   /api/v1/events/mine      — list patient's event bookings
//  POST  /api/v1/events/bls       — request BLS ambulance (alias to requests)
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../database');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

router.use((req, res, next) => {
  if (req.user.role !== 'patient') {
    return res.status(403).json({ message: 'Patient access required.' });
  }
  next();
});

function eventToJson(row) {
  if (!row) return null;
  return {
    id: row.id,
    user_id: row.user_id,
    event_name: row.event_name,
    location: row.location,
    expected_attendees: row.expected_attendees,
    contact_person: row.contact_person,
    event_date: row.event_date,
    status: row.status,
    created_at: row.created_at,
  };
}

// ── Book event medical standby ────────────────────────────────────────────────
router.post('/standby', (req, res) => {
  const {
    event_name,
    location,
    expected_attendees,
    contact_person,
    event_date,
  } = req.body;

  if (!location || !event_date) {
    return res.status(400).json({
      message: 'location and event_date are required.',
    });
  }

  const id = uuidv4();
  db.prepare(`
    INSERT INTO event_standby_bookings
      (id, user_id, event_name, location, expected_attendees, contact_person, event_date, status)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')
  `).run(
    id,
    req.user.id,
    (event_name || '').toString().trim() || 'Unnamed Event',
    location,
    expected_attendees ? expected_attendees.toString() : null,
    contact_person || null,
    event_date,
  );

  const row = db.prepare('SELECT * FROM event_standby_bookings WHERE id = ?').get(id);
  return res.status(201).json({ booking: eventToJson(row) });
});

// ── List this patient's event bookings ────────────────────────────────────────
router.get('/mine', (req, res) => {
  const rows = db.prepare(`
    SELECT * FROM event_standby_bookings
    WHERE user_id = ?
    ORDER BY datetime(created_at) DESC
    LIMIT 40
  `).all(req.user.id);
  return res.json({ bookings: rows.map(eventToJson) });
});

// ── BLS request — creates an emergency request with type 'Basic Life Support' ─
router.post('/bls', (req, res) => {
  const { pickup_location, notes } = req.body;

  if (!pickup_location) {
    return res.status(400).json({ message: 'pickup_location is required.' });
  }

  const userId = req.user.id;

  // Cancel any existing active request first
  db.prepare(`
    UPDATE requests SET status = 'cancelled'
    WHERE user_id = ? AND status IN ('pending', 'accepted', 'in_progress')
  `).run(userId);

  const id = uuidv4();
  db.prepare(`
    INSERT INTO requests (id, user_id, emergency_type, status, pickup_lat, pickup_lng, pickup_address, notes)
    VALUES (?, ?, 'basic_life_support', 'pending', ?, ?, ?, ?)
  `).run(
    id,
    userId,
    pickup_location.latitude,
    pickup_location.longitude,
    pickup_location.address || null,
    notes || null,
  );

  const request = db.prepare('SELECT * FROM requests WHERE id = ?').get(id);

  const { requestToJson } = require('../database');
  return res.status(201).json({ request: requestToJson(request) });
});

module.exports = router;
