// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Driver Routes
//  routes/driver.js
//
//  GET    /api/v1/driver/requests
//  GET    /api/v1/driver/active-trip
//  GET    /api/v1/driver/trips          ← [BUG FIX] was missing; caused 404
//  PATCH  /api/v1/driver/status
//  POST   /api/v1/driver/requests/:id/accept
//  POST   /api/v1/driver/requests/:id/decline
//  POST   /api/v1/driver/trips/:id/complete
//  GET    /api/v1/driver/stats
//  POST   /api/v1/driver/location
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { db, requestToJson } = require('../database');
const { getTrackingSnapshot } = require('../trackingSnapshot');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth);

// Ensure the caller is a driver
router.use((req, res, next) => {
  if (req.user.role !== 'driver') {
    return res.status(403).json({ message: 'Driver access required.' });
  }
  next();
});

// ── Get all pending requests visible to this driver ───────────────────────────
router.get('/requests', (req, res) => {
  const rows = db.prepare(`
    SELECT * FROM requests WHERE status = 'pending'
    ORDER BY requested_at ASC
  `).all();
  return res.json({ requests: rows.map(requestToJson) });
});

// ── Get this driver's currently active trip ───────────────────────────────────
router.get('/active-trip', (req, res) => {
  const request = db.prepare(`
    SELECT * FROM requests
    WHERE assigned_driver_id = ? AND status IN ('accepted', 'in_progress')
    ORDER BY accepted_at DESC LIMIT 1
  `).get(req.user.id);

  if (!request) return res.json({ request: null });
  return res.json({ request: requestToJson(request) });
});

// ── Get driver's trip history (completed + cancelled) ─────────────────────────
// [BUG FIX] This route was completely missing — the app was calling
// GET /api/v1/driver/trips but only POST /api/v1/driver/trips/:id/complete
// existed, causing the "Route GET /api/v1/driver/trips not found" 404 error.
router.get('/trips', (req, res) => {
  const { status } = req.query;
  const allowedStatuses = ['completed', 'cancelled'];

  // Parse comma-separated status filter, default to both
  const requested = status
    ? status.split(',').map(s => s.trim()).filter(s => allowedStatuses.includes(s))
    : allowedStatuses;

  if (requested.length === 0) {
    return res.status(400).json({ message: 'Invalid status filter.' });
  }

  const placeholders = requested.map(() => '?').join(', ');
  const rows = db.prepare(`
    SELECT * FROM requests
    WHERE assigned_driver_id = ?
      AND status IN (${placeholders})
    ORDER BY
      COALESCE(completed_at, accepted_at, requested_at) DESC
  `).all(req.user.id, ...requested);

  return res.json({ trips: rows.map(requestToJson) });
});

// ── Update driver availability status ─────────────────────────────────────────
router.patch('/status', (req, res) => {
  const { status } = req.body;
  if (!['available', 'busy', 'offline'].includes(status)) {
    return res.status(400).json({ message: 'Invalid status.' });
  }
  db.prepare(`UPDATE drivers SET status = ?, updated_at = datetime('now') WHERE id = ?`)
    .run(status, req.user.id);
  return res.json({ success: true });
});

// ── Accept a request ──────────────────────────────────────────────────────────
router.post('/requests/:id/accept', (req, res) => {
  const request = db.prepare(`SELECT * FROM requests WHERE id = ? AND status = 'pending'`).get(req.params.id);
  if (!request) return res.status(404).json({ message: 'Request not found or already taken.' });

  db.prepare(`
    UPDATE requests
    SET status = 'accepted', assigned_driver_id = ?, accepted_at = datetime('now')
    WHERE id = ?
  `).run(req.user.id, req.params.id);

  db.prepare(`UPDATE drivers SET status = 'busy', updated_at = datetime('now') WHERE id = ?`)
    .run(req.user.id);

  const updated = db.prepare('SELECT * FROM requests WHERE id = ?').get(req.params.id);
  const io = req.app.get('io');
  if (io) {
    const snap = getTrackingSnapshot(req.params.id);
    if (snap) io.to(`track:${req.params.id}`).emit('tracking_update', snap);
  }
  return res.json({ request: requestToJson(updated) });
});

// ── Decline a request ─────────────────────────────────────────────────────────
router.post('/requests/:id/decline', (req, res) => {
  // Simply don't assign — other drivers can still pick it up
  return res.json({ success: true });
});

// ── Complete an active trip ───────────────────────────────────────────────────
router.post('/trips/:id/complete', (req, res) => {
  const request = db.prepare(`
    SELECT * FROM requests WHERE id = ? AND assigned_driver_id = ?
  `).get(req.params.id, req.user.id);

  if (!request) return res.status(404).json({ message: 'Trip not found.' });

  db.prepare(`
    UPDATE requests
    SET status = 'completed', completed_at = datetime('now')
    WHERE id = ?
  `).run(req.params.id);

  db.prepare(`UPDATE drivers SET status = 'available', updated_at = datetime('now') WHERE id = ?`)
    .run(req.user.id);

  const io = req.app.get('io');
  if (io) {
    const snap = getTrackingSnapshot(req.params.id);
    if (snap) io.to(`track:${req.params.id}`).emit('tracking_update', snap);
  }

  return res.json({ success: true });
});

// ── Get today's driver stats ──────────────────────────────────────────────────
router.get('/stats', (req, res) => {
  const tripsCompleted = db.prepare(`
    SELECT COUNT(*) as count FROM requests
    WHERE assigned_driver_id = ? AND status = 'completed'
    AND date(completed_at) = date('now')
  `).get(req.user.id).count;

  const pendingRequests = db.prepare(`
    SELECT COUNT(*) as count FROM requests WHERE status = 'pending'
  `).get().count;

  return res.json({
    trips_completed: tripsCompleted,
    pending_requests: pendingRequests,
    avg_response_time: tripsCompleted > 0 ? '6 min' : '--',
  });
});

// ── Driver pushes their GPS location to server ────────────────────────────────
router.post('/location', (req, res) => {
  const { latitude, longitude } = req.body;
  if (latitude == null || longitude == null) {
    return res.status(400).json({ message: 'latitude and longitude are required.' });
  }

  db.prepare(`
    UPDATE drivers
    SET current_lat = ?, current_lng = ?, location_updated_at = datetime('now'), updated_at = datetime('now')
    WHERE id = ?
  `).run(latitude, longitude, req.user.id);

  const { request_id } = req.body;
  const io = req.app.get('io');
  if (io && request_id) {
    const snap = getTrackingSnapshot(request_id);
    if (snap) {
      io.to(`track:${request_id}`).emit('tracking_update', snap);
    }
  }

  return res.json({ success: true });
});

module.exports = router;
