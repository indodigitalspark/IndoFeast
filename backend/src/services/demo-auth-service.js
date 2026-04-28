import { env } from '../config/env.js';

const demoAdminUser = {
  _id: 'demo-super-admin',
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
  createdAt: new Date(),
  updatedAt: new Date(),
  rejectionReason: null,
  document: null,
};

export function getDemoAdminUser() {
  return {
    ...demoAdminUser,
    createdAt: new Date(demoAdminUser.createdAt),
    updatedAt: new Date(),
  };
}

export function isDemoAdminCredentials({ email, password, role }) {
  return (
    String(email || '').toLowerCase() === env.defaultAdminEmail.toLowerCase() &&
    String(password || '') === env.defaultAdminPassword &&
    (!role || String(role || '').toUpperCase() === 'SUPER_ADMIN')
  );
}
