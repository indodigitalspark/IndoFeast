import crypto from 'node:crypto';

import bcrypt from 'bcryptjs';
import express from 'express';

import { isDemoModeEnabled } from '../config/db.js';
import { env } from '../config/env.js';
import { ACCOUNT_STATUSES, ADMIN_FAMILY, USER_ROLES } from '../constants/auth-constants.js';
import {
  requireAuth,
  requirePermissions,
  requireRoles,
  userHasPermission,
} from '../middleware/auth-middleware.js';
import { AdminNotificationModel } from '../models/admin-notification-model.js';
import { OrderModel } from '../models/order-model.js';
import { RestaurantModel } from '../models/restaurant-model.js';
import { UserModel } from '../models/user-model.js';
import { getOrCreateAdminConfig } from '../services/admin-config-service.js';
import { cancelOrder } from '../services/order-lifecycle-service.js';
import { refundProviderPayment } from '../services/payment-provider-service.js';
import {
  serializeNotification,
  serializeRestaurant,
  serializeUser,
} from '../utils/serializers.js';

const router = express.Router();

router.use(requireAuth, requireRoles(...ADMIN_FAMILY));

router.get('/dashboard', requirePermissions('dashboard:view'), async (req, res) => {
  if (isDemoModeEnabled()) {
    return res.json(buildDemoAdminDashboard());
  }

  const config = await getOrCreateAdminConfig();

  const [users, restaurants, orders, notifications] = await Promise.all([
    UserModel.find({}).sort({ createdAt: -1 }),
    RestaurantModel.find({}).sort({ createdAt: -1 }),
    OrderModel.find({}).sort({ createdAt: -1 }),
    AdminNotificationModel.find({}).sort({ createdAt: -1 }).limit(20),
  ]);

  const analytics = buildAnalytics({ users, restaurants, orders });
  const transactions = buildTransactions(users);
  const canViewUsers =
    userHasPermission(req.user, 'users:manage') ||
    userHasPermission(req.user, 'approvals:manage');
  const canViewTransactions = userHasPermission(req.user, 'transactions:view');
  const canViewCommission = userHasPermission(req.user, 'commission:manage');
  const canViewRoles = userHasPermission(req.user, 'roles:manage');
  const canViewCategories = userHasPermission(req.user, 'categories:manage');
  const canViewBanners = userHasPermission(req.user, 'banners:manage');
  const canManageOtpSettings = req.user.role === 'SUPER_ADMIN';

  return res.json({
    analytics,
    users: canViewUsers ? users.map(serializeUser) : [],
    restaurants: canViewUsers
      ? restaurants.map((restaurant) => ({
          ...serializeRestaurant(restaurant),
          ownerName:
            users.find(
              (user) =>
                user._id.toString() === restaurant.ownerId?.toString(),
            )?.displayName || null,
          ownerEmail:
            users.find(
              (user) =>
                user._id.toString() === restaurant.ownerId?.toString(),
            )?.email || null,
        }))
      : [],
    transactions: canViewTransactions ? transactions : [],
    notifications: notifications.map(serializeNotification),
    config: serializeAdminConfig(
      {
        ...config.toObject(),
        globalCommissionRate: canViewCommission ? config.globalCommissionRate : 0.18,
        roleDefinitions: canViewRoles ? config.roleDefinitions : [],
        managedCategories: canViewCategories ? config.managedCategories : [],
        marketingBanners: canViewBanners ? config.marketingBanners : [],
      },
      {
        includeOtpSettings: canManageOtpSettings,
        includeSensitiveOtpFields: canManageOtpSettings,
      },
    ),
    report: buildReportSnapshot({ orders, restaurants, transactions, analytics }),
  });
});

router.get('/users', requirePermissions('users:manage'), async (req, res) => {
  if (isDemoModeEnabled()) {
    return res.json({ users: buildDemoAdminDashboard().users });
  }

  const filter = {};
  if (req.query.status) {
    filter.status = req.query.status;
  }

  const users = await UserModel.find(filter).sort({ createdAt: -1 });
  return res.json({ users: users.map(serializeUser) });
});

router.post('/users', requirePermissions('users:manage'), async (req, res) => {
  if (isDemoModeEnabled()) {
    return res.status(503).json({ message: 'User creation is unavailable in demo mode.' });
  }

  try {
    const displayName = String(req.body.displayName || '').trim();
    const email = String(req.body.email || '').trim().toLowerCase();
    const phoneNumber = String(req.body.phoneNumber || '').trim();
    const password = String(req.body.password || '');
    const role = String(req.body.role || '').trim().toUpperCase();
    const requestedStatus = String(req.body.status || 'APPROVED').trim().toUpperCase();
    const customRoleKey = String(req.body.customRoleKey || '').trim() || null;

    if (!displayName || !email || !phoneNumber || !password || !role) {
      return res.status(400).json({
        message: 'Display name, email, phone number, password, and role are required.',
      });
    }

    if (!USER_ROLES.includes(role)) {
      return res.status(400).json({ message: 'Invalid role.' });
    }

    if (!ACCOUNT_STATUSES.includes(requestedStatus)) {
      return res.status(400).json({ message: 'Invalid account status.' });
    }

    if (role === 'SUPER_ADMIN' && req.user.role !== 'SUPER_ADMIN') {
      return res.status(403).json({ message: 'Only a SUPER_ADMIN can create another SUPER_ADMIN.' });
    }

    const existing = await UserModel.findOne({ email });
    if (existing) {
      return res.status(409).json({ message: 'An account with this email already exists.' });
    }

    const config = await getOrCreateAdminConfig();
    const customRole = customRoleKey
      ? config.roleDefinitions.find((item) => item.key === customRoleKey)
      : null;

    const passwordHash = await bcrypt.hash(password, 12);
    const user = await UserModel.create({
      displayName,
      email,
      phoneNumber,
      passwordHash,
      role,
      status: requestedStatus,
      customRoleKey: customRole?.key || null,
      customRoleName: customRole?.name || null,
      permissions: customRole?.permissions || [],
      deliveryProfile:
        role === 'DELIVERY_PARTNER'
          ? {
              isOnline: false,
              currentZone: 'Central Zone',
              vehicleLabel: 'Bike',
            }
          : undefined,
    });

    await AdminNotificationModel.create({
      title: 'Credentials created by admin',
      body: `${req.user.displayName} created a ${role} account for ${displayName}.`,
      targetRoles: ADMIN_FAMILY,
      relatedUserId: user._id,
    });

    return res.status(201).json({
      message: 'User credentials created successfully.',
      user: serializeUser(user),
    });
  } catch (error) {
    return res.status(500).json({ message: 'Could not create user credentials.' });
  }
});

