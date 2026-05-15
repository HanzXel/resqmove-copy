// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Auth Routes
//  routes/auth.js
//
//  POST /api/v1/auth/patient/login
//  POST /api/v1/auth/driver/register
//  POST /api/v1/auth/driver/login
//  POST /api/v1/auth/logout
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { db, userToJson, driverToJson } = require('../database');
const { JWT_SECRET } = require('../server');

const router = express.Router();

// ── Patient Login ─────────────────────────────────────────────────────────────
// Patient side: login by contact number only (no password).
// Auto-creates account if contact number is new.
router.post('/patient/login', (req, res) => {
  const { contact_number } = req.body;
  if (!contact_number) {
    return res.status(400).json({ message: 'contact_number is required.' });
  }

  let user = db.prepare('SELECT * FROM users WHERE contact_number = ?').get(contact_number);

  if (!user) {
    // Auto-register new patient
    const id = uuidv4();
    db.prepare(`
      INSERT INTO users (id, full_name, contact_number)
      VALUES (?, '', ?)
    `).run(id, contact_number);
    user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
  }

  const token = jwt.sign(
    { id: user.id, role: 'patient' },
    JWT_SECRET,
    { expiresIn: '7d' }
  );

  return res.json({
    access_token: token,
    user: userToJson(user),
  });
});

// ── Driver self-registration (no auth) ────────────────────────────────────────
router.post('/driver/register', (req, res) => {
  const {
    driver_id,
    password,
    full_name,
    contact_number,
    unit_id,
    hospital_name,
    unit_type,
  } = req.body;

  if (!driver_id || !password || !full_name) {
    return res.status(400).json({
      message: 'driver_id, password, and full_name are required.',
    });
  }

  const existing = db.prepare('SELECT id FROM drivers WHERE driver_id = ?').get(driver_id);
  if (existing) {
    return res.status(409).json({ message: 'Driver ID already taken.' });
  }

  const id = uuidv4();
  const hash = bcrypt.hashSync(password, 10);
  db.prepare(`
    INSERT INTO drivers (id, full_name, driver_id, password_hash, contact_number, unit_id, hospital_name, unit_type, status, approved)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'offline', 0)
  `).run(
    id,
    full_name,
    driver_id,
    hash,
    contact_number || '',
    unit_id || null,
    hospital_name || null,
    unit_type || null,
  );

  return res.status(201).json({
    success: true,
    message:
      'Account created and is pending approval. An administrator must approve your account before you can sign in.',
  });
});

// ── Driver Login ──────────────────────────────────────────────────────────────
router.post('/driver/login', (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ message: 'username and password are required.' });
  }

  const driver = db.prepare('SELECT * FROM drivers WHERE driver_id = ?').get(username);
  if (!driver) {
    return res.status(401).json({ message: 'Invalid driver ID or password.' });
  }

  const valid = bcrypt.compareSync(password, driver.password_hash);
  if (!valid) {
    return res.status(401).json({ message: 'Invalid driver ID or password.' });
  }

  if (Number(driver.approved) !== 1) {
    return res.status(403).json({
      message:
        'Your driver account is pending approval. Contact dispatch or an administrator.',
    });
  }

  const token = jwt.sign(
    { id: driver.id, role: 'driver' },
    JWT_SECRET,
    { expiresIn: '7d' }
  );

  return res.json({
    access_token: token,
    driver: driverToJson(driver),
  });
});

// ── Logout (stateless JWT — just acknowledge) ─────────────────────────────────
router.post('/logout', (req, res) => {
  return res.json({ success: true });
});

module.exports = router;
