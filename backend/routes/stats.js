// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Stats Route
//  routes/stats.js
//
//  GET /api/v1/stats  (public, no auth needed)
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { db } = require('../database');

const router = express.Router();

router.get('/', (req, res) => {
  const availableUnits = db.prepare(
    `SELECT COUNT(*) as count FROM drivers WHERE status = 'available'`
  ).get().count;

  const livesSaved = db.prepare(
    `SELECT COUNT(*) as count FROM requests WHERE status = 'completed'`
  ).get().count;

  // Average response time: avg minutes between requested_at and accepted_at
  const avgRow = db.prepare(`
    SELECT AVG(
      (julianday(accepted_at) - julianday(requested_at)) * 24 * 60
    ) as avg_min
    FROM requests
    WHERE accepted_at IS NOT NULL AND requested_at IS NOT NULL
  `).get();

  const avgMin = avgRow.avg_min ? Math.round(avgRow.avg_min) : null;
  const avgResponseTime = avgMin != null ? `${avgMin} min` : '--';

  return res.json({
    avg_response_time: avgResponseTime,
    available_units: availableUnits,
    lives_saved: livesSaved,
  });
});

module.exports = router;
