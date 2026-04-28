import bcrypt from 'bcryptjs';

import { env } from '../config/env.js';
import { UserModel } from '../models/user-model.js';

export async function ensureDefaultAdmin() {
  const existing = await UserModel.findOne({ email: env.defaultAdminEmail.toLowerCase() });
  if (existing) {
    let changed = false;

    if (existing.role !== 'SUPER_ADMIN') {
      existing.role = 'SUPER_ADMIN';
      changed = true;
    }

    if (existing.status !== 'APPROVED') {
      existing.status = 'APPROVED';
      changed = true;
    }

    if (changed) {
      await existing.save();
    }
    return;
  }

  const passwordHash = await bcrypt.hash(env.defaultAdminPassword, 12);

  await UserModel.create({
    displayName: env.defaultAdminName,
    email: env.defaultAdminEmail.toLowerCase(),
    phoneNumber: '+910000000000',
    passwordHash,
    role: 'SUPER_ADMIN',
    status: 'APPROVED',
  });
}
