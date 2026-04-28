import express from 'express';

import { requireAuth, requireRoles } from '../middleware/auth-middleware.js';
import { OrderModel } from '../models/order-model.js';
import { RestaurantModel } from '../models/restaurant-model.js';
import { UserModel } from '../models/user-model.js';
import { markOrderDelivered } from '../services/order-lifecycle-service.js';
import {
  initializeSse,
  pushSse,
  watchChangeStreams,
} from '../services/realtime-service.js';
import { serializeOrder, serializeUser } from '../utils/serializers.js';

const router = express.Router();

router.use(requireAuth, requireRoles('DELIVERY_PARTNER'));

router.get('/dashboard', async (req, res) => {
  await ensureDeliveryProfile(req.user);

  const [availableOrders, assignedOrders, partner] = await Promise.all([
    OrderModel.find({
      orderMode: 'DELIVERY',
      status: { $in: ['ACCEPTED', 'PREPARING'] },
      $or: [{ deliveryPartnerId: { $exists: false } }, { deliveryPartnerId: null }],
    }).sort({ createdAt: -1 }),
    OrderModel.find({
      orderMode: 'DELIVERY',
      deliveryPartnerId: req.user._id,
      status: { $in: ['ACCEPTED', 'PREPARING', 'OUT_FOR_DELIVERY'] },
    }).sort({ createdAt: -1 }),
    UserModel.findById(req.user._id),
  ]);

  return res.json({
    partner: serializeUser(partner),
    availableOrders: availableOrders.map(serializeOrder),
    assignedOrders: assignedOrders.map(serializeOrder),
    earnings: buildEarnings(partner?.walletTransactions || []),
    paymentHistory: (partner?.walletTransactions || []).slice().reverse(),
  });
});

router.patch('/availability', async (req, res) => {
  const isOnline = Boolean(req.body.isOnline);
  await ensureDeliveryProfile(req.user);
  req.user.deliveryProfile.isOnline = isOnline;
  req.user.deliveryProfile.lastSeenAt = new Date();
  await req.user.save();

  return res.json({
    message: `You are now ${isOnline ? 'online' : 'offline'}.`,
    partner: serializeUser(req.user),
  });
});

router.post('/orders/:id/accept', async (req, res) => {
  await ensureDeliveryProfile(req.user);
  if (!req.user.deliveryProfile?.isOnline) {
    return res.status(400).json({ message: 'Go online before accepting deliveries.' });
  }

  const order = await OrderModel.findOne({
    _id: req.params.id,
    orderMode: 'DELIVERY',
    status: { $in: ['ACCEPTED', 'PREPARING'] },
    $or: [{ deliveryPartnerId: { $exists: false } }, { deliveryPartnerId: null }],
  });

  if (!order) {
    return res.status(404).json({ message: 'Order is no longer available.' });
  }

  order.deliveryPartnerId = req.user._id;
  order.deliveryPartnerName = req.user.displayName;
  order.deliveryAcceptedAt = new Date();
  order.assignedAt = new Date();
  await order.save();

  return res.json({
    message: 'Order assigned to you.',
    order: serializeOrder(order),
  });
});

router.post('/orders/:id/pickup', async (req, res) => {
  const order = await OrderModel.findOne({
    _id: req.params.id,
    deliveryPartnerId: req.user._id,
    orderMode: 'DELIVERY',
  });

  if (!order) {
    return res.status(404).json({ message: 'Assigned order not found.' });
  }

  if (order.pickupConfirmedAt) {
    return res.status(400).json({ message: 'Pickup already confirmed.' });
  }

  if (!['ACCEPTED', 'PREPARING'].includes(order.status)) {
    return res.status(400).json({ message: 'Order is not ready for pickup.' });
  }

  order.pickupConfirmedAt = new Date();
  order.status = 'OUT_FOR_DELIVERY';
  await order.save();

  return res.json({
    message: 'Pickup confirmed. Start navigation to the customer.',
    order: serializeOrder(order),
  });
});