router.patch('/users/:id/status', requirePermissions('approvals:manage'), async (req, res) => {
  if (isDemoModeEnabled()) {
    const demoUser = findDemoUser(req.params.id);
    if (!demoUser) {
      return res.status(404).json({ message: 'User not found.' });
    }

    demoUser.status = String(req.body.status || demoUser.status).trim().toUpperCase();
    demoUser.rejectionReason =
      demoUser.status === 'REJECTED'
        ? req.body.rejectionReason || 'Rejected by admin review.'
        : null;

    return res.json({
      message: `Account marked as ${demoUser.status}.`,
      user: demoUser,
    });
  }

  const { status, rejectionReason } = req.body;

  const user = await UserModel.findByIdAndUpdate(
    req.params.id,
    {
      status,
      rejectionReason:
        status === 'REJECTED' ? rejectionReason || 'Rejected by admin review.' : null,
    },
    { new: true },
  );

  if (!user) {
    return res.status(404).json({ message: 'User not found.' });
  }

  return res.json({
    message: `Account marked as ${status}.`,
    user: serializeUser(user),
  });
});

router.patch('/users/:id/profile', requirePermissions('users:manage'), async (req, res) => {
  const {
    displayName,
    email,
    phoneNumber,
    role,
    customRoleKey,
    status,
  } = req.body;
  if (isDemoModeEnabled()) {
    const demoUser = findDemoUser(req.params.id);
    if (!demoUser) {
      return res.status(404).json({ message: 'User not found.' });
    }

    if (demoUser.role && ADMIN_FAMILY.includes(demoUser.role) && req.user.role !== 'SUPER_ADMIN') {
      return res.status(403).json({ message: 'Only a SUPER_ADMIN can update admin-family accounts.' });
    }

    if (
      demoUser.email?.toLowerCase() === env.defaultAdminEmail.toLowerCase() &&
      req.user.role === 'SUPER_ADMIN' &&
      role &&
      String(role).trim().toUpperCase() !== 'SUPER_ADMIN'
    ) {
      return res.status(403).json({ message: 'The default SUPER_ADMIN account cannot be downgraded.' });
    }

    if (displayName != null) {
      demoUser.displayName = String(displayName).trim();
    }
    if (email != null) {
      const normalizedEmail = String(email).trim().toLowerCase();
      const existing = demoAdminState.users.find(
        (item) => item.email === normalizedEmail && item.id !== demoUser.id,
      );
      if (existing) {
        return res.status(409).json({ message: 'Another account already uses this email.' });
      }
      demoUser.email = normalizedEmail;
    }
    if (phoneNumber != null) {
      demoUser.phoneNumber = String(phoneNumber).trim();
    }
    if (role != null) {
      const normalizedRole = String(role).trim().toUpperCase();
      if (!USER_ROLES.includes(normalizedRole)) {
        return res.status(400).json({ message: 'Invalid role.' });
      }
      demoUser.role = normalizedRole;
    }
    if (status != null) {
      const normalizedStatus = String(status).trim().toUpperCase();
      if (!ACCOUNT_STATUSES.includes(normalizedStatus)) {
        return res.status(400).json({ message: 'Invalid account status.' });
      }
      demoUser.status = normalizedStatus;
    }

    const customRole = demoAdminState.config.roleDefinitions.find(
      (item) => item.key === customRoleKey,
    );
    demoUser.customRoleKey = customRole?.key || null;
    demoUser.customRoleName = customRole?.name || null;
    demoUser.permissions = customRole?.permissions || [];

    return res.json({
      message: 'User profile updated.',
      user: demoUser,
    });
  }

  const user = await UserModel.findById(req.params.id);
  if (!user) {
    return res.status(404).json({ message: 'User not found.' });
  }

  if (user.role && ADMIN_FAMILY.includes(user.role) && req.user.role !== 'SUPER_ADMIN') {
    return res.status(403).json({ message: 'Only a SUPER_ADMIN can update admin-family accounts.' });
  }

  if (
    user.email?.toLowerCase() === env.defaultAdminEmail.toLowerCase() &&
    req.user.role === 'SUPER_ADMIN' &&
    role &&
    String(role).trim().toUpperCase() !== 'SUPER_ADMIN'
  ) {
    return res.status(403).json({ message: 'The default SUPER_ADMIN account cannot be downgraded.' });
  }

  const config = await getOrCreateAdminConfig();
  const customRole = config.roleDefinitions.find((item) => item.key === customRoleKey);

  if (displayName != null) {
    const normalizedDisplayName = String(displayName).trim();
    if (!normalizedDisplayName) {
      return res.status(400).json({ message: 'Display name is required.' });
    }
    user.displayName = normalizedDisplayName;
  }

  if (email != null) {
    const normalizedEmail = String(email).trim().toLowerCase();
    if (!normalizedEmail) {
      return res.status(400).json({ message: 'Email is required.' });
    }

    const existing = await UserModel.findOne({
      email: normalizedEmail,
      _id: { $ne: user._id },
    });
    if (existing) {
      return res.status(409).json({ message: 'Another account already uses this email.' });
    }

    user.email = normalizedEmail;
  }

  if (phoneNumber != null) {
    const normalizedPhoneNumber = String(phoneNumber).trim();
    if (!normalizedPhoneNumber) {
      return res.status(400).json({ message: 'Phone number is required.' });
    }
    user.phoneNumber = normalizedPhoneNumber;
  }

  if (role) {
    const normalizedRole = String(role).trim().toUpperCase();
    if (!USER_ROLES.includes(normalizedRole)) {
      return res.status(400).json({ message: 'Invalid role.' });
    }
    if (normalizedRole === 'SUPER_ADMIN' && req.user.role !== 'SUPER_ADMIN') {
      return res.status(403).json({ message: 'Only a SUPER_ADMIN can assign the SUPER_ADMIN role.' });
    }
    user.role = normalizedRole;
  }

  if (status) {
    const normalizedStatus = String(status).trim().toUpperCase();
    if (!ACCOUNT_STATUSES.includes(normalizedStatus)) {
      return res.status(400).json({ message: 'Invalid account status.' });
    }
    user.status = normalizedStatus;
  }

  user.customRoleKey = customRole?.key || null;
  user.customRoleName = customRole?.name || null;
  user.permissions = customRole?.permissions || [];
  await user.save();

  return res.json({
    message: 'User profile updated.',
    user: serializeUser(user),
  });
});

