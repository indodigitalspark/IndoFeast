import crypto from 'node:crypto';

import express from 'express';

import { upload } from '../config/uploads.js';
import { requireAuth, requireRoles } from '../middleware/auth-middleware.js';
import { OrderModel } from '../models/order-model.js';
import { RestaurantModel } from '../models/restaurant-model.js';
import { getOrCreateAdminConfig } from '../services/admin-config-service.js';
import {
  cancelOrder,
  markOrderDelivered,
} from '../services/order-lifecycle-service.js';
import {
  initializeSse,
  pushSse,
  watchChangeStreams,
} from '../services/realtime-service.js';
import {
  serializeOrder,
  serializeRestaurant,
} from '../utils/serializers.js';

const router = express.Router();

router.use(requireAuth, requireRoles('VENDOR'));

function parseStringList(value) {
  if (Array.isArray(value)) {
    return value
      .map((item) => String(item).trim())
      .filter(Boolean);
  }

  if (typeof value === 'string') {
    return value
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
  }

  return [];
}

router.get('/dashboard', async (req, res) => {
  const restaurant = await getOrCreateVendorRestaurant(req.user);
  const orders = await OrderModel.find({ restaurantId: restaurant._id }).sort({
    createdAt: -1,
  });

  const today = buildReport(orders, restaurant.commissionRate, 1);
  const weekly = buildReport(orders, restaurant.commissionRate, 7);
  const monthly = buildReport(orders, restaurant.commissionRate, 30);

  return res.json({
    restaurant: serializeRestaurant(restaurant),
    today,
    weekly,
    monthly,
    orders: orders.map(serializeOrder),
  });
});

router.patch('/store-status', async (req, res) => {
  const restaurant = await getOrCreateVendorRestaurant(req.user);
  const nextStatus = String(req.body.storeStatus || '').trim().toUpperCase();

  if (!['OPEN', 'CLOSED'].includes(nextStatus)) {
    return res.status(400).json({ message: 'Store status must be OPEN or CLOSED.' });
  }

  restaurant.storeStatus = nextStatus;
  await restaurant.save();

  return res.json({
    message: `Store marked as ${nextStatus}.`,
    restaurant: serializeRestaurant(restaurant),
  });
});

router.post('/products', upload.single('image'), async (req, res) => {
  const restaurant = await getOrCreateVendorRestaurant(req.user);
  const {
    name,
    description,
    category,
    price,
    stock,
    isVeg,
    bestseller,
    isAvailable,
    discountPercent,
    preparationTimeMin,
    preparationTimeMax,
    addOns,
    customizationOptions,
  } = req.body;

  const product = {
    itemId: crypto.randomUUID(),
    name,
    description,
    category: category || 'Main Course',
    price: Number(price),
    stock: Number(stock ?? 0),
    isVeg: isVeg === 'true',
    bestseller: bestseller === 'true',
    isAvailable: isAvailable != null ? isAvailable === 'true' : true,
    imagePath: req.file?.path,
    discountPercent: Number(discountPercent ?? 0),
    preparationTimeMin: Number(preparationTimeMin ?? 20),
    preparationTimeMax: Number(preparationTimeMax ?? 25),
    addOns: parseStringList(addOns),
    customizationOptions: parseStringList(customizationOptions),
  };

  restaurant.menuItems.push(product);
  await restaurant.save();

  return res.status(201).json({
    message: 'Product added.',
    restaurant: serializeRestaurant(restaurant),
  });
});

router.patch('/products/:itemId', upload.single('image'), async (req, res) => {
  const restaurant = await getOrCreateVendorRestaurant(req.user);
  const item = restaurant.menuItems.find(
    (entry) => entry.itemId === req.params.itemId,
  );

  if (!item) {
    return res.status(404).json({ message: 'Product not found.' });
  }

  item.name = req.body.name ?? item.name;
  item.description = req.body.description ?? item.description;
  item.category = req.body.category ?? item.category;
  item.price = Number(req.body.price ?? item.price);
  item.stock = Number(req.body.stock ?? item.stock);
  item.isVeg = req.body.isVeg != null ? req.body.isVeg === 'true' : item.isVeg;
  item.bestseller =
    req.body.bestseller != null
      ? req.body.bestseller === 'true'
      : item.bestseller;
  item.isAvailable =
    req.body.isAvailable != null
      ? req.body.isAvailable === 'true'
      : item.isAvailable;
  item.discountPercent = Number(req.body.discountPercent ?? item.discountPercent);
  item.preparationTimeMin = Number(
    req.body.preparationTimeMin ?? item.preparationTimeMin,
  );
  item.preparationTimeMax = Number(
    req.body.preparationTimeMax ?? item.preparationTimeMax,
  );
  item.addOns =
    req.body.addOns != null ? parseStringList(req.body.addOns) : item.addOns;
  item.customizationOptions =
    req.body.customizationOptions != null
      ? parseStringList(req.body.customizationOptions)
      : item.customizationOptions;
  if (req.file?.path) {
    item.imagePath = req.file.path;
  }

  await restaurant.save();

  return res.json({
    message: 'Product updated.',
    restaurant: serializeRestaurant(restaurant),
  });
});

