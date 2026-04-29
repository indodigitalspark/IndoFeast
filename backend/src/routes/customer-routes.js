import express from 'express';

import { requireAuth, requireRoles } from '../middleware/auth-middleware.js';
import { getOrCreateAdminConfig } from '../services/admin-config-service.js';
import { CartModel } from '../models/cart-model.js';
import { CouponModel } from '../models/coupon-model.js';
import { OrderModel } from '../models/order-model.js';
import { RestaurantModel } from '../models/restaurant-model.js';
import { UserModel } from '../models/user-model.js';
import { cancelOrder } from '../services/order-lifecycle-service.js';
import {
  createProviderPayment,
  refundProviderPayment,
  verifyProviderPayment,
} from '../services/payment-provider-service.js';
import {
  initializeSse,
  pushSse,
  watchChangeStreams,
} from '../services/realtime-service.js';
import {
  serializeCart,
  serializeCoupon,
  serializeOrder,
  serializeRestaurant,
  serializeUser,
} from '../utils/serializers.js';

const router = express.Router();

router.use(requireAuth, requireRoles('CUSTOMER'));

router.get('/home', async (req, res) => {
  const {
    search = '',
    category,
    rating,
    deliveryTime,
    price,
  } = req.query;

  const filters = {};
  if (category && category !== 'All') {
    filters.category = category;
  }

  let restaurants = await RestaurantModel.find(filters).sort({ rating: -1, createdAt: -1 });
  const config = await getOrCreateAdminConfig();
  restaurants = restaurants.filter((restaurant) => {
    if (restaurant.storeStatus === 'CLOSED') {
      return false;
    }

    const matchesSearch =
      !search ||
      restaurant.name.toLowerCase().includes(String(search).toLowerCase()) ||
      restaurant.cuisine.some((item) =>
        item.toLowerCase().includes(String(search).toLowerCase()),
      );

    const matchesRating = !rating || restaurant.rating >= Number(rating);
    const matchesDelivery = !deliveryTime || restaurant.deliveryTime <= Number(deliveryTime);
    const matchesPrice =
      !price || restaurant.priceLevel.toLowerCase().includes(String(price).toLowerCase());

    return matchesSearch && matchesRating && matchesDelivery && matchesPrice;
  });

  const coupons = await CouponModel.find({ isActive: true }).sort({ createdAt: -1 });
  const categories = [
    'All',
    ...new Set([
      ...config.managedCategories
        .filter((item) => item.isActive)
        .map((item) => item.name),
      ...restaurants.map((restaurant) => restaurant.category),
    ]),
  ];

  return res.json({
    banners: config.marketingBanners
      .filter((banner) => banner.isActive)
      .map((banner) => ({
        id: banner.id,
        title: banner.title,
        subtitle: banner.subtitle,
      })),
    categories,
    coupons: coupons.map(serializeCoupon),
    restaurants: restaurants.map(serializeRestaurant),
  });
});

router.get('/cart', async (req, res) => {
  const cart = await getOrCreateCart(req.user._id);
  return res.json({ cart: serializeCart(cart) });
});