router.patch('/users/:id/password', requirePermissions('users:manage'), async (req, res) => {
  const nextPassword = String(req.body.password || '');
  if (!nextPassword || nextPassword.length < 8) {
    return res.status(400).json({ message: 'Password must be at least 8 characters long.' });
  }

  if (isDemoModeEnabled()) {
    const demoUser = findDemoUser(req.params.id);
    if (!demoUser) {
      return res.status(404).json({ message: 'User not found.' });
    }

    if (ADMIN_FAMILY.includes(demoUser.role) && req.user.role !== 'SUPER_ADMIN') {
      return res.status(403).json({ message: 'Only a SUPER_ADMIN can reset admin-family passwords.' });
    }

    return res.json({
      message: `Password reset simulated for ${demoUser.displayName}.`,
      user: demoUser,
    });
  }

  const user = await UserModel.findById(req.params.id);
  if (!user) {
    return res.status(404).json({ message: 'User not found.' });
  }

  if (ADMIN_FAMILY.includes(user.role) && req.user.role !== 'SUPER_ADMIN') {
    return res.status(403).json({ message: 'Only a SUPER_ADMIN can reset admin-family passwords.' });
  }

  user.passwordHash = await bcrypt.hash(nextPassword, 12);
  await user.save();

  await AdminNotificationModel.create({
    title: 'Password reset by admin',
    body: `${req.user.displayName} reset credentials for ${user.displayName}.`,
    targetRoles: ADMIN_FAMILY,
    relatedUserId: user._id,
  });

  return res.json({
    message: 'Password reset successfully.',
    user: serializeUser(user),
  });
});

router.delete('/users/:id', requirePermissions('users:manage'), async (req, res) => {
  if (isDemoModeEnabled()) {
    const demoUser = findDemoUser(req.params.id);
    if (!demoUser) {
      return res.status(404).json({ message: 'User not found.' });
    }

    if (String(demoUser.id) === String(req.user._id)) {
      return res.status(403).json({ message: 'You cannot delete your own signed-in account.' });
    }

    if (demoUser.email?.toLowerCase() === env.defaultAdminEmail.toLowerCase()) {
      return res.status(403).json({ message: 'The default SUPER_ADMIN account cannot be deleted.' });
    }

    if (ADMIN_FAMILY.includes(demoUser.role) && req.user.role !== 'SUPER_ADMIN') {
      return res.status(403).json({ message: 'Only a SUPER_ADMIN can delete admin-family accounts.' });
    }

    demoAdminState.users = demoAdminState.users.filter((item) => item.id !== demoUser.id);
    demoAdminState.notifications.unshift({
      id: `demo-notification-${Date.now()}`,
      title: 'User deleted by admin',
      body: `${req.user.displayName} deleted ${demoUser.displayName} (${demoUser.role}).`,
      createdAt: new Date().toISOString(),
      targetRoles: ADMIN_FAMILY,
      isRead: false,
      relatedUserId: null,
    });

    return res.json({
      message: 'User deleted successfully.',
      userId: demoUser.id,
    });
  }

  const user = await UserModel.findById(req.params.id);
  if (!user) {
    return res.status(404).json({ message: 'User not found.' });
  }

  if (String(user._id) === String(req.user._id)) {
    return res.status(403).json({ message: 'You cannot delete your own signed-in account.' });
  }

  if (user.email?.toLowerCase() === env.defaultAdminEmail.toLowerCase()) {
    return res.status(403).json({ message: 'The default SUPER_ADMIN account cannot be deleted.' });
  }

  if (ADMIN_FAMILY.includes(user.role) && req.user.role !== 'SUPER_ADMIN') {
    return res.status(403).json({ message: 'Only a SUPER_ADMIN can delete admin-family accounts.' });
  }

  if (user.role === 'VENDOR') {
    await RestaurantModel.updateMany({ ownerId: user._id }, { $set: { ownerId: null } });
  }

  if (user.role === 'DELIVERY_PARTNER') {
    await OrderModel.updateMany(
      { deliveryPartnerId: user._id, status: { $ne: 'DELIVERED' } },
      {
        $set: {
          deliveryPartnerId: null,
          deliveryPartnerName: null,
          assignedAt: null,
          deliveryAcceptedAt: null,
        },
      },
    );
  }

  await UserModel.deleteOne({ _id: user._id });

  await AdminNotificationModel.create({
    title: 'User deleted by admin',
    body: `${req.user.displayName} deleted ${user.displayName} (${user.role}).`,
    targetRoles: ADMIN_FAMILY,
  });

  return res.json({
    message: 'User deleted successfully.',
    userId: String(user._id),
  });
});

router.patch('/commission', requirePermissions('commission:manage'), async (req, res) => {
  const commissionRate = Number(req.body.commissionRate);
  if (Number.isNaN(commissionRate) || commissionRate <= 0 || commissionRate >= 1) {
    return res.status(400).json({ message: 'Commission rate must be between 0 and 1.' });
  }

  const config = await getOrCreateAdminConfig();
  config.globalCommissionRate = commissionRate;
  await config.save();
  await RestaurantModel.updateMany({}, { commissionRate });

  return res.json({
    message: 'Commission rate updated.',
    config: serializeAdminConfig(config),
  });
});

