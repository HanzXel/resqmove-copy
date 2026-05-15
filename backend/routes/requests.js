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
const { db, requestToJson } = require('../database');
const { getTrackingSnapshot } = require('../trackingSnapshot');
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

// ── Get tracking info (must be before /:id) ───────────────────────────────────
router.get('/:id/tracking', (req, res) => {
  const request = db.prepare('SELECT * FROM requests WHERE id = ?').get(req.params.id);
  if (!request) return res.status(404).json({ message: 'Request not found.' });

  if (req.user.role === 'patient' && request.user_id !== req.user.id) {
    return res.status(403).json({ message: 'Forbidden.' });
  }
  if (req.user.role === 'driver' && request.assigned_driver_id !== req.user.id) {
    return res.status(403).json({ message: 'Forbidden.' });
  }

  const snap = getTrackingSnapshot(req.params.id);
  if (!snap) return res.status(404).json({ message: 'Request not found.' });
  return res.json(snap);
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
  const io = req.app.get('io');
  if (io) {
    const snap = getTrackingSnapshot(req.params.id);
    if (snap) io.to(`track:${req.params.id}`).emit('tracking_update', snap);
  }
  return res.json({ success: true });
});

module.exports = router;
