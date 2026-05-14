// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Main Server
//  server.js
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8000;

// ── Export JWT secret so routes/middleware can import it ──────────────────────
// Change this to a strong random string before going to production!
const JWT_SECRET = process.env.JWT_SECRET || 'resqmove-super-secret-jwt-key-2024';
module.exports.JWT_SECRET = JWT_SECRET;

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/v1/auth',     require('./routes/auth'));
app.use('/api/v1/requests', require('./routes/requests'));
app.use('/api/v1/driver',   require('./routes/driver'));
app.use('/api/v1/profile',  require('./routes/profile'));
app.use('/api/v1/stats',    require('./routes/stats'));

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ok', app: 'ResQMove API', time: new Date().toISOString() });
});

// ── 404 catch-all ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ message: `Route ${req.method} ${req.path} not found.` });
});

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n✅  ResQMove API is running!`);
  console.log(`   Local:   http://localhost:${PORT}`);
  console.log(`   Network: http://<YOUR_IP>:${PORT}`);
  console.log(`\n   Health check: http://localhost:${PORT}/health\n`);
});