router.post('/vendors/stores', requirePermissions('users:manage'), async (req, res) => {
  const {
    ownerId,
    name,
    category,
    cuisine,
    description,
    offerText,
    deliveryTime,
    priceLevel,
    commissionRate,
  } = req.body;

  if (!name || !ownerId) {
    return res.status(400).json({ message: 'Vendor owner and store name are required.' });
  }

  if (isDemoModeEnabled()) {
    return res.status(503).json({ message: 'Vendor store creation is unavailable in demo mode.' });
  }

  const owner = await UserModel.findById(ownerId);
  if (!owner || owner.role !== 'VENDOR') {
    return res.status(404).json({ message: 'Vendor account not found.' });
  }

  const restaurant = await RestaurantModel.create({
    ownerId: owner._id,
    name: String(name).trim(),
    cuisine: sanitizeStringArray(cuisine),
    category: String(category || 'Meals').trim(),
    rating: 0,
    deliveryTime: Number(deliveryTime ?? 25),
    priceLevel: String(priceLevel || 'Rs 300 for two').trim(),
    offerText: String(offerText || '').trim(),
    description: String(description || '').trim(),
    accentColor: '#F9E7D2',
    heroTag: 'NEW',
    commissionRate: Number(commissionRate ?? 0.18),
    menuItems: [],
  });

  return res.status(201).json({
    message: 'Vendor store created successfully.',
    restaurant: serializeRestaurant(restaurant),
  });
});

router.patch('/vendors/stores/:id', requirePermissions('users:manage'), async (req, res) => {
  if (isDemoModeEnabled()) {
    return res.status(503).json({ message: 'Vendor store editing is unavailable in demo mode.' });
  }

  const restaurant = await RestaurantModel.findById(req.params.id);
  if (!restaurant) {
    return res.status(404).json({ message: 'Vendor store not found.' });
  }

  const {
    ownerId,
    name,
    category,
    cuisine,
    description,
    offerText,
    deliveryTime,
    priceLevel,
    commissionRate,
  } = req.body;

  if (ownerId != null) {
    const owner = await UserModel.findById(ownerId);
    if (!owner || owner.role !== 'VENDOR') {
      return res.status(404).json({ message: 'Vendor account not found.' });
    }
    restaurant.ownerId = owner._id;
  }

  if (name != null) {
    restaurant.name = String(name).trim();
  }
  if (category != null) {
    restaurant.category = String(category).trim();
  }
  if (cuisine != null) {
    restaurant.cuisine = sanitizeStringArray(cuisine);
  }
  if (description != null) {
    restaurant.description = String(description).trim();
  }
  if (offerText != null) {
    restaurant.offerText = String(offerText).trim();
  }
  if (deliveryTime != null) {
    restaurant.deliveryTime = Number(deliveryTime);
  }
  if (priceLevel != null) {
    restaurant.priceLevel = String(priceLevel).trim();
  }
  if (commissionRate != null) {
    restaurant.commissionRate = Number(commissionRate);
  }

  await restaurant.save();

  return res.json({
    message: 'Vendor store updated successfully.',
    restaurant: serializeRestaurant(restaurant),
  });
});

router.post('/roles', requirePermissions('roles:manage'), async (req, res) => {
  const { name, permissions } = req.body;
  if (!name) {
    return res.status(400).json({ message: 'Role name is required.' });
  }

  const config = await getOrCreateAdminConfig();
  const key = slugify(name);

  if (config.roleDefinitions.some((item) => item.key === key)) {
    return res.status(409).json({ message: 'A role with this name already exists.' });
  }

  config.roleDefinitions.push({
    key,
    name: String(name).trim(),
    permissions: sanitizePermissions(permissions),
    isSystem: false,
  });
  await config.save();

  return res.status(201).json({
    message: 'Custom role created.',
    config: serializeAdminConfig(config),
  });
});

router.patch('/roles/:key', requirePermissions('roles:manage'), async (req, res) => {
  const config = await getOrCreateAdminConfig();
  const role = config.roleDefinitions.find((item) => item.key === req.params.key);
  if (!role) {
    return res.status(404).json({ message: 'Role not found.' });
  }

  role.name = req.body.name ? String(req.body.name).trim() : role.name;
  role.permissions = req.body.permissions
    ? sanitizePermissions(req.body.permissions)
    : role.permissions;
  await config.save();

  await syncUsersWithCustomRole(role.key, role.name, role.permissions);

  return res.json({
    message: 'Role updated.',
    config: serializeAdminConfig(config),
  });
});

router.post('/categories', requirePermissions('categories:manage'), async (req, res) => {
  const name = String(req.body.name || '').trim();
  if (!name) {
    return res.status(400).json({ message: 'Category name is required.' });
  }

  const config = await getOrCreateAdminConfig();
  config.managedCategories.push({
    id: crypto.randomUUID(),
    name,
    isActive: req.body.isActive !== false,
  });
  await config.save();

  return res.status(201).json({
    message: 'Category created.',
    config: serializeAdminConfig(config),
  });
});

router.patch('/categories/:id', requirePermissions('categories:manage'), async (req, res) => {
  const config = await getOrCreateAdminConfig();
  const category = config.managedCategories.find((item) => item.id === req.params.id);
  if (!category) {
    return res.status(404).json({ message: 'Category not found.' });
  }

  category.name = req.body.name ? String(req.body.name).trim() : category.name;
  if (req.body.isActive != null) {
    category.isActive = Boolean(req.body.isActive);
  }
  await config.save();

  return res.json({
    message: 'Category updated.',
    config: serializeAdminConfig(config),
  });
});

router.post('/banners', requirePermissions('banners:manage'), async (req, res) => {
  const { title, subtitle, ctaText } = req.body;
  if (!title || !subtitle) {
    return res.status(400).json({ message: 'Banner title and subtitle are required.' });
  }

  const config = await getOrCreateAdminConfig();
  config.marketingBanners.push({
    id: crypto.randomUUID(),
    title: String(title).trim(),
    subtitle: String(subtitle).trim(),
    ctaText: String(ctaText || 'Order now').trim(),
    isActive: req.body.isActive !== false,
  });
  await config.save();

  return res.status(201).json({
    message: 'Banner created.',
    config: serializeAdminConfig(config),
  });
});

router.patch('/banners/:id', requirePermissions('banners:manage'), async (req, res) => {
  const config = await getOrCreateAdminConfig();
  const banner = config.marketingBanners.find((item) => item.id === req.params.id);
  if (!banner) {
    return res.status(404).json({ message: 'Banner not found.' });
  }

  banner.title = req.body.title ? String(req.body.title).trim() : banner.title;
  banner.subtitle = req.body.subtitle
    ? String(req.body.subtitle).trim()
    : banner.subtitle;
  banner.ctaText = req.body.ctaText ? String(req.body.ctaText).trim() : banner.ctaText;
  if (req.body.isActive != null) {
    banner.isActive = Boolean(req.body.isActive);
  }
  await config.save();

  return res.json({
    message: 'Banner updated.',
    config: serializeAdminConfig(config),
  });
});

