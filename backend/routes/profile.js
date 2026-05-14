// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Profile Routes
//  routes/profile.js
//
//  GET /api/v1/profile/patient
//  PUT /api/v1/profile/patient
//  GET /api/v1/profile/driver
//  PUT /api/v1/profile/driver
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { db, userToJson, driverToJson } = require('../database');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

// ── Get patient profile ───────────────────────────────────────────────────────
router.get('/patient', (req, res) => {
  if (req.user.role !== 'patient') return res.status(403).json({ message: 'Forbidden.' });
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);
  if (!user) return res.status(404).json({ message: 'User not found.' });
  return res.json({ user: userToJson(user) });
});

// ── Update patient profile ────────────────────────────────────────────────────
router.put('/patient', (req, res) => {
  if (req.user.role !== 'patient') return res.status(403).json({ message: 'Forbidden.' });

  const { full_name, address, preferred_hospital, emergency_contact } = req.body;

  db.prepare(`
    UPDATE users
    SET full_name = COALESCE(?, full_name),
        address = ?,
        preferred_hospital = ?,
        emergency_contact_name = ?,
        emergency_contact_number = ?,
        updated_at = datetime('now')
    WHERE id = ?
  `).run(
    full_name || null,
    address || null,
    preferred_hospital || null,
    emergency_contact?.name || null,
    emergency_contact?.contact_number || null,
    req.user.id,
  );

  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);
  return res.json({ user: userToJson(user) });
});

// ── Get driver profile ────────────────────────────────────────────────────────
router.get('/driver', (req, res) => {
  if (req.user.role !== 'driver') return res.status(403).json({ message: 'Forbidden.' });
  const driver = db.prepare('SELECT * FROM drivers WHERE id = ?').get(req.user.id);
  if (!driver) return res.status(404).json({ message: 'Driver not found.' });
  return res.json({ driver: driverToJson(driver) });
});

// ── Update driver profile ─────────────────────────────────────────────────────
router.put('/driver', (req, res) => {
  if (req.user.role !== 'driver') return res.status(403).json({ message: 'Forbidden.' });

  const { full_name, contact_number, unit_id, hospital_name, unit_type } = req.body;

  db.prepare(`
    UPDATE drivers
    SET full_name = COALESCE(?, full_name),
        contact_number = COALESCE(?, contact_number),
        unit_id = COALESCE(?, unit_id),
        hospital_name = COALESCE(?, hospital_name),
        unit_type = COALESCE(?, unit_type),
        updated_at = datetime('now')
    WHERE id = ?
  `).run(
    full_name || null,
    contact_number || null,
    unit_id || null,
    hospital_name || null,
    unit_type || null,
    req.user.id,
  );

  const driver = db.prepare('SELECT * FROM drivers WHERE id = ?').get(req.user.id);
  return res.json({ driver: driverToJson(driver) });
});

module.exports = router;
