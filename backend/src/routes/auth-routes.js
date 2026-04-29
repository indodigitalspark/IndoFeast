import bcrypt from 'bcryptjs';
import express from 'express';

import { isDemoModeEnabled } from '../config/db.js';
import { upload } from '../config/uploads.js';
import { ADMIN_FAMILY, USER_ROLES } from '../constants/auth-constants.js';
import { requireAuth } from '../middleware/auth-middleware.js';
import { AdminNotificationModel } from '../models/admin-notification-model.js';
import { OtpSessionModel } from '../models/otp-session-model.js';
import { UserModel } from '../models/user-model.js';
import {
  getDemoAdminUser,
  isDemoAdminCredentials,
} from '../services/demo-auth-service.js';
import { getOrCreateAdminConfig } from '../services/admin-config-service.js';
import { signAuthToken } from '../services/jwt-service.js';
import { sendRegistrationOtp } from '../services/otp-provider-service.js';
import { serializeUser } from '../utils/serializers.js';

const router = express.Router();
const REGISTRATION_ROLES = ['CUSTOMER', 'VENDOR', 'DELIVERY_PARTNER'];

router.post('/register', upload.single('document'), async (req, res) => {
  if (isDemoModeEnabled()) {
    return res.status(503).json({
      message:
        'Registration is unavailable in demo mode. Use the default SUPER_ADMIN credentials to log in.',
    });
  }

  try {
    const {
      displayName,
      email,
      phoneNumber,
      password,
      role,
      otp,
      businessName,
      vehicleLabel,
    } = req.body;
    const normalizedRole = String(role || '').toUpperCase();

    if (!displayName || !email || !phoneNumber || !password || !normalizedRole || !otp) {
      return res.status(400).json({ message: 'Missing registration fields.' });
    }

    if (!REGISTRATION_ROLES.includes(normalizedRole)) {
      return res.status(400).json({ message: 'Invalid role.' });
    }

    if (normalizedRole === 'VENDOR' && !String(businessName || '').trim()) {
      return res.status(400).json({ message: 'Store name is required for vendor registration.' });
    }

    if (normalizedRole === 'DELIVERY_PARTNER' && !String(vehicleLabel || '').trim()) {
      return res.status(400).json({ message: 'Vehicle type is required for delivery partner registration.' });
    }

    if (normalizedRole !== 'CUSTOMER' && !req.file) {
      return res.status(400).json({ message: 'Document upload is required.' });
    }

    const existing = await UserModel.findOne({ email: email.toLowerCase() });
    if (existing) {
      return res.status(409).json({ message: 'An account with this email already exists.' });
    }

    const otpSession = await OtpSessionModel.findOne({
      phoneNumber,
      role: normalizedRole,
      code: String(otp),
    });
    if (!otpSession || otpSession.expiresAt.getTime() < Date.now()) {
      return res.status(401).json({ message: 'Invalid or expired OTP.' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const user = await UserModel.create({
      displayName,
      email: email.toLowerCase(),
      phoneNumber,
      businessName: normalizedRole === 'VENDOR' ? String(businessName || '').trim() : undefined,
      passwordHash,
      role: normalizedRole,
      status: normalizedRole === 'CUSTOMER' ? 'APPROVED' : 'PENDING',
      document: req.file
        ? {
            originalName: req.file.originalname,
            mimeType: req.file.mimetype,
            size: req.file.size,
            path: req.file.path,
          }
        : undefined,
      deliveryProfile:
        normalizedRole === 'DELIVERY_PARTNER'
          ? { vehicleLabel: String(vehicleLabel || '').trim() || 'Bike' }
          : undefined,
    });

    await OtpSessionModel.deleteMany({ phoneNumber, role: normalizedRole });

    if (normalizedRole !== 'CUSTOMER') {
      await AdminNotificationModel.create({
        title: 'New user registration',
        body: `${displayName} registered as ${normalizedRole} and is waiting for approval.`,
        targetRoles: ADMIN_FAMILY,
        relatedUserId: user._id,
      });

      return res.status(201).json({
        message: 'Registration submitted. Your account is pending approval.',
        user: serializeUser(user),
      });
    }

    return res.status(201).json({
      message: 'Registration successful. Your customer account is ready to use.',
      token: signAuthToken(user),
      user: serializeUser(user),
    });
  } catch (error) {
    return res.status(500).json({ message: 'Registration failed.' });
  }
});

router.post('/login', async (req, res) => {
  if (isDemoModeEnabled()) {
    if (!isDemoAdminCredentials(req.body)) {
      return res.status(401).json({
        message:
          'Demo mode only supports the default SUPER_ADMIN account. Use aman@indofeast.com / Amazing12@.',
      });
    }

    const user = getDemoAdminUser();
    return res.json({
      token: signAuthToken(user),
      user: serializeUser(user),
      mode: 'demo',
    });
  }

  try {
    const { email, password, role } = req.body;

    const user = await UserModel.findOne({ email: String(email).toLowerCase() });
    if (!user) {
      return res.status(401).json({ message: 'Invalid email or password.' });
    }

    const isValid = await bcrypt.compare(String(password), user.passwordHash);
    if (!isValid) {
      return res.status(401).json({ message: 'Invalid email or password.' });
    }

    if (role && user.role !== String(role).toUpperCase()) {
      return res
        .status(403)
        .json({ message: `This account is registered as ${user.role}, not ${role}.` });
    }

    if (user.status !== 'APPROVED') {
      return res.status(403).json({
        message:
          user.status === 'REJECTED'
            ? user.rejectionReason || 'Your account was rejected.'
            : user.status === 'SUSPENDED'
            ? 'Your account has been suspended.'
            : 'Your account is pending approval.',
        user: serializeUser(user),
      });
    }

    return res.json({
      token: signAuthToken(user),
      user: serializeUser(user),
    });
  } catch (error) {
    return res.status(500).json({ message: 'Login failed.' });
  }
});

router.post('/phone/send-otp', async (req, res) => {
  if (isDemoModeEnabled()) {
    return res.status(503).json({
      message: 'Phone OTP is unavailable in demo mode. Use email login instead.',
    });
  }

  try {
    const { phoneNumber, role } = req.body;
    if (!phoneNumber || !role) {
      return res.status(400).json({ message: 'Phone number and role are required.' });
    }

    const code = String(Math.floor(100000 + Math.random() * 900000));
    const expiryMinutes = 5;
    const expiresAt = new Date(Date.now() + expiryMinutes * 60 * 1000);

    await OtpSessionModel.deleteMany({ phoneNumber, role });
    await OtpSessionModel.create({ phoneNumber, role, code, expiresAt });

    const delivery = await sendRegistrationOtp({
      phoneNumber,
      role,
      code,
      expiryMinutes,
    });

    return res.json({
      message: delivery.message,
      otpPreview: delivery.otpPreview || null,
      providerName: delivery.providerName,
      mode: delivery.mode,
    });
  } catch (error) {
    return res.status(500).json({
      message: error instanceof Error ? error.message : 'Could not send OTP.',
    });
  }
});

router.post('/phone/verify-otp', async (req, res) => {
  if (isDemoModeEnabled()) {
    return res.status(503).json({
      message: 'Phone OTP is unavailable in demo mode. Use email login instead.',
    });
  }

  try {
    const { phoneNumber, role, otp } = req.body;

    const otpSession = await OtpSessionModel.findOne({ phoneNumber, role, code: otp });
    if (!otpSession || otpSession.expiresAt.getTime() < Date.now()) {
      return res.status(401).json({ message: 'Invalid or expired OTP.' });
    }

    const user = await UserModel.findOne({ phoneNumber, role });
    await OtpSessionModel.deleteMany({ phoneNumber, role });

    if (!user) {
      return res.status(404).json({ message: 'No registered account found for this phone number.' });
    }

    if (user.status !== 'APPROVED') {
      return res.status(403).json({
        message:
          user.status === 'REJECTED'
            ? user.rejectionReason || 'Your account was rejected.'
            : user.status === 'SUSPENDED'
            ? 'Your account has been suspended.'
            : 'Your account is pending approval.',
        user: serializeUser(user),
      });
    }

    return res.json({
      token: signAuthToken(user),
      user: serializeUser(user),
    });
  } catch (error) {
    return res.status(500).json({ message: 'OTP verification failed.' });
  }
});

router.get('/me', requireAuth, async (req, res) => {
  return res.json({ user: serializeUser(req.user) });
});

router.get('/public-site', async (req, res) => {
  try {
    const config = await getOrCreateAdminConfig();
    return res.json({
      websiteSettings: {
        headline: config.websiteSettings?.headline || 'IndoFeast Digital Entry',
        subtitle: config.websiteSettings?.subtitle || '',
        qrLinks: (config.websiteSettings?.qrLinks || []).filter(
          (item) => item.isActive !== false,
        ),
      },
    });
  } catch (error) {
    return res
        .status(500)
        .json({ message: 'Could not load public website settings.' });
  }
});

export { router as authRoutes };