router.post('/cart/items', async (req, res) => {
  const { restaurantId, menuItemId, replaceCart = false } = req.body;
  if (!restaurantId || !menuItemId) {
    return res.status(400).json({
      message: 'Restaurant and menu item identifiers are required.',
    });
  }

  const restaurant = await RestaurantModel.findById(restaurantId);
  if (!restaurant) {
    return res.status(404).json({ message: 'Restaurant not found.' });
  }
  if (restaurant.storeStatus === 'CLOSED') {
    return res.status(400).json({
      message: 'This store is currently closed. Please check back later.',
    });
  }

  const resolvedMenuItem = findRestaurantMenuItem(restaurant, menuItemId);
  if (!resolvedMenuItem) {
    return res.status(404).json({ message: 'Menu item not found.' });
  }
  if (!resolvedMenuItem.item.isAvailable || resolvedMenuItem.item.stock <= 0) {
    return res.status(400).json({ message: 'This item is currently out of stock.' });
  }

  const cart = await getOrCreateCart(req.user._id);
  if (
    cart.items.length > 0 &&
    cart.items[0].restaurantId.toString() !== restaurantId
  ) {
    if (replaceCart) {
      cart.items = [];
      cart.couponCode = undefined;
      cart.discount = 0;
    } else {
      return res.status(400).json({
        message:
          'Your cart already contains items from another restaurant. Remove them before adding from a new one.',
      });
    }
  }
  const existing = cart.items.find(
    (item) =>
      item.restaurantId.toString() === restaurantId &&
      item.menuItemId === resolvedMenuItem.id,
  );

  if (existing) {
    existing.quantity += 1;
  } else {
    cart.items.push({
      restaurantId: restaurant._id,
      restaurantName: restaurant.name,
      menuItemId: resolvedMenuItem.id,
      name: resolvedMenuItem.item.name,
      price: resolvedMenuItem.item.price,
      quantity: 1,
    });
  }

  await cart.save();
  return res.json({ message: 'Item added to cart.', cart: serializeCart(cart) });
});

router.patch('/cart/items', async (req, res) => {
  const { restaurantId, menuItemId, action } = req.body;
  const cart = await getOrCreateCart(req.user._id);
  const item = cart.items.find(
    (entry) => entry.restaurantId.toString() === restaurantId && entry.menuItemId === menuItemId,
  );

  if (!item) {
    return res.status(404).json({ message: 'Cart item not found.' });
  }

  if (action === 'decrement') {
    item.quantity -= 1;
  } else if (action === 'remove') {
    item.quantity = 0;
  } else {
    return res.status(400).json({ message: 'Unsupported cart action.' });
  }

  cart.items = cart.items.filter((entry) => entry.quantity > 0);
  if (cart.items.length === 0) {
    cart.couponCode = undefined;
    cart.discount = 0;
  }

  await cart.save();
  return res.json({ message: 'Cart updated.', cart: serializeCart(cart) });
});

router.patch('/cart/coupon', async (req, res) => {
  const { code } = req.body;
  const cart = await getOrCreateCart(req.user._id);

  if (!code) {
    cart.couponCode = undefined;
    cart.discount = 0;
    await cart.save();
    return res.json({ message: 'Coupon removed.', cart: serializeCart(cart) });
  }

  const coupon = await CouponModel.findOne({ code: String(code).toUpperCase(), isActive: true });
  if (!coupon) {
    return res.status(404).json({ message: 'Coupon not found.' });
  }

  const subtotal = cart.items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  if (subtotal < coupon.minOrderValue) {
    return res.status(400).json({
      message: `Coupon requires a minimum order of Rs ${coupon.minOrderValue}.`,
    });
  }

  cart.couponCode = coupon.code;
  cart.discount =
    coupon.discountType === 'FIXED'
      ? coupon.discountValue
      : Math.round((subtotal * coupon.discountValue) / 100);
  await cart.save();

  return res.json({ message: `${coupon.code} applied.`, cart: serializeCart(cart) });
});

router.patch('/cart/mode', async (req, res) => {
  const { orderMode } = req.body;
  const cart = await getOrCreateCart(req.user._id);
  cart.orderMode = orderMode;
  await cart.save();
  return res.json({ message: 'Order mode updated.', cart: serializeCart(cart) });
});

router.patch('/cart/payment', async (req, res) => {
  const { paymentMethod } = req.body;
  const allowed = new Set(['COD', 'WALLET', 'RAZORPAY', 'CASHFREE', 'STRIPE']);
  if (!allowed.has(String(paymentMethod || '').toUpperCase())) {
    return res.status(400).json({ message: 'Unsupported payment method.' });
  }

  const cart = await getOrCreateCart(req.user._id);
  cart.paymentMethod = String(paymentMethod).toUpperCase();
  await cart.save();
  return res.json({ message: 'Payment method updated.', cart: serializeCart(cart) });
});

