// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — SQLite Database Setup
//  database.js
// ─────────────────────────────────────────────────────────────────────────────

const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, 'resqmove.db');
const db = new Database(DB_PATH);

// Enable WAL mode for better concurrent read performance
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

// ── Schema ────────────────────────────────────────────────────────────────────

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    full_name TEXT NOT NULL DEFAULT '',
    contact_number TEXT NOT NULL UNIQUE,
    address TEXT,
    preferred_hospital TEXT,
    emergency_contact_name TEXT,
    emergency_contact_number TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS drivers (
    id TEXT PRIMARY KEY,
    full_name TEXT NOT NULL DEFAULT '',
    driver_id TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    contact_number TEXT NOT NULL DEFAULT '',
    unit_id TEXT,
    hospital_name TEXT,
    unit_type TEXT,
    status TEXT NOT NULL DEFAULT 'offline',
    current_lat REAL,
    current_lng REAL,
    location_updated_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS requests (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    emergency_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    pickup_lat REAL NOT NULL,
    pickup_lng REAL NOT NULL,
    pickup_address TEXT,
    notes TEXT,
    assigned_driver_id TEXT,
    destination_hospital TEXT,
    requested_at TEXT NOT NULL DEFAULT (datetime('now')),
    accepted_at TEXT,
    completed_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (assigned_driver_id) REFERENCES drivers(id)
  );

  CREATE TABLE IF NOT EXISTS transport_bookings (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    patient_name TEXT NOT NULL DEFAULT '',
    pickup_address TEXT NOT NULL,
    destination_hospital TEXT NOT NULL,
    contact_number TEXT,
    scheduled_at TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS event_standby_bookings (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    event_name TEXT NOT NULL DEFAULT '',
    location TEXT NOT NULL,
    expected_attendees TEXT,
    contact_person TEXT,
    event_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
`);

// ── Schema migrations (additive) ─────────────────────────────────────────────
(() => {
  const cols = db.prepare('PRAGMA table_info(drivers)').all();
  const hasApproved = cols.some((c) => c.name === 'approved');
  if (!hasApproved) {
    db.exec(
      "ALTER TABLE drivers ADD COLUMN approved INTEGER NOT NULL DEFAULT 1",
    );
  }
})();

// ── Helper: map DB driver row → API JSON ──────────────────────────────────────
function driverToJson(row) {
  if (!row) return null;
  return {
    id: row.id,
    full_name: row.full_name,
    driver_id: row.driver_id,
    contact_number: row.contact_number,
    unit_id: row.unit_id,
    hospital_name: row.hospital_name,
    unit_type: row.unit_type,
    status: row.status,
    approved: row.approved !== undefined ? !!row.approved : true,
    current_location: row.current_lat != null ? {
      latitude: row.current_lat,
      longitude: row.current_lng,
      timestamp: row.location_updated_at,
    } : null,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

// ── Helper: map DB user row → API JSON ───────────────────────────────────────
function userToJson(row) {
  if (!row) return null;
  return {
    id: row.id,
    full_name: row.full_name,
    contact_number: row.contact_number,
    address: row.address,
    preferred_hospital: row.preferred_hospital,
    emergency_contact: row.emergency_contact_name ? {
      name: row.emergency_contact_name,
      contact_number: row.emergency_contact_number,
    } : null,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

// ── Helper: map DB request row → API JSON ────────────────────────────────────
function requestToJson(row) {
  if (!row) return null;
  return {
    id: row.id,
    user_id: row.user_id,
    emergency_type: row.emergency_type,
    status: row.status,
    pickup_location: {
      latitude: row.pickup_lat,
      longitude: row.pickup_lng,
      address: row.pickup_address,
    },
    notes: row.notes,
    assigned_driver_id: row.assigned_driver_id,
    destination_hospital: row.destination_hospital,
    requested_at: row.requested_at,
    accepted_at: row.accepted_at,
    completed_at: row.completed_at,
  };
}

module.exports = { db, driverToJson, userToJson, requestToJson };
