// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Request Routes (Patient Side)
//  routes/requests.js
//
//  POST   /api/v1/requests
//  GET    /api/v1/requests/active
//  GET    /api/v1/requests/history
//  GET    /api/v1/requests/:id
//  PATCH  /api/v1/requests/:id/cancel
//  GET    /api/v1/requests/:id/tracking
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { db, requestToJson, driverToJson } = require('../database');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// All request routes require auth
router.use(requireAuth);

// ── Submit a new ambulance request ────────────────────────────────────────────
router.post('/', (req, res) => {
  const { emergency_type, pickup_location, notes } = req.body;

  if (!emergency_type || !pickup_location) {
    return res.status(400).json({ message: 'emergency_type and pickup_location are required.' });
  }

  const userId = req.user.id;

  // Cancel any existing active request from this user first
  db.prepare(`
    UPDATE requests SET status = 'cancelled'
    WHERE user_id = ? AND status IN ('pending', 'accepted', 'in_progress')
  `).run(userId);

  const id = uuidv4();
  db.prepare(`
    INSERT INTO requests (id, user_id, emergency_type, status, pickup_lat, pickup_lng, pickup_address, notes)
    VALUES (?, ?, ?, 'pending', ?, ?, ?, ?)
  `).run(
    id,
    userId,
    emergency_type,
    pickup_location.latitude,
    pickup_location.longitude,
    pickup_location.address || null,
    notes || null,
  );

  const request = db.prepare('SELECT * FROM requests WHERE id = ?').get(id);
  return res.status(201).json({ request: requestToJson(request) });
});

// ── Get active request for this patient ───────────────────────────────────────
// NOTE: must come before /:id route
router.get('/active', (req, res) => {
  const request = db.prepare(`
    SELECT * FROM requests
    WHERE user_id = ? AND status IN ('pending', 'accepted', 'in_progress')
    ORDER BY requested_at DESC LIMIT 1
  `).get(req.user.id);

  if (!request) return res.json({ request: null });
  return res.json({ request: requestToJson(request) });
});

// ── Get request history ───────────────────────────────────────────────────────
router.get('/history', (req, res) => {
  const rows = db.prepare(`
    SELECT * FROM requests WHERE user_id = ?
    ORDER BY requested_at DESC LIMIT 50
  `).all(req.user.id);

  return res.json({ requests: rows.map(requestToJson) });
});

// ── Get a single request ──────────────────────────────────────────────────────
router.get('/:id', (req, res) => {
  const request = db.prepare('SELECT * FROM requests WHERE id = ?').get(req.params.id);
  if (!request) return res.status(404).json({ message: 'Request not found.' });
  return res.json({ request: requestToJson(request) });
});

// ── Cancel a request ──────────────────────────────────────────────────────────
router.patch('/:id/cancel', (req, res) => {
  const request = db.prepare('SELECT * FROM requests WHERE id = ?').get(req.params.id);
  if (!request) return res.status(404).json({ message: 'Request not found.' });
  if (request.user_id !== req.user.id) return res.status(403).json({ message: 'Forbidden.' });

  db.prepare(`UPDATE requests SET status = 'cancelled' WHERE id = ?`).run(req.params.id);
  return res.json({ success: true });
});

// ── Get tracking info for a request (driver location + ETA) ──────────────────
router.get('/:id/tracking', (req, res) => {
  const request = db.prepare('SELECT * FROM requests WHERE id = ?').get(req.params.id);
  if (!request) return res.status(404).json({ message: 'Request not found.' });

  let driverLocation = null;
  let etaMinutes = null;

  if (request.assigned_driver_id) {
    const driver = db.prepare('SELECT * FROM drivers WHERE id = ?').get(request.assigned_driver_id);
    if (driver && driver.current_lat != null) {
      driverLocation = {
        latitude: driver.current_lat,
        longitude: driver.current_lng,
        timestamp: driver.location_updated_at,
      };

      // Simple ETA estimate based on straight-line distance
      if (request.pickup_lat && request.pickup_lng) {
        const distKm = haversineKm(
          driver.current_lat, driver.current_lng,
          request.pickup_lat, request.pickup_lng
        );
        // Assume ~40 km/h average in city
        etaMinutes = Math.max(1, Math.round((distKm / 40) * 60));
      }
    }
  }

  return res.json({
    status: request.status,
    driver_location: driverLocation,
    eta_minutes: etaMinutes,
  });
});

// ── Haversine distance helper ─────────────────────────────────────────────────
function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = deg2rad(lat2 - lat1);
  const dLon = deg2rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
function deg2rad(deg) { return deg * (Math.PI / 180); }

module.exports = router;
