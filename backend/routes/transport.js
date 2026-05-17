// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Non-emergency transport bookings
//  routes/transport.js
//
//  POST   /api/v1/transport
//  GET    /api/v1/transport/mine
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../database');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

router.use((req, res, next) => {
  if (req.user.role !== 'patient') {
    return res.status(403).json({
      message: 'This feature is only available to patient accounts. Please log in with a patient account to book transport.',
    });
  }
  next();
});

function bookingToJson(row) {
  if (!row) return null;
  return {
    id: row.id,
    user_id: row.user_id,
    patient_name: row.patient_name,
    pickup_address: row.pickup_address,
    destination_hospital: row.destination_hospital,
    contact_number: row.contact_number,
    scheduled_at: row.scheduled_at,
    status: row.status,
    created_at: row.created_at,
  };
}

router.post('/', (req, res) => {
  const {
    patient_name,
    pickup_address,
    destination_hospital,
    contact_number,
    scheduled_at,
  } = req.body;

  if (!pickup_address || !destination_hospital || !scheduled_at) {
    return res.status(400).json({
      message: 'pickup_address, destination_hospital, and scheduled_at are required.',
    });
  }

  const id = uuidv4();
  const pname = (patient_name || '').toString().trim() || 'Patient';

  db.prepare(`
    INSERT INTO transport_bookings (
      id, user_id, patient_name, pickup_address, destination_hospital, contact_number, scheduled_at, status
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')
  `).run(
    id,
    req.user.id,
    pname,
    pickup_address,
    destination_hospital,
    contact_number || null,
    scheduled_at,
  );

  const row = db.prepare('SELECT * FROM transport_bookings WHERE id = ?').get(id);
  return res.status(201).json({ booking: bookingToJson(row) });
});

router.get('/mine', (req, res) => {
  const rows = db.prepare(`
    SELECT * FROM transport_bookings
    WHERE user_id = ?
    ORDER BY datetime(created_at) DESC
    LIMIT 40
  `).all(req.user.id);
  return res.json({ bookings: rows.map(bookingToJson) });
});

module.exports = router;
