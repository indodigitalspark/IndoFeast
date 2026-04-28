import mongoose from 'mongoose';

import { USER_ROLES } from '../constants/auth-constants.js';

const otpSessionSchema = new mongoose.Schema(
  {
    phoneNumber: { type: String, required: true, trim: true },
    role: { type: String, enum: USER_ROLES, required: true },
    code: { type: String, required: true },
    expiresAt: { type: Date, required: true, expires: 0 },
  },
  { timestamps: true },
);

export const OtpSessionModel = mongoose.model('OtpSession', otpSessionSchema);
