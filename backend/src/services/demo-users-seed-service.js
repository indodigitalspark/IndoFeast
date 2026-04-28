import bcrypt from 'bcryptjs';

import { RestaurantModel } from '../models/restaurant-model.js';
import { UserModel } from '../models/user-model.js';
import { getOrCreateAdminConfig } from './admin-config-service.js';

const demoPassword = 'Demo123@';

const demoUsers = [
  {
    displayName: 'Aman IndoFeast',
    email: 'aman@indofeast.com',
    phoneNumber: '+910000000000',
    role: 'SUPER_ADMIN',
    status: 'APPROVED',
  },
  {
    displayName: 'Priya Platform Admin',
    email: 'admin@indofeast.com',
    phoneNumber: '+910000000001',
    role: 'ADMIN',
    status: 'APPROVED',
  },
  {
    displayName: 'Rohit Ops Manager',
    email: 'manager@indofeast.com',
    phoneNumber: '+910000000002',
    role: 'MANAGER',
    status: 'APPROVED',
    customRoleKey: 'ops_manager',
  },
  {
    displayName: 'Neha Vendor',
    email: 'vendor@indofeast.com',
    phoneNumber: '+910000000003',
    role: 'VENDOR',
    status: 'APPROVED',
  },
  {
    displayName: 'Arjun Delivery',
    email: 'delivery@indofeast.com',
    phoneNumber: '+910000000004',
    role: 'DELIVERY_PARTNER',
    status: 'APPROVED',
    deliveryProfile: {
      isOnline: false,
      currentZone: 'Central Zone',
      vehicleLabel: 'Bike',
    },
  },
  {
    displayName: 'Kavya Customer',
    email: 'customer@indofeast.com',
    phoneNumber: '+910000000005',
    role: 'CUSTOMER',
    status: 'APPROVED',
  },
];

export async function ensureDemoUsers() {
  const config = await getOrCreateAdminConfig();
  const passwordHash = await bcrypt.hash(demoPassword, 12);

  for (const seed of demoUsers) {
    const existing = await UserModel.findOne({ email: seed.email.toLowerCase() });
    if (existing) {
      let changed = false;

      if (existing.status !== seed.status) {
        existing.status = seed.status;
        changed = true;
      }

      if (existing.role !== seed.role) {
        existing.role = seed.role;
        changed = true;
      }

      const customRole = seed.customRoleKey
        ? config.roleDefinitions.find((item) => item.key === seed.customRoleKey)
        : null;
      const nextPermissions = customRole?.permissions || [];

      if ((existing.customRoleKey || null) !== (customRole?.key || null)) {
        existing.customRoleKey = customRole?.key || null;
        existing.customRoleName = customRole?.name || null;
        changed = true;
      }

      if (JSON.stringify(existing.permissions || []) !== JSON.stringify(nextPermissions)) {
        existing.permissions = nextPermissions;
        changed = true;
      }

      if (seed.deliveryProfile && !existing.deliveryProfile) {
        existing.deliveryProfile = seed.deliveryProfile;
        changed = true;
      }

      if (changed) {
        await existing.save();
      }
      continue;
    }

    const customRole = seed.customRoleKey
      ? config.roleDefinitions.find((item) => item.key === seed.customRoleKey)
      : null;

    await UserModel.create({
      displayName: seed.displayName,
      email: seed.email.toLowerCase(),
      phoneNumber: seed.phoneNumber,
      passwordHash,
      role: seed.role,
      status: seed.status,
      customRoleKey: customRole?.key || null,
      customRoleName: customRole?.name || null,
      permissions: customRole?.permissions || [],
      deliveryProfile: seed.deliveryProfile,
    });
  }

  await ensureDemoVendorRestaurant();
}

async function ensureDemoVendorRestaurant() {
  const vendor = await UserModel.findOne({ email: 'vendor@indofeast.com' });
  if (!vendor) {
    return;
  }

  const existingVendorRestaurant = await RestaurantModel.findOne({
    ownerId: vendor._id,
  });
  if (existingVendorRestaurant) {
    return;
  }

  const unassignedRestaurant = await RestaurantModel.findOne({
    $or: [{ ownerId: { $exists: false } }, { ownerId: null }],
  }).sort({ createdAt: 1 });

  if (unassignedRestaurant) {
    unassignedRestaurant.ownerId = vendor._id;
    await unassignedRestaurant.save();
    return;
  }

  await RestaurantModel.create({
    ownerId: vendor._id,
    name: 'Demo Vendor Kitchen',
    cuisine: ['North Indian', 'Meals'],
    category: 'Meals',
    rating: 4.5,
    deliveryTime: 25,
    priceLevel: 'Rs 300 for two',
    offerText: 'Demo vendor special combo',
    description: 'Seeded restaurant for vendor dashboard testing.',
    accentColor: '#F9E7D2',
    heroTag: 'DEMO',
    menuItems: [
      {
        itemId: 'demo-paneer-meal',
        name: 'Paneer Meal Box',
        description: 'Paneer curry, jeera rice, roti, and salad.',
        category: 'Meals',
        price: 229,
        stock: 30,
        isAvailable: true,
        isVeg: true,
        bestseller: true,
        imagePath: 'backend/uploads/demo-paneer-meal-box.jpg',
        discountPercent: 15,
        preparationTimeMin: 20,
        preparationTimeMax: 25,
        addOns: ['Extra roti', 'Extra paneer gravy'],
        customizationOptions: ['Jain option', 'Low spice', 'Extra spicy'],
      },
      {
        itemId: 'demo-chicken-roll',
        name: 'Chicken Kathi Roll',
        description: 'Spiced chicken wrapped in flaky paratha.',
        category: 'Snacks',
        price: 159,
        stock: 40,
        isAvailable: true,
        isVeg: false,
        bestseller: false,
        imagePath: 'backend/uploads/demo-chicken-kathi-roll.jpg',
        discountPercent: 5,
        preparationTimeMin: 15,
        preparationTimeMax: 20,
        addOns: ['Extra mayo', 'Cheese slice'],
        customizationOptions: ['No onion', 'Extra spicy'],
      },
    ],
  });
}