router.post('/orders', async (req, res) => {
  const cart = await getOrCreateCart(req.user._id);
  if (cart.items.length === 0) {
    return res.status(400).json({ message: 'Your cart is empty.' });
  }

  const subtotal = cart.items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const total = Math.max(subtotal - cart.discount, 0);
  const paymentMethod = String(req.body.paymentMethod || cart.paymentMethod || 'COD').toUpperCase();
  const restaurantId = cart.items[0].restaurantId;
  const restaurant = await RestaurantModel.findById(restaurantId);
  if (!restaurant) {
    return res.status(404).json({ message: 'Restaurant not found.' });
  }
  if (restaurant.storeStatus === 'CLOSED') {
    return res.status(400).json({
      message: 'This store is currently closed. Please check back later.',
    });
  }

  for (const cartItem of cart.items) {
    const resolvedMenuItem = findRestaurantMenuItem(restaurant, cartItem.menuItemId);
    const menuItem = resolvedMenuItem?.item;
    if (!menuItem || !menuItem.isAvailable || menuItem.stock < cartItem.quantity) {
      return res.status(400).json({
        message: `Insufficient stock for ${cartItem.name}. Please update your cart.`,
      });
    }
  }

  const order = await OrderModel.create({
    userId: req.user._id,
    restaurantId: restaurant._id,
    restaurantName: restaurant.name,
    items: cart.items.map((item) => ({
      menuItemId: item.menuItemId,
      name: item.name,
      price: item.price,
      quantity: item.quantity,
    })),
    paymentMethod,
    orderMode: cart.orderMode,
    couponCode: cart.couponCode,
    discount: cart.discount,
    subtotal,
    total,
    customerName: req.user.displayName,
    customerPhoneNumber: req.user.phoneNumber,
    pickupAddress: `${restaurant.name}, Partner Pickup Counter`,
    pickupLatitude: 28.6139 + createCoordinateOffset(restaurant._id.toString(), 0),
    pickupLongitude: 77.2090 + createCoordinateOffset(restaurant._id.toString(), 1),
    deliveryAddress: buildCustomerAddress(req.user),
    deliveryLatitude: 28.6225 + createCoordinateOffset(req.user._id.toString(), 2),
    deliveryLongitude: 77.2187 + createCoordinateOffset(req.user._id.toString(), 3),
    deliveryOtp: await generateUniqueDeliveryOtp(),
    status: 'PLACED',
    paymentStatus: paymentMethod === 'COD' ? 'PENDING_COD_COLLECTION' : 'PENDING',
  });

  let checkout = null;
  if (paymentMethod === 'WALLET') {
    if ((req.user.walletBalance || 0) < total) {
      return res.status(400).json({ message: 'Insufficient wallet balance.' });
    }
    req.user.walletBalance -= total;
    req.user.walletTransactions.push({
      amount: total,
      type: 'DEBIT',
      category: 'ORDER_PAYMENT',
      description: `Wallet payment for order ${order._id.toString().slice(-6).toUpperCase()}`,
      orderId: order._id,
      createdAt: new Date(),
    });
    await req.user.save();
    order.paymentStatus = 'PAID';
    order.paymentVerifiedAt = new Date();
    order.paymentReferenceId = `wallet_${order._id.toString()}`;
    await order.save();
  } else if (paymentMethod !== 'COD') {
    const provider = await createProviderPayment({ order, user: req.user });
    order.paymentProviderOrderId = provider.providerOrderId;
    order.paymentSessionId = provider.sessionId;
    order.paymentClientSecret = provider.clientSecret;
    order.paymentStatus = provider.paymentStatus;
    order.paymentVerifiedAt = provider.verifiedAt || undefined;
    await order.save();
    checkout = provider.sessionPayload;
  }

  for (const cartItem of cart.items) {
    const menuItem = findRestaurantMenuItem(restaurant, cartItem.menuItemId)?.item;
    if (menuItem) {
      menuItem.stock -= cartItem.quantity;
      menuItem.isAvailable = menuItem.stock > 0;
    }
  }
  await restaurant.save();

  cart.items = [];
  cart.couponCode = undefined;
  cart.discount = 0;
  await cart.save();

  return res.status(201).json({
    message: 'Order placed successfully.',
    order: serializeOrder(order),
    cart: serializeCart(cart),
    checkout,
  });
});

