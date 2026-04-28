import jwt from 'jsonwebtoken';

import { env } from '../config/env.js';

export function signAuthToken(user) {
  return jwt.sign(
    {
      sub: user._id.toString(),
      role: user.role,
      status: user.status,
      email: user.email,
    },
    env.jwtSecret,
    { expiresIn: '7d' },
  );
}

export function verifyAuthToken(token) {
  return jwt.verify(token, env.jwtSecret);
}
