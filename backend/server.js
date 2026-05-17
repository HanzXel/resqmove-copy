// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Main Server
//  server.js
// ─────────────────────────────────────────────────────────────────────────────

// Load .env file so JWT_SECRET persists across restarts (no more ephemeral tokens)
try { require('dotenv').config(); } catch (_) { /* dotenv optional — set env vars manually if needed */ }

const crypto = require('crypto');
const http = require('http');
const express = require('express');
const cors = require('cors');
const { attachSocket } = require('./socket');

const app = express();
const PORT = process.env.PORT || 8000;

// ── JWT secret (never ship a fixed default in production) ────────────────────
function resolveJwtSecret() {
  const fromEnv = process.env.JWT_SECRET;
  if (fromEnv && String(fromEnv).trim().length > 0) {
    if (String(fromEnv).length < 32) {
      console.warn('⚠️  JWT_SECRET should be at least 32 characters for adequate entropy.');
    }
    return String(fromEnv).trim();
  }
  if (process.env.NODE_ENV === 'production') {
    console.error('FATAL: JWT_SECRET must be set when NODE_ENV=production.');
    process.exit(1);
  }
  const ephemeral = crypto.randomBytes(48).toString('hex');
  console.warn(
    '⚠️  JWT_SECRET not set — using an ephemeral dev secret (tokens become invalid after restart).',
  );
  return ephemeral;
}

const JWT_SECRET = resolveJwtSecret();
module.exports.JWT_SECRET = JWT_SECRET;

// ── [FIX 3] Auto-approve all existing pending drivers on startup ──────────────
try {
  const { db } = require('./database');
  const result = db.prepare("UPDATE drivers SET approved = 1 WHERE approved = 0").run();
  if (result.changes > 0) {
    console.log(`✅  Auto-approved ${result.changes} pending driver account(s).`);
  }
} catch (e) {
  console.warn('⚠️  Could not auto-approve drivers:', e.message);
}

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/v1/auth',      require('./routes/auth'));
app.use('/api/v1/requests',  require('./routes/requests'));
app.use('/api/v1/driver',    require('./routes/driver'));
app.use('/api/v1/profile',   require('./routes/profile'));
app.use('/api/v1/transport', require('./routes/transport'));
app.use('/api/v1/stats',     require('./routes/stats'));     // FIX: was missing
app.use('/api/v1/events',    require('./routes/events'));    // FIX: event standby bookings

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ok', app: 'ResQMove API', time: new Date().toISOString() });
});

// ── APK Download ───────────────────────────────────────────────────────────────
app.get('/download', (req, res) => {
  const path = require('path');
  const apkPath = path.join(__dirname, 'resqmove.apk');
  res.download(apkPath, 'ResQMove.apk', (err) => {
    if (err) res.status(404).json({ message: 'APK not found.' });
  });
});

// ── 404 catch-all ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ message: `Route ${req.method} ${req.path} not found.` });
});

// ── HTTP + Socket.io (same port) ─────────────────────────────────────────────
const server = http.createServer(app);
const io = attachSocket(server, JWT_SECRET);
app.set('io', io);

server.listen(PORT, '0.0.0.0', () => {
  console.log(`\n✅  ResQMove API is running!`);
  console.log(`   Local:   http://localhost:${PORT}`);
  console.log(`   Network: http://<YOUR_IP>:${PORT}`);
  console.log(`\n   Health check: http://localhost:${PORT}/health`);
  console.log(`   Socket.io:   same origin (e.g. ws://<YOUR_IP>:${PORT})\n`);
});