router.patch('/website-settings', async (req, res) => {
  if (req.user.role !== 'SUPER_ADMIN') {
    return res.status(403).json({
      message: 'Only a SUPER_ADMIN can manage website QR settings.',
    });
  }

  const config = await getOrCreateAdminConfig();
  const websiteSettings = req.body.websiteSettings || {};

  config.websiteSettings = {
    headline:
      String(websiteSettings.headline || '').trim() ||
      'IndoFeast Digital Entry',
    subtitle: String(websiteSettings.subtitle || '').trim(),
    qrLinks: Array.isArray(websiteSettings.qrLinks)
      ? websiteSettings.qrLinks
          .map((item) => ({
            id: String(item.id || '').trim(),
            title: String(item.title || '').trim(),
            description: String(item.description || '').trim(),
            url: String(item.url || '').trim(),
            isActive: Boolean(item.isActive),
          }))
          .filter((item) => item.id && item.title && item.url)
      : [],
  };

  await config.save();

  return res.json({
    message: 'Website settings updated.',
    config: serializeAdminConfig(config),
  });
});

router.patch('/otp-settings', async (req, res) => {
  if (req.user.role !== 'SUPER_ADMIN') {
    return res.status(403).json({
      message: 'Only a SUPER_ADMIN can manage OTP API settings.',
    });
  }

  const otpSettings = req.body.otpSettings || {};
  const normalizedStatusCodes = sanitizeStatusCodes(
    otpSettings.successStatusCodes,
  );
  const httpMethod =
    String(otpSettings.httpMethod || 'POST').trim().toUpperCase() || 'POST';
  if (!['GET', 'POST', 'PUT', 'PATCH'].includes(httpMethod)) {
    return res.status(400).json({
      message: 'HTTP method must be GET, POST, PUT, or PATCH.',
    });
  }

  try {
    ensureJsonString(
      String(otpSettings.requestHeaders || '').trim() ||
        '{"Content-Type":"application/json"}',
      'Request headers',
    );
    ensureJsonString(
      String(otpSettings.requestBodyTemplate || '').trim() ||
        '{"phone":"{{PHONE_NUMBER}}","message":"{{MESSAGE}}","senderId":"{{SENDER_ID}}"}',
      'Request body template',
    );
  } catch (error) {
    return res.status(400).json({
      message: error instanceof Error ? error.message : 'Invalid OTP API configuration.',
    });
  }

  if (otpSettings.enabled === true && !String(otpSettings.apiUrl || '').trim()) {
    return res.status(400).json({
      message: 'API URL is required when OTP API delivery is enabled.',
    });
  }

  const config = await getOrCreateAdminConfig();
  config.otpSettings = {
    enabled: otpSettings.enabled === true,
    providerName: String(otpSettings.providerName || '').trim() || 'Custom SMS API',
    apiUrl: String(otpSettings.apiUrl || '').trim(),
    httpMethod,
    authToken: String(otpSettings.authToken || '').trim(),
    senderId: String(otpSettings.senderId || '').trim() || 'INDOFEAST',
    messageTemplate:
      String(otpSettings.messageTemplate || '').trim() ||
      'Your IndoFeast OTP is {{OTP}}. It expires in {{EXPIRY_MINUTES}} minutes.',
    requestHeaders:
      String(otpSettings.requestHeaders || '').trim() ||
      '{"Content-Type":"application/json"}',
    requestBodyTemplate:
      String(otpSettings.requestBodyTemplate || '').trim() ||
      '{"phone":"{{PHONE_NUMBER}}","message":"{{MESSAGE}}","senderId":"{{SENDER_ID}}"}',
    successStatusCodes: normalizedStatusCodes,
  };

  await config.save();

  return res.json({
    message: 'OTP API settings updated.',
    config: serializeAdminConfig(config, {
      includeOtpSettings: true,
      includeSensitiveOtpFields: true,
    }),
  });
});

router.post(
  '/notifications/broadcast',
  requirePermissions('notifications:broadcast'),
  async (req, res) => {
  const title = String(req.body.title || '').trim();
  const body = String(req.body.body || '').trim();
  if (!title || !body) {
    return res.status(400).json({ message: 'Broadcast title and body are required.' });
  }

  const targetRoles = Array.isArray(req.body.targetRoles) && req.body.targetRoles.length > 0
    ? req.body.targetRoles.map((item) => String(item))
    : ['CUSTOMER', 'VENDOR', 'DELIVERY_PARTNER', ...ADMIN_FAMILY];

  const notification = await AdminNotificationModel.create({
    title,
    body,
    targetRoles,
  });

  return res.status(201).json({
    message: 'Broadcast notification created.',
    notification: serializeNotification(notification),
  });
  },
);

router.get('/transactions', requirePermissions('transactions:view'), async (req, res) => {
  const users = await UserModel.find({}).sort({ createdAt: -1 });
  return res.json({ transactions: buildTransactions(users) });
});

router.get('/reports', requirePermissions('reports:view'), async (req, res) => {
  const days = Math.max(Number(req.query.days || 30), 1);
  const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;

  const [users, restaurants, orders] = await Promise.all([
    UserModel.find({}),
    RestaurantModel.find({}),
    OrderModel.find({ createdAt: { $gte: new Date(cutoff) } }),
  ]);

  const transactions = buildTransactions(users).filter(
    (entry) => new Date(entry.createdAt).getTime() >= cutoff,
  );

  return res.json({
    report: buildReportSnapshot({
      orders,
      restaurants,
      transactions,
      analytics: buildAnalytics({ users, restaurants, orders }),
      days,
    }),
  });
});

