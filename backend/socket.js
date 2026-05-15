// ─────────────────────────────────────────────────────────────────────────────
//  Socket.io — live tracking pushes when driver POSTs /driver/location
// ─────────────────────────────────────────────────────────────────────────────

const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');
const { db } = require('./database');
const { getTrackingSnapshot } = require('./trackingSnapshot');

function attachSocket(httpServer, jwtSecret) {
  const io = new Server(httpServer, {
    cors: { origin: '*', methods: ['GET', 'POST'] },
  });

  io.on('connection', (socket) => {
    socket.on('subscribe_tracking', (payload) => {
      try {
        const requestId = payload?.request_id;
        const token = payload?.token;
        if (!requestId || !token) {
          socket.emit('tracking_error', { message: 'request_id and token are required.' });
          return;
        }
        const user = jwt.verify(token, jwtSecret);
        const request = db.prepare('SELECT * FROM requests WHERE id = ?').get(requestId);
        if (!request) {
          socket.emit('tracking_error', { message: 'Request not found.' });
          return;
        }
        if (user.role === 'patient' && request.user_id !== user.id) {
          socket.emit('tracking_error', { message: 'Forbidden.' });
          return;
        }
        if (user.role === 'driver' && request.assigned_driver_id !== user.id) {
          socket.emit('tracking_error', { message: 'Forbidden.' });
          return;
        }
        socket.join(`track:${requestId}`);
        const snap = getTrackingSnapshot(requestId);
        if (snap) socket.emit('tracking_update', snap);
      } catch {
        socket.emit('tracking_error', { message: 'Invalid or expired token.' });
      }
    });
  });

  return io;
}

module.exports = { attachSocket };
