// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — JWT Auth Middleware
//  middleware/auth.js
// ─────────────────────────────────────────────────────────────────────────────

const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../server');

function requireAuth(req, res, next) {
  const header = req.headers['authorization'];
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Missing or invalid token.' });
  }

  const token = header.slice(7);
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ message: 'Token expired or invalid.' });
  }
}

module.exports = { requireAuth };