router.post('/orders/:id/refund', requirePermissions('transactions:view'), async (req, res) => {
  const order = await OrderModel.findById(req.params.id);
  if (!order) {
    return res.status(404).json({ message: 'Order not found.' });
  }

  const refundAmount = Math.min(
    Number(req.body.amount || order.total),
    Math.max(order.total - (order.refundedAmount || 0), 0),
  );
  if (refundAmount <= 0) {
    return res.status(400).json({ message: 'No refundable amount remains.' });
  }

  const refund = await refundProviderPayment({
    order,
    amount: refundAmount,
    reason: String(req.body.reason || 'Admin-initiated refund.'),
  });

  order.refundedAmount += refundAmount;
  order.paymentStatus = order.refundedAmount >= order.total ? 'REFUNDED' : 'PARTIALLY_REFUNDED';
  order.refunds.push({
    refundId: `admin_refund_${Date.now()}`,
    providerRefundId: refund.refundId,
    amount: refundAmount,
    status: refund.status,
    reason: String(req.body.reason || 'Admin-initiated refund.'),
    createdAt: new Date(),
  });

  const customer = await UserModel.findById(order.userId);
  if (customer && order.paymentMethod === 'WALLET') {
    customer.walletBalance += refundAmount;
    customer.walletTransactions.push({
      amount: refundAmount,
      type: 'CREDIT',
      category: 'ORDER_REFUND',
      description: `Refund for order ${order._id.toString().slice(-6).toUpperCase()}`,
      orderId: order._id,
      createdAt: new Date(),
    });
    await customer.save();
  }

  if (req.body.cancelOrder === true && order.status !== 'CANCELLED' && order.status !== 'DELIVERED') {
    const restaurant = await RestaurantModel.findById(order.restaurantId);
    if (restaurant) {
      await cancelOrder({
        order,
        restaurant,
        reason: 'Cancelled during admin refund.',
      });
    }
  } else {
    await order.save();
  }

  return res.json({
    message: 'Refund initiated.',
    orderId: order._id.toString(),
    refundedAmount: order.refundedAmount,
    paymentStatus: order.paymentStatus,
  });
});

router.get('/notifications', async (req, res) => {
  const notifications = await AdminNotificationModel.find({
    targetRoles: { $in: [req.user.role] },
  }).sort({ createdAt: -1 });

  return res.json({
    notifications: notifications.map(serializeNotification),
  });
});

export { router as adminRoutes };

function serializeAdminConfig(
  config,
  {
    includeOtpSettings = false,
    includeSensitiveOtpFields = false,
  } = {},
) {
  return {
    globalCommissionRate: config.globalCommissionRate ?? 0.18,
    roleDefinitions: (config.roleDefinitions || []).map((item) => ({
      key: item.key,
      name: item.name,
      permissions: item.permissions || [],
      isSystem: item.isSystem ?? false,
    })),
    managedCategories: (config.managedCategories || []).map((item) => ({
      id: item.id,
      name: item.name,
      isActive: item.isActive ?? true,
    })),
    marketingBanners: (config.marketingBanners || []).map((item) => ({
      id: item.id,
      title: item.title,
      subtitle: item.subtitle,
      ctaText: item.ctaText || 'Order now',
      isActive: item.isActive ?? true,
    })),
    websiteSettings: {
      headline: config.websiteSettings?.headline || 'IndoFeast Digital Entry',
      subtitle: config.websiteSettings?.subtitle || '',
      qrLinks: (config.websiteSettings?.qrLinks || []).map((item) => ({
        id: item.id,
        title: item.title,
        description: item.description || '',
        url: item.url,
        isActive: item.isActive ?? true,
      })),
    },
    otpSettings: includeOtpSettings
      ? {
          enabled: config.otpSettings?.enabled === true,
          providerName: config.otpSettings?.providerName || 'Custom SMS API',
          apiUrl: config.otpSettings?.apiUrl || '',
          httpMethod: config.otpSettings?.httpMethod || 'POST',
          authToken: includeSensitiveOtpFields
            ? config.otpSettings?.authToken || ''
            : '',
          hasAuthToken: Boolean(config.otpSettings?.authToken),
          senderId: config.otpSettings?.senderId || 'INDOFEAST',
          messageTemplate:
            config.otpSettings?.messageTemplate ||
            'Your IndoFeast OTP is {{OTP}}. It expires in {{EXPIRY_MINUTES}} minutes.',
          requestHeaders:
            config.otpSettings?.requestHeaders ||
            '{"Content-Type":"application/json"}',
          requestBodyTemplate:
            config.otpSettings?.requestBodyTemplate ||
            '{"phone":"{{PHONE_NUMBER}}","message":"{{MESSAGE}}","senderId":"{{SENDER_ID}}"}',
          successStatusCodes:
            config.otpSettings?.successStatusCodes?.length
              ? config.otpSettings.successStatusCodes
              : [200, 201, 202],
        }
      : null,
  };
}

function buildAnalytics({ users, restaurants, orders }) {
  const completedOrders = orders.filter((order) => order.status === 'DELIVERED');
  const fulfilledOrders = orders.filter((order) => order.status !== 'CANCELLED');

  return {
    totalRevenue: completedOrders.reduce((sum, order) => sum + (order.total || 0), 0),
    totalOrders: orders.length,
    activeVendors: users.filter(
      (user) => user.role === 'VENDOR' && user.status === 'APPROVED',
    ).length,
    activeDeliveryPartners: users.filter(
      (user) =>
        user.role === 'DELIVERY_PARTNER' &&
        user.status === 'APPROVED' &&
        user.deliveryProfile?.isOnline,
    ).length,
    totalUsers: users.length,
    pendingApprovals: users.filter((user) => user.status === 'PENDING').length,
    suspendedAccounts: users.filter((user) => user.status === 'SUSPENDED').length,
    totalRestaurants: restaurants.length,
    completionRate:
      fulfilledOrders.length == 0
        ? 0
        : Math.round((completedOrders.length / fulfilledOrders.length) * 100),
  };
}

function buildTransactions(users) {
  return users
    .flatMap((user) =>
      (user.walletTransactions || []).map((transaction) => ({
        userId: user._id.toString(),
        userName: user.displayName,
        userRole: user.role,
        amount: transaction.amount,
        type: transaction.type,
        category: transaction.category || 'ADJUSTMENT',
        description: transaction.description,
        orderId: transaction.orderId?.toString() || null,
        createdAt: transaction.createdAt?.toISOString() || new Date().toISOString(),
      })),
    )
    .sort((left, right) => new Date(right.createdAt) - new Date(left.createdAt));
}

