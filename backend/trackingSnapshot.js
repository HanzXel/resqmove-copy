// ─────────────────────────────────────────────────────────────────────────────
//  Shared tracking payload for HTTP GET and Socket.io push.
// ─────────────────────────────────────────────────────────────────────────────

const { db } = require('./database');

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = deg2rad(lat2 - lat1);
  const dLon = deg2rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function deg2rad(deg) {
  return deg * (Math.PI / 180);
}

function getTrackingSnapshot(requestId) {
  const request = db.prepare('SELECT * FROM requests WHERE id = ?').get(requestId);
  if (!request) return null;

  let driverLocation = null;
  let etaMinutes = null;

  if (request.assigned_driver_id) {
    const driver = db.prepare('SELECT * FROM drivers WHERE id = ?').get(request.assigned_driver_id);
    if (driver && driver.current_lat != null) {
      driverLocation = {
        latitude: driver.current_lat,
        longitude: driver.current_lng,
        timestamp: driver.location_updated_at,
      };
      if (request.pickup_lat != null && request.pickup_lng != null) {
        const distKm = haversineKm(
          driver.current_lat,
          driver.current_lng,
          request.pickup_lat,
          request.pickup_lng,
        );
        etaMinutes = Math.max(1, Math.round((distKm / 40) * 60));
      }
    }
  }

  return {
    status: request.status,
    driver_location: driverLocation,
    eta_minutes: etaMinutes,
  };
}

module.exports = { getTrackingSnapshot, haversineKm };
