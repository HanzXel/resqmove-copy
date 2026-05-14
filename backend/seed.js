// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Database Seeder
//  seed.js
//
//  Run this ONCE after `npm install` to create demo accounts.
//  Command: node seed.js
//
//  Creates:
//    Driver 1:  ID: DRV-001  Password: resq123
//    Driver 2:  ID: DRV-002  Password: resq123
//    Patient:   Phone: 09171234567  (auto-created on first login)
// ─────────────────────────────────────────────────────────────────────────────

const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { db } = require('./database');

const drivers = [
  {
    id: uuidv4(),
    full_name: 'Juan dela Cruz',
    driver_id: 'DRV-001',
    password: 'resq123',
    contact_number: '09171111111',
    unit_id: 'RESQ-101',
    hospital_name: 'Chong Hua Hospital',
    unit_type: 'ALS',
  },
  {
    id: uuidv4(),
    full_name: 'Maria Santos',
    driver_id: 'DRV-002',
    password: 'resq123',
    contact_number: '09172222222',
    unit_id: 'RESQ-102',
    hospital_name: 'Vicente Sotto Memorial Medical Center',
    unit_type: 'BLS',
  },
];

for (const d of drivers) {
  const existing = db.prepare('SELECT id FROM drivers WHERE driver_id = ?').get(d.driver_id);
  if (existing) {
    console.log(`⚠️  Driver ${d.driver_id} already exists — skipping.`);
    continue;
  }

  const hash = bcrypt.hashSync(d.password, 10);
  db.prepare(`
    INSERT INTO drivers (id, full_name, driver_id, password_hash, contact_number, unit_id, hospital_name, unit_type, status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'offline')
  `).run(d.id, d.full_name, d.driver_id, hash, d.contact_number, d.unit_id, d.hospital_name, d.unit_type);

  console.log(`✅  Created driver: ${d.driver_id} / ${d.password}`);
}

console.log('\n🎉  Seed complete!\n');
console.log('Demo accounts:');
console.log('  Driver 1:  DRV-001 / resq123');
console.log('  Driver 2:  DRV-002 / resq123');
console.log('  Patient:   Just enter any phone number in the app\n');