function buildReportSnapshot({
  orders,
  restaurants,
  transactions,
  analytics,
  days = 30,
}) {
  const ordersByStatus = orders.reduce((accumulator, order) => {
    accumulator[order.status] = (accumulator[order.status] || 0) + 1;
    return accumulator;
  }, {});

  const topVendors = restaurants
    .map((restaurant) => {
      const restaurantOrders = orders.filter(
        (order) => order.restaurantId?.toString() === restaurant._id.toString(),
      );
      const deliveredOrders = restaurantOrders.filter(
        (order) => order.status === 'DELIVERED',
      );
      return {
        restaurantName: restaurant.name,
        orders: restaurantOrders.length,
        revenue: deliveredOrders.reduce((sum, order) => sum + (order.total || 0), 0),
        platformProfit: deliveredOrders.reduce(
          (sum, order) => sum + (order.commissionAmount || 0),
          0,
        ),
        vendorEarnings: deliveredOrders.reduce(
          (sum, order) => sum + (order.vendorSettlementAmount || 0),
          0,
        ),
      };
    })
    .sort((left, right) => right.revenue - left.revenue)
    .slice(0, 5);

  const totalPlatformProfit = orders
    .filter((order) => order.status === 'DELIVERED')
    .reduce((sum, order) => sum + (order.commissionAmount || 0), 0);
  const totalVendorEarnings = orders
    .filter((order) => order.status === 'DELIVERED')
    .reduce((sum, order) => sum + (order.vendorSettlementAmount || 0), 0);

  return {
    days,
    generatedAt: new Date().toISOString(),
    summary: analytics,
    ordersByStatus,
    topVendors,
    totalCredits: transactions
      .filter((entry) => entry.type === 'CREDIT')
      .reduce((sum, entry) => sum + (entry.amount || 0), 0),
    totalDebits: transactions
      .filter((entry) => entry.type === 'DEBIT')
      .reduce((sum, entry) => sum + (entry.amount || 0), 0),
    totalPlatformProfit,
    totalVendorEarnings,
  };
}