router.post('/orders/:id/cancel', async (req, res) => {
  const order = await OrderModel.findOne({ _id: req.params.id, userId: req.user._id });
  if (!order) {
    return res.status(404).json({ message: 'Order not found.' });
  }

  if (!['PLACED', 'ACCEPTED', 'PREPARING'].includes(order.status)) {
    return res.status(400).json({ message: 'This order can no longer be cancelled.' });
  }

  const restaurant = await RestaurantModel.findById(order.restaurantId);
  if (!restaurant) {
    return res.status(404).json({ message: 'Restaurant not found.' });
  }

  if (['PAID', 'PARTIALLY_REFUNDED'].includes(order.paymentStatus)) {
    const refund = await refundProviderPayment({
      order,
      amount: Math.max(order.total - (order.refundedAmount || 0), 0),
      reason: 'Customer cancelled order before dispatch.',
    });
    const remaining = Math.max(order.total - (order.refundedAmount || 0), 0);
    order.refundedAmount += remaining;
    order.paymentStatus = 'REFUNDED';
    order.refunds.push({
      refundId: `refund_${Date.now()}`,
      providerRefundId: refund.refundId,
      amount: remaining,
      status: refund.status,
      reason: 'Customer cancelled order before dispatch.',
      createdAt: new Date(),
    });

    if (order.paymentMethod === 'WALLET') {
      req.user.walletBalance += remaining;
      req.user.walletTransactions.push({
        amount: remaining,
        type: 'CREDIT',
        category: 'ORDER_REFUND',
        description: `Refund for order ${order._id.toString().slice(-6).toUpperCase()}`,
        orderId: order._id,
        createdAt: new Date(),
      });
      await req.user.save();
    }
  }

  await cancelOrder({
    order,
    restaurant,
    reason: 'Cancelled by customer before dispatch.',
  });

  return res.json({
    message: 'Order cancelled.',
    order: serializeOrder(order),
  });
});

router.post('/orders/:id/payment/verify', async (req, res) => {
  const order = await OrderModel.findOne({ _id: req.params.id, userId: req.user._id });
  if (!order) {
    return res.status(404).json({ message: 'Order not found.' });
  }

  if (['PAID', 'REFUNDED', 'PARTIALLY_REFUNDED'].includes(order.paymentStatus)) {
    return res.json({ message: 'Payment already verified.', order: serializeOrder(order) });
  }

  const verification = await verifyProviderPayment({ order, payload: req.body });
  order.paymentStatus = verification.status;
  order.paymentReferenceId = verification.referenceId || order.paymentReferenceId;
  order.paymentVerifiedAt = verification.verifiedAt || new Date();
  await order.save();

  return res.json({
    message: 'Payment verified.',
    order: serializeOrder(order),
  });
});

router.get('/orders/active', async (req, res) => {
  const orders = await OrderModel.find({ userId: req.user._id }).sort({ createdAt: -1 });
  return res.json({
    orders: orders
      .filter((order) => !['DELIVERED', 'CANCELLED'].includes(order.status))
      .map(serializeOrder),
  });
});

router.get('/orders/history', async (req, res) => {
  const orders = await OrderModel.find({ userId: req.user._id }).sort({ createdAt: -1 });
  return res.json({ orders: orders.map(serializeOrder) });
});