router.delete('/products/:itemId', async (req, res) => {
  const restaurant = await getOrCreateVendorRestaurant(req.user);
  restaurant.menuItems = restaurant.menuItems.filter(
    (entry) => entry.itemId !== req.params.itemId,
  );
  await restaurant.save();

  return res.json({
    message: 'Product deleted.',
    restaurant: serializeRestaurant(restaurant),
  });
});

router.patch('/products/:itemId/stock', async (req, res) => {
  const restaurant = await getOrCreateVendorRestaurant(req.user);
  const item = restaurant.menuItems.find(
    (entry) => entry.itemId === req.params.itemId,
  );

  if (!item) {
    return res.status(404).json({ message: 'Product not found.' });
  }

  item.stock = Number(req.body.stock ?? item.stock);
  item.isAvailable =
    req.body.isAvailable != null
      ? Boolean(req.body.isAvailable)
      : item.stock > 0;
  await restaurant.save();

  return res.json({
    message: 'Stock updated.',
    restaurant: serializeRestaurant(restaurant),
  });
});

router.patch('/orders/:id/decision', async (req, res) => {
  const restaurant = await getOrCreateVendorRestaurant(req.user);
  const order = await OrderModel.findOne({
    _id: req.params.id,
    restaurantId: restaurant._id,
  });

  if (!order) {
    return res.status(404).json({ message: 'Order not found.' });
  }

  if (!['PAID', 'PENDING_COD_COLLECTION'].includes(order.paymentStatus)) {
    return res.status(400).json({ message: 'Payment must be verified before vendor action.' });
  }

  const decision = String(req.body.decision || '').toUpperCase();
  if (decision === 'ACCEPT') {
    order.status = 'ACCEPTED';
  } else if (decision === 'REJECT' || decision === 'CANCEL') {
    await cancelOrder({
      order,
      restaurant,
      reason: 'Cancelled by vendor during order review.',
    });
    return res.json({
      message: 'Order cancelled.',
      order: serializeOrder(order),
    });
  } else {
    return res.status(400).json({ message: 'Unsupported decision.' });
  }

  await order.save();
  await restaurant.save();

  return res.json({
    message: 'Order accepted.',
    order: serializeOrder(order),
  });
});

router.patch('/orders/:id/status', async (req, res) => {
  const restaurant = await getOrCreateVendorRestaurant(req.user);
  const order = await OrderModel.findOne({
    _id: req.params.id,
    restaurantId: restaurant._id,
  });

  if (!order) {
    return res.status(404).json({ message: 'Order not found.' });
  }

  if (!['PAID', 'PENDING_COD_COLLECTION'].includes(order.paymentStatus)) {
    return res.status(400).json({ message: 'Payment must be verified before status changes.' });
  }

  const nextStatus = String(req.body.status || '').toUpperCase();
  const allowed = new Set(['ACCEPTED', 'PREPARING', 'CANCELLED']);

  if (!allowed.has(nextStatus)) {
    return res.status(400).json({ message: 'Unsupported order status.' });
  }

  if (nextStatus === 'CANCELLED') {
    await cancelOrder({
      order,
      restaurant,
      reason: 'Cancelled by vendor.',
    });
    return res.json({
      message: 'Order cancelled.',
      order: serializeOrder(order),
    });
  }

  if (nextStatus === 'ACCEPTED' && order.status !== 'PLACED') {
    return res.status(400).json({ message: 'Order can only be accepted from PLACED.' });
  }

  if (nextStatus === 'PREPARING' && !['ACCEPTED', 'PREPARING'].includes(order.status)) {
    return res.status(400).json({ message: 'Order must be accepted before preparing.' });
  }

  order.status = nextStatus;
  await order.save();

  return res.json({
    message: 'Order status updated.',
    order: serializeOrder(order),
  });
});

