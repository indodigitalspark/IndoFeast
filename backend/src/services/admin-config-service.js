import crypto from 'node:crypto';

import { AdminConfigModel } from '../models/admin-config-model.js';

export async function getOrCreateAdminConfig() {
  let config = await AdminConfigModel.findOne({ key: 'platform' });
  if (config) {
    return config;
  }

  config = await AdminConfigModel.create({
    key: 'platform',
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
        key: 'finance_analyst',
        name: 'Finance Analyst',
        permissions: [
          'dashboard:view',
          'transactions:view',
          'reports:view',
          'commission:manage',
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
      { id: crypto.randomUUID(), name: 'Biryani', isActive: true },
      { id: crypto.randomUUID(), name: 'Meals', isActive: true },
      { id: crypto.randomUUID(), name: 'Snacks', isActive: true },
    ],
    marketingBanners: [
      {
        id: crypto.randomUUID(),
        title: 'Weekend Feast Deals',
        subtitle: 'Spotlight top vendors and keep order volumes high.',
        ctaText: 'Explore offers',
        isActive: true,
      },
      {
        id: crypto.randomUUID(),
        title: 'Free Delivery Rush',
        subtitle: 'Turn on promotions for high-intent customer windows.',
        ctaText: 'Order today',
        isActive: true,
      },
    ],
    websiteSettings: {
      headline: 'IndoFeast Digital Entry',
      subtitle:
        'Scan the right QR to sign in, register, or open the right IndoFeast journey.',
      qrLinks: [
        {
          id: crypto.randomUUID(),
          title: 'Portal Sign In',
          description: 'Open the login page for approved users.',
          url: 'https://app.indofeast.com/?mode=signIn',
          isActive: true,
        },
        {
          id: crypto.randomUUID(),
          title: 'Customer Register',
          description: 'Create a customer account with OTP verification.',
          url: 'https://app.indofeast.com/?mode=register&role=CUSTOMER',
          isActive: true,
        },
        {
          id: crypto.randomUUID(),
          title: 'Vendor Register',
          description: 'Register a vendor store and submit for approval.',
          url: 'https://app.indofeast.com/?mode=register&role=VENDOR',
          isActive: true,
        },
        {
          id: crypto.randomUUID(),
          title: 'Delivery Register',
          description: 'Register a delivery partner account and submit for approval.',
          url: 'https://app.indofeast.com/?mode=register&role=DELIVERY_PARTNER',
          isActive: true,
        },
      ],
    },
  });

  return config;
}