router.post('/orders/:id/review', async (req, res) => {
  const { rating, comment } = req.body;
  const order = await OrderModel.findOne({ _id: req.params.id, userId: req.user._id });
  if (!order) {
    return res.status(404).json({ message: 'Order not found.' });
  }

  if (order.status !== 'DELIVERED') {
    return res.status(400).json({ message: 'Only completed orders can be reviewed.' });
  }

  order.review = {
    rating: Number(rating),
    comment: String(comment || ''),
    createdAt: new Date(),
  };
  await order.save();

  await RestaurantModel.findByIdAndUpdate(order.restaurantId, {
    $push: {
      reviews: {
        orderId: order._id,
        userId: req.user._id,
        userName: req.user.displayName,
        rating: Number(rating),
        review: String(comment || ''),
        createdAt: new Date(),
      },
    },
  });

  return res.json({ message: 'Review submitted.', order: serializeOrder(order) });
});

router.get('/orders/stream', async (req, res) => {
  const closeConnection = initializeSse(res);
  pushSse(res, { type: 'ready', scope: 'customer-orders' });

  const userId = req.user._id.toString();
  const stopWatching = watchChangeStreams([
    {
      model: OrderModel,
      onChange: (change) => {
        const order = change.fullDocument;
        if (order?.userId?.toString() === userId) {
          pushSse(res, { type: 'refresh', scope: 'customer-orders' });
        }
      },
    },
    {
      model: UserModel,
      onChange: (change) => {
        const user = change.fullDocument;
        if (user?._id?.toString() === userId) {
          pushSse(res, { type: 'refresh', scope: 'customer-orders' });
        }
      },
    },
  ]);

  req.on('close', async () => {
    await stopWatching();
    closeConnection();
  });
});

router.get('/wallet', async (req, res) => {
  const user = await UserModel.findById(req.user._id);
  return res.json({
    walletBalance: user.walletBalance || 0,
    transactions: (user.walletTransactions || []).slice().reverse(),
  });
});

router.post('/wallet/add-funds', async (req, res) => {
  const amount = Number(req.body.amount || 0);
  if (amount <= 0) {
    return res.status(400).json({ message: 'Amount must be greater than zero.' });
  }

  req.user.walletBalance += amount;
  req.user.walletTransactions.push({
    amount,
    type: 'CREDIT',
    category: 'WALLET_TOP_UP',
    description: 'Wallet top-up',
    createdAt: new Date(),
  });
  await req.user.save();

  return res.json({
    message: 'Funds added to wallet.',
    user: serializeUser(req.user),
  });
});

function findRestaurantMenuItem(restaurant, menuItemId) {
  for (const [index, item] of (restaurant.menuItems || []).entries()) {
    const resolvedId = resolveMenuItemId(item, index);
    if (resolvedId === String(menuItemId)) {
      return { item, index, id: resolvedId };
    }
  }

  return null;
}

function resolveMenuItemId(item, index) {
  if (item?.itemId && String(item.itemId).trim()) {
    return String(item.itemId).trim();
  }

  if (item?._id) {
    return item._id.toString();
  }

  const slug = String(item?.name || `menu-item-${index + 1}`)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

  return `legacy-${index + 1}-${slug || 'item'}`;
}

async function getOrCreateCart(userId) {
  let cart = await CartModel.findOne({ userId });
  if (!cart) {
    cart = await CartModel.create({ userId });
  }
  return cart;
}

async function generateUniqueDeliveryOtp() {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const otp = String(Math.floor(1000 + Math.random() * 9000));
    const existing = await OrderModel.exists({
      deliveryOtp: otp,
      status: { $nin: ['DELIVERED', 'CANCELLED'] },
    });

    if (!existing) {
      return otp;
    }
  }

  return String(Math.floor(1000 + Math.random() * 9000));
}

function buildCustomerAddress(user) {
  const initials = String(user.displayName || 'Customer')
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0]?.toUpperCase() || '')
    .join('')
    .slice(0, 3);
  return `House ${initials || 'CF'}-12, Green Residency`;
}

function createCoordinateOffset(seed, index) {
  const source = `${seed}:${index}`;
  let total = 0;
  for (let position = 0; position < source.length; position += 1) {
    total += source.charCodeAt(position) * (position + 1);
  }

  return ((total % 900) - 450) / 10000;
}

export { router as customerRoutes };
