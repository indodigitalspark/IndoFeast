import cors from 'cors';
import express from 'express';

import { isDemoModeEnabled } from './config/db.js';
import { env } from './config/env.js';
import { uploadDirectory } from './config/uploads.js';
import { adminRoutes } from './routes/admin-routes.js';
import { authRoutes } from './routes/auth-routes.js';
import { customerRoutes } from './routes/customer-routes.js';
import { deliveryRoutes } from './routes/delivery-routes.js';
import { vendorRoutes } from './routes/vendor-routes.js';

export function createApp() {
  const app = express();
  const allowedOrigins = env.clientOrigin
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  const allowAnyOrigin =
    allowedOrigins.length === 0 || allowedOrigins.includes('*');
  const corsOptions = {
    origin: (origin, callback) => {
      if (!origin) {
        return callback(null, true);
      }

      if (
        allowAnyOrigin ||
        allowedOrigins.includes(origin) ||
        isLocalFlutterOrigin(origin)
      ) {
        return callback(null, true);
      }

      return callback(new Error(`CORS blocked for origin ${origin}.`));
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  };

  app.use(cors(corsOptions));
  app.options(/.*/, cors(corsOptions));
  app.use(express.json());
  app.use('/backend/uploads', express.static(uploadDirectory));

  app.get('/', (req, res) => {
    res.json({
      service: 'indofeast-backend',
      message: 'Backend is running.',
      health: '/api/health',
    });
  });

  app.get('/api/health', (req, res) => {
    res.json({
      status: 'ok',
      service: 'indofeast-backend',
      mode: isDemoModeEnabled() ? 'demo' : 'database',
    });
  });

  app.use('/api/auth', authRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api/customer', customerRoutes);
  app.use('/api/delivery', deliveryRoutes);
  app.use('/api/vendor', vendorRoutes);

  app.use((req, res) => {
    res.status(404).json({ message: 'Route not found.' });
  });

  return app;
}

function isLocalFlutterOrigin(origin) {
  return /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin);
}