function slugify(value) {
  return String(value)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function sanitizePermissions(value) {
  if (Array.isArray(value)) {
    return value.map((item) => String(item).trim()).filter(Boolean);
  }

  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function sanitizeStringArray(value) {
  if (Array.isArray(value)) {
    return value.map((item) => String(item).trim()).filter(Boolean);
  }

  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function sanitizeStatusCodes(value) {
  const source = Array.isArray(value)
    ? value
    : String(value || '')
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean);

  const normalized = source
    .map((item) => Number(item))
    .filter((item) => Number.isInteger(item) && item >= 100 && item <= 599);

  return normalized.length > 0 ? normalized : [200, 201, 202];
}

function ensureJsonString(value, label) {
  JSON.parse(value);
  return value;
}

async function syncUsersWithCustomRole(key, name, permissions) {
  await UserModel.updateMany(
    { customRoleKey: key },
    {
      customRoleName: name,
      permissions,
    },
  );
}

const demoAdminState = createDemoAdminState();

function findDemoUser(userId) {
  return demoAdminState.users.find((user) => user.id === userId) || null;
}

function buildDemoAdminDashboard() {
  const users = demoAdminState.users.map((user) => ({ ...user }));
  const totalUsers = users.length;
  const pendingApprovals = users.filter((user) => user.status === 'PENDING').length;
  const suspendedAccounts = users.filter((user) => user.status === 'SUSPENDED').length;
  const activeVendors = users.filter(
    (user) => user.role === 'VENDOR' && user.status === 'APPROVED',
  ).length;
  const activeDeliveryPartners = users.filter(
    (user) => user.role === 'DELIVERY_PARTNER' && user.status === 'APPROVED',
  ).length;

  return {
    analytics: {
      totalRevenue: 42860,
      totalOrders: 126,
      activeVendors,
      activeDeliveryPartners,
      totalUsers,
      pendingApprovals,
      suspendedAccounts,
      totalRestaurants: 8,
      completionRate: 94,
    },
    users,
    restaurants: [],
    transactions: demoAdminState.transactions.map((item) => ({ ...item })),
    notifications: demoAdminState.notifications.map((item) => ({ ...item })),
    config: {
      ...demoAdminState.config,
      roleDefinitions: demoAdminState.config.roleDefinitions.map((item) => ({
        ...item,
        permissions: [...(item.permissions || [])],
      })),
      managedCategories: demoAdminState.config.managedCategories.map((item) => ({ ...item })),
      marketingBanners: demoAdminState.config.marketingBanners.map((item) => ({ ...item })),
      otpSettings: {
        ...(demoAdminState.config.otpSettings || {}),
        successStatusCodes: [
          ...((demoAdminState.config.otpSettings || {}).successStatusCodes || [
            200,
            201,
            202,
          ]),
        ],
      },
    },
    report: {
      days: 30,
      generatedAt: new Date().toISOString(),
      summary: {
        totalRevenue: 42860,
        totalOrders: 126,
        activeVendors,
        activeDeliveryPartners,
        totalUsers,
        pendingApprovals,
        suspendedAccounts,
        totalRestaurants: 8,
        completionRate: 94,
      },
      ordersByStatus: {
        DELIVERED: 102,
        CANCELLED: 8,
        OUT_FOR_DELIVERY: 4,
        PREPARING: 6,
        ACCEPTED: 6,
      },
      topVendors: [
        {
          restaurantName: 'IndoFeast Kitchen',
          orders: 32,
          revenue: 15200,
          platformProfit: 2736,
          vendorEarnings: 12464,
        },
        {
          restaurantName: 'Spice Route',
          orders: 24,
          revenue: 11860,
          platformProfit: 2135,
          vendorEarnings: 9725,
        },
      ],
      totalCredits: 11240,
      totalDebits: 8740,
      totalPlatformProfit: 7720,
      totalVendorEarnings: 35140,
    },
  };
}

function createDemoAdminState() {
  const now = new Date().toISOString();

  return {
    users: [
      {
        id: 'demo-super-admin',
        email: env.defaultAdminEmail.toLowerCase(),
        displayName: env.defaultAdminName,
        phoneNumber: '+910000000000',
        role: 'SUPER_ADMIN',
        customRoleKey: null,
        customRoleName: null,
        permissions: [
          'dashboard:view',
          'users:manage',
          'approvals:manage',
          'roles:manage',
          'categories:manage',
          'banners:manage',
          'notifications:broadcast',
          'transactions:view',
          'reports:view',
          'commission:manage',
        ],
        status: 'APPROVED',
        walletBalance: 0,
        walletTransactions: [],
        deliveryProfile: null,
        createdAt: now,
        documentUrl: null,
        documentName: null,
        rejectionReason: null,
      },
      {
        id: 'demo-platform-admin',
        email: 'admin@indofeast.com',
        displayName: 'Priya Platform Admin',
        phoneNumber: '+910000000001',
        role: 'ADMIN',
        customRoleKey: 'platform_admin',
        customRoleName: 'Platform Admin',
        permissions: [
          'dashboard:view',
          'users:manage',
          'approvals:manage',
          'roles:manage',
          'categories:manage',
          'banners:manage',
          'notifications:broadcast',
          'transactions:view',
          'reports:view',
          'commission:manage',
        ],
        status: 'APPROVED',
        walletBalance: 0,
        walletTransactions: [],
        deliveryProfile: null,
        createdAt: now,
        documentUrl: null,
        documentName: null,
        rejectionReason: null,
      },
      {
        id: 'demo-ops-manager',
        email: 'manager@indofeast.com',
        displayName: 'Rohit Ops Manager',
        phoneNumber: '+910000000002',
        role: 'MANAGER',
        customRoleKey: 'ops_manager',
        customRoleName: 'Ops Manager',
        permissions: [
          'dashboard:view',
          'users:manage',
          'approvals:manage',
          'notifications:broadcast',
          'reports:view',
          'categories:manage',
          'banners:manage',
        ],
        status: 'APPROVED',
        walletBalance: 0,
        walletTransactions: [],
        deliveryProfile: null,
        createdAt: now,
        documentUrl: null,
        documentName: null,
        rejectionReason: null,
      },
      {
        id: 'demo-vendor',
        email: 'vendor@indofeast.com',
        displayName: 'Neha Vendor',
        phoneNumber: '+910000000003',
        role: 'VENDOR',
        customRoleKey: null,
        customRoleName: null,
        permissions: [],
        status: 'PENDING',
        walletBalance: 2400,
        walletTransactions: [],
        deliveryProfile: null,
        createdAt: now,
        documentUrl: 'vendor-license.pdf',
        documentName: 'vendor-license.pdf',
        rejectionReason: null,
      },
      {
        id: 'demo-delivery',
        email: 'delivery@indofeast.com',
        displayName: 'Arjun Delivery',
        phoneNumber: '+910000000004',
        role: 'DELIVERY_PARTNER',
        customRoleKey: null,
        customRoleName: null,
        permissions: [],
        status: 'APPROVED',
        walletBalance: 1180,
        walletTransactions: [],
        deliveryProfile: {
          isOnline: true,
          currentZone: 'Central Zone',
          vehicleLabel: 'Bike',
          lastSeenAt: now,
        },
        createdAt: now,
        documentUrl: 'license-card.jpg',
        documentName: 'license-card.jpg',
        rejectionReason: null,
      },
      {
        id: 'demo-customer',
        email: 'customer@indofeast.com',
        displayName: 'Kavya Customer',
        phoneNumber: '+910000000005',
        role: 'CUSTOMER',
        customRoleKey: null,
        customRoleName: null,
        permissions: [],
        status: 'APPROVED',
        walletBalance: 699,
        walletTransactions: [],
        deliveryProfile: null,
        createdAt: now,
        documentUrl: null,
        documentName: null,
        rejectionReason: null,
      },
    ],
    transactions: [
      {
        userId: 'demo-delivery',
        userName: 'Arjun Delivery',
        userRole: 'DELIVERY_PARTNER',
        amount: 420,
        type: 'CREDIT',
        category: 'DELIVERY_EARNING',
        description: 'Delivery earning payout',
        orderId: 'demo-order-1',
        createdAt: now,
      },
      {
        userId: 'demo-customer',
        userName: 'Kavya Customer',
        userRole: 'CUSTOMER',
        amount: 699,
        type: 'DEBIT',
        category: 'ORDER_PAYMENT',
        description: 'Order payment captured',
        orderId: 'demo-order-2',
        createdAt: now,
      },
    ],
    notifications: [
      {
        id: 'demo-notification-1',
        title: 'Demo mode enabled',
        body: 'MongoDB is unavailable, so the backend started with demo admin data.',
        createdAt: now,
        targetRoles: ADMIN_FAMILY,
        isRead: false,
        relatedUserId: null,
      },
    ],
    config: {
      globalCommissionRate: 0.18,
      roleDefinitions: [
        {
          key: 'ops_manager',
          name: 'Ops Manager',
          permissions: [
            'dashboard:view',
            'users:manage',
            'approvals:manage',
            'notifications:broadcast',
            'reports:view',
            'categories:manage',
            'banners:manage',
          ],
          isSystem: true,
        },
        {
          key: 'platform_admin',
          name: 'Platform Admin',
          permissions: [
            'dashboard:view',
            'users:manage',
            'approvals:manage',
            'roles:manage',
            'categories:manage',
            'banners:manage',
            'notifications:broadcast',
            'transactions:view',
            'reports:view',
            'commission:manage',
          ],
          isSystem: true,
        },
      ],
      managedCategories: [
        { id: 'cat-1', name: 'North Indian', isActive: true },
        { id: 'cat-2', name: 'Biryani', isActive: true },
        { id: 'cat-3', name: 'Desserts', isActive: true },
      ],
      marketingBanners: [
        {
          id: 'banner-1',
          title: 'Free delivery weekend',
          subtitle: 'Boost weekend orders with limited-time promos.',
          ctaText: 'Launch promo',
          isActive: true,
        },
      ],
      otpSettings: {
        enabled: false,
        providerName: 'Custom SMS API',
        apiUrl: '',
        httpMethod: 'POST',
        authToken: '',
        senderId: 'INDOFEAST',
        messageTemplate:
          'Your IndoFeast OTP is {{OTP}}. It expires in {{EXPIRY_MINUTES}} minutes.',
        requestHeaders: '{"Content-Type":"application/json"}',
        requestBodyTemplate:
          '{"phone":"{{PHONE_NUMBER}}","message":"{{MESSAGE}}","senderId":"{{SENDER_ID}}"}',
        successStatusCodes: [200, 201, 202],
      },
    },
  };
}