router.patch('/orders/:id/location', async (req, res) => {
  const order = await OrderModel.findOne({
    _id: req.params.id,
    deliveryPartnerId: req.user._id,
    orderMode: 'DELIVERY',
  });

  if (!order) {
    return res.status(404).json({ message: 'Assigned order not found.' });
  }

  const latitude = Number(req.body.latitude);
  const longitude = Number(req.body.longitude);
  if (Number.isNaN(latitude) || Number.isNaN(longitude)) {
    return res.status(400).json({ message: 'Latitude and longitude are required.' });
  }

  order.deliveryPartnerLatitude = latitude;
  order.deliveryPartnerLongitude = longitude;
  order.locationUpdatedAt = new Date();
  await order.save();

  return res.json({
    message: 'Live location updated.',
    order: serializeOrder(order),
  });
});

router.post('/orders/:id/verify-otp', async (req, res) => {
  const otp = String(req.body.otp || '').trim();
  const order = await OrderModel.findOne({
    _id: req.params.id,
    deliveryPartnerId: req.user._id,
    orderMode: 'DELIVERY',
  });

  if (!order) {
    return res.status(404).json({ message: 'Assigned order not found.' });
  }

  if (!order.pickupConfirmedAt) {
    return res.status(400).json({ message: 'Confirm pickup before verifying delivery OTP.' });
  }

  if (order.status === 'DELIVERED') {
    return res.status(400).json({ message: 'Order has already been delivered.' });
  }

  if (!otp || otp !== order.deliveryOtp) {
    return res.status(400).json({ message: 'Invalid delivery OTP.' });
  }

  const restaurant = await RestaurantModel.findById(order.restaurantId);
  if (!restaurant) {
    return res.status(404).json({ message: 'Restaurant not found for settlement.' });
  }

  await markOrderDelivered({ order, restaurant });

  const earning = calculateDeliveryEarning(order.total);
  req.user.walletBalance += earning;
  req.user.walletTransactions.push({
    amount: earning,
    type: 'CREDIT',
    category: 'DELIVERY_EARNING',
    description: `Delivery earnings for order ${order._id.toString().slice(-6).toUpperCase()}`,
    orderId: order._id,
    createdAt: new Date(),
  });
  await req.user.save();

  return res.json({
    message: 'Delivery verified and earnings added.',
    order: serializeOrder(order),
    partner: serializeUser(req.user),
  });
});

router.get('/dashboard/stream', async (req, res) => {
  await ensureDeliveryProfile(req.user);
  const closeConnection = initializeSse(res);
  pushSse(res, { type: 'ready', scope: 'delivery-dashboard' });

  const userId = req.user._id.toString();
  const stopWatching = watchChangeStreams([
    {
      model: OrderModel,
      onChange: (change) => {
        const order = change.fullDocument;
        if (
          order?.deliveryPartnerId?.toString() === userId ||
          (['ACCEPTED', 'PREPARING'].includes(order?.status) &&
            !order?.deliveryPartnerId)
        ) {
          pushSse(res, { type: 'refresh', scope: 'delivery-dashboard' });
        }
      },
    },
    {
      model: UserModel,
      onChange: (change) => {
        const user = change.fullDocument;
        if (user?._id?.toString() === userId) {
          pushSse(res, { type: 'refresh', scope: 'delivery-dashboard' });
        }
      },
    },
  ]);

  req.on('close', async () => {
    await stopWatching();
    closeConnection();
  });
});

async function ensureDeliveryProfile(user) {
  if (!user.deliveryProfile) {
    user.deliveryProfile = {
      isOnline: false,
      currentZone: 'Central Zone',
      vehicleLabel: 'Bike',
      lastSeenAt: new Date(),
    };
    await user.save();
  }
}

function calculateDeliveryEarning(orderTotal) {
  return 35 + Math.round(orderTotal * 0.08);
}

function buildEarnings(transactions) {
  const now = Date.now();
  const credits = transactions.filter(
    (entry) => entry.type === 'CREDIT' && entry.category === 'DELIVERY_EARNING',
  );

  return {
    today: sumTransactionsSince(credits, now - 24 * 60 * 60 * 1000),
    weekly: sumTransactionsSince(credits, now - 7 * 24 * 60 * 60 * 1000),
    monthly: sumTransactionsSince(credits, now - 30 * 24 * 60 * 60 * 1000),
    lifetime: credits.reduce((sum, entry) => sum + (entry.amount || 0), 0),
    completedTrips: credits.length,
  };
}

function sumTransactionsSince(transactions, cutoff) {
  return transactions
    .filter((entry) => new Date(entry.createdAt).getTime() >= cutoff)
    .reduce((sum, entry) => sum + (entry.amount || 0), 0);
}

export { router as deliveryRoutes };
