import { isDemoModeEnabled } from '../config/db.js';
import { UserModel } from '../models/user-model.js';
import { getDemoAdminUser } from '../services/demo-auth-service.js';
import { verifyAuthToken } from '../services/jwt-service.js';

export async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const queryToken = typeof req.query.access_token === 'string' ? req.query.access_token : '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : queryToken;

  if (!token) {
    return res.status(401).json({ message: 'Missing auth token.' });
  }

  try {
    const payload = verifyAuthToken(token);
    if (isDemoModeEnabled() && payload.sub === 'demo-super-admin') {
      req.user = getDemoAdminUser();
      return next();
    }

    const user = await UserModel.findById(payload.sub);
    if (!user) {
      return res.status(401).json({ message: 'Invalid auth token.' });
    }
    if (user.status === 'SUSPENDED') {
      return res.status(403).json({ message: 'Your account has been suspended.' });
    }

    req.user = user;
    return next();
  } catch (error) {
    return res.status(401).json({ message: 'Authentication failed.' });
  }
}

export function requireRoles(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ message: 'You are not allowed to perform this action.' });
    }

    return next();
  };
}

export function userHasPermission(user, permission) {
  if (!user) {
    return false;
  }

  if (['SUPER_ADMIN', 'ADMIN'].includes(user.role)) {
    return true;
  }

  return Array.isArray(user.permissions) && user.permissions.includes(permission);
}

export function requirePermissions(...permissions) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ message: 'Authentication required.' });
    }

    const allowed = permissions.every((permission) => userHasPermission(req.user, permission));
    if (!allowed) {
      return res.status(403).json({ message: 'You do not have permission for this action.' });
    }

    return next();
  };
}