router.post('/orders/:id/verify-otp', async (req, res) => {
  const restaurant = await getOrCreateVendorRestaurant(req.user);
  const order = await OrderModel.findOne({
    _id: req.params.id,
    restaurantId: restaurant._id,
  });

  if (!order) {
    return res.status(404).json({ message: 'Order not found.' });
  }

  if (order.status === 'CANCELLED' || order.status === 'DELIVERED') {
    return res.status(400).json({ message: 'This order is already closed.' });
  }

  const otp = String(req.body.otp || '').trim();
  if (!otp || otp !== order.deliveryOtp) {
    return res.status(400).json({ message: 'Invalid verification OTP.' });
  }

  if (order.orderMode === 'DELIVERY') {
    if (!['ACCEPTED', 'PREPARING'].includes(order.status)) {
      return res.status(400).json({
        message: 'Delivery OTP can only be verified before dispatch.',
      });
    }

    if (!order.deliveryPartnerId) {
      return res.status(400).json({
        message: 'Assign a delivery partner before verifying handoff OTP.',
      });
    }

    order.pickupConfirmedAt = new Date();
    order.status = 'OUT_FOR_DELIVERY';
    await order.save();

    return res.json({
      message: 'Delivery partner verified. Order is now out for delivery.',
      order: serializeOrder(order),
    });
  }

  if (!['ACCEPTED', 'PREPARING'].includes(order.status)) {
    return res.status(400).json({
      message: 'Pickup and dine-in OTP can only be verified while processing.',
    });
  }

  await markOrderDelivered({ order, restaurant });

  return res.json({
    message:
      order.orderMode === 'PICKUP'
        ? 'Pickup verified and order completed.'
        : 'Dine-in verification complete and order closed.',
    order: serializeOrder(order),
  });
});

router.get('/dashboard/stream', async (req, res) => {
  const restaurant = await getOrCreateVendorRestaurant(req.user);
  const closeConnection = initializeSse(res);
  pushSse(res, { type: 'ready', scope: 'vendor-dashboard' });

  const restaurantId = restaurant._id.toString();
  const stopWatching = watchChangeStreams([
    {
      model: OrderModel,
      onChange: (change) => {
        const order = change.fullDocument;
        if (order?.restaurantId?.toString() === restaurantId) {
          pushSse(res, { type: 'refresh', scope: 'vendor-dashboard' });
        }
      },
    },
    {
      model: RestaurantModel,
      onChange: (change) => {
        const document = change.fullDocument;
        if (document?._id?.toString() === restaurantId) {
          pushSse(res, { type: 'refresh', scope: 'vendor-dashboard' });
        }
      },
    },
  ]);

  req.on('close', async () => {
    await stopWatching();
    closeConnection();
  });
});

async function getOrCreateVendorRestaurant(user) {
  let restaurant = await RestaurantModel.findOne({ ownerId: user._id });
  if (restaurant) {
    return restaurant;
  }

  const config = await getOrCreateAdminConfig();

  restaurant = await RestaurantModel.create({
    ownerId: user._id,
    name: `${user.displayName}'s Kitchen`,
    cuisine: ['Indian', 'Fusion'],
    category: 'Meals',
    rating: 4.2,
    deliveryTime: 30,
    priceLevel: 'Rs 300 for two',
    offerText: 'Freshly onboarded vendor',
    description: 'Manage your menu, stock, and orders from one partner console.',
    accentColor: '#F1F7F4',
    heroTag: 'NEW PARTNER',
    commissionRate: config.globalCommissionRate ?? 0.18,
    pendingSettlementAmount: 0,
    lifetimeSettlementAmount: 0,
    menuItems: [
      {
        itemId: crypto.randomUUID(),
        name: 'House Special Thali',
        description: 'Starter product to help you begin selling immediately.',
        category: 'Main Course',
        price: 229,
        stock: 20,
        isVeg: true,
        bestseller: true,
        isAvailable: true,
      },
    ],
  });

  return restaurant;
}

function buildReport(orders, commissionRate, days) {
  const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
  const scoped = orders.filter(
    (order) =>
      new Date(order.createdAt).getTime() >= cutoff && order.status !== 'CANCELLED',
  );
  const delivered = scoped.filter((order) => order.status === 'DELIVERED');
  const grossSales = delivered.reduce((sum, order) => sum + order.total, 0);
  const commissionDeduction = delivered.reduce(
    (sum, order) => sum + (order.commissionAmount || Math.round(order.total * commissionRate)),
    0,
  );
  const netPayout = delivered.reduce(
    (sum, order) =>
      sum +
      (order.vendorSettlementAmount ||
        Math.max(order.total - Math.round(order.total * commissionRate), 0)),
    0,
  );
  const completedOrders = delivered.length;

  return {
    grossSales,
    commissionDeduction,
    netPayout,
    orderCount: scoped.length,
    completedOrders,
  };
}

export { router as vendorRoutes };
