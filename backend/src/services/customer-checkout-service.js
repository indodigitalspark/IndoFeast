import crypto from 'node:crypto';

import mongoose from 'mongoose';

import { AdminNotificationModel } from '../models/admin-notification-model.js';
import { CartModel } from '../models/cart-model.js';
import { OrderModel } from '../models/order-model.js';
import { RestaurantModel } from '../models/restaurant-model.js';
import { UserModel } from '../models/user-model.js';
import { findRestaurantMenuItem } from '../utils/menu-item-ids.js';

const DELIVERY_FEE = 40;
const TAX_RATE = 0.05;

export async function buildCheckoutBreakdown(cart) {
  if (!cart.items?.length) {
    throw new Error('Your cart is empty.');
  }

  const restaurantIds = [
    ...new Set(cart.items.map((item) => item.restaurantId.toString())),
  ];
  const restaurants = await RestaurantModel.find({ _id: { $in: restaurantIds } });
  const restaurantMap = new Map(
    restaurants.map((restaurant) => [restaurant._id.toString(), restaurant]),
  );

  const stores = [];
  for (const restaurantId of restaurantIds) {
    const restaurant = restaurantMap.get(restaurantId);
    if (!restaurant) {
      throw new Error('One or more stores in your cart are no longer available.');
    }
    if (restaurant.storeStatus === 'CLOSED') {
      throw new Error(`${restaurant.name} is currently closed. Please update your cart.`);
    }

    const storeItems = cart.items.filter(
      (item) => item.restaurantId.toString() === restaurantId,
    );

    for (const cartItem of storeItems) {
      const menuItem = findRestaurantMenuItem(restaurant, cartItem.menuItemId)?.item;
      if (!menuItem || !menuItem.isAvailable || menuItem.stock < cartItem.quantity) {
        throw new Error(
          `Insufficient stock for ${cartItem.name} at ${restaurant.name}. Please update your cart.`,
        );
      }
    }

    const subtotal = storeItems.reduce(
      (sum, item) => sum + item.price * item.quantity,
      0,
    );
    const deliveryFee = cart.orderMode === 'DELIVERY' ? DELIVERY_FEE : 0;
    const tax = Math.round(subtotal * TAX_RATE);

    stores.push({
      restaurantId: restaurant._id,
      restaurantName: restaurant.name,
      itemCount: storeItems.reduce((sum, item) => sum + item.quantity, 0),
      items: storeItems.map((item) => ({
        menuItemId: item.menuItemId,
        name: item.name,
        price: item.price,
        quantity: item.quantity,
      })),
      subtotal,
      deliveryFee,
      tax,
      discount: 0,
      total: subtotal + deliveryFee + tax,
    });
  }

  allocateDiscount(stores, cart.discount || 0);

  return {
    orderMode: cart.orderMode,
    paymentMethod: cart.paymentMethod,
    couponCode: cart.couponCode || undefined,
    discount: cart.discount || 0,
    subtotal: stores.reduce((sum, store) => sum + store.subtotal, 0),
    deliveryFee: stores.reduce((sum, store) => sum + store.deliveryFee, 0),
    tax: stores.reduce((sum, store) => sum + store.tax, 0),
    total: stores.reduce((sum, store) => sum + store.total, 0),
    stores,
  };
}

export async function finalizeCheckoutSession({
  checkoutSession,
  userId,
  paymentStatus,
  paymentReferenceId,
  paymentVerifiedAt,
}) {
  if (checkoutSession.status === 'FINALIZED' && checkoutSession.createdOrderIds.length > 0) {
    return OrderModel.find({ _id: { $in: checkoutSession.createdOrderIds } }).sort({ createdAt: 1 });
  }

  const mongoSession = await mongoose.startSession();
  try {
    let createdOrders = [];
    await mongoSession.withTransaction(async () => {
      const freshSession = await checkoutSession.constructor
        .findById(checkoutSession._id)
        .session(mongoSession);
      const user = await UserModel.findById(userId).session(mongoSession);
      const cart = await CartModel.findOne({ userId }).session(mongoSession);

      if (!freshSession) {
        throw new Error('Checkout session was not found.');
      }
      if (!user) {
        throw new Error('User was not found for checkout.');
      }
      if (!cart) {
        throw new Error('Cart was not found for checkout.');
      }
      if (freshSession.status === 'FINALIZED' && freshSession.createdOrderIds.length > 0) {
        createdOrders = await OrderModel.find({
          _id: { $in: freshSession.createdOrderIds },
        })
          .session(mongoSession)
          .sort({ createdAt: 1 });
        return;
      }

      if (freshSession.paymentMethod === 'WALLET') {
        if ((user.walletBalance || 0) < freshSession.total) {
          throw new Error('Insufficient wallet balance.');
        }

        user.walletBalance -= freshSession.total;
        user.walletTransactions.push({
          amount: freshSession.total,
          type: 'DEBIT',
          category: 'ORDER_PAYMENT',
          description: `Wallet payment for checkout ${freshSession.orderGroupId}`,
          createdAt: new Date(),
        });
        await user.save({ session: mongoSession });
      }

      const restaurantIds = freshSession.stores.map((store) => store.restaurantId.toString());
      const restaurants = await RestaurantModel.find({
        _id: { $in: restaurantIds },
      }).session(mongoSession);
      const restaurantMap = new Map(
        restaurants.map((restaurant) => [restaurant._id.toString(), restaurant]),
      );

      const orderDocs = [];
      for (const [index, store] of freshSession.stores.entries()) {
        const restaurant = restaurantMap.get(store.restaurantId.toString());
        if (!restaurant) {
          throw new Error(`${store.restaurantName} is no longer available.`);
        }
        if (restaurant.storeStatus === 'CLOSED') {
          throw new Error(`${store.restaurantName} is currently closed. Please try again later.`);
        }

        for (const item of store.items) {
          const menuItem = findRestaurantMenuItem(restaurant, item.menuItemId)?.item;
          if (!menuItem || !menuItem.isAvailable || menuItem.stock < item.quantity) {
            throw new Error(
              `Insufficient stock for ${item.name} at ${store.restaurantName}.`,
            );
          }
        }

        const order = await OrderModel.create(
          [
            {
              userId: user._id,
              restaurantId: restaurant._id,
              restaurantName: store.restaurantName,
              items: store.items,
              paymentMethod: freshSession.paymentMethod,
              paymentStatus,
              paymentProviderOrderId: freshSession.paymentProviderOrderId,
              paymentReferenceId,
              paymentClientSecret: freshSession.paymentClientSecret,
              paymentSessionId: freshSession.paymentSessionId,
              paymentVerifiedAt,
              checkoutSessionId: freshSession._id,
              orderGroupId: freshSession.orderGroupId,
              splitSequence: index + 1,
              orderMode: freshSession.orderMode,
              couponCode: freshSession.couponCode,
              discount: store.discount,
              subtotal: store.subtotal,
              deliveryFee: store.deliveryFee,
              tax: store.tax,
              total: store.total,
              customerName: user.displayName,
              customerPhoneNumber: user.phoneNumber,
              pickupAddress: `${restaurant.name}, Partner Pickup Counter`,
              pickupLatitude: 28.6139 + createCoordinateOffset(restaurant._id.toString(), 0),
              pickupLongitude: 77.2090 + createCoordinateOffset(restaurant._id.toString(), 1),
              deliveryAddress: buildCustomerAddress(user),
              deliveryLatitude: 28.6225 + createCoordinateOffset(user._id.toString(), 2),
              deliveryLongitude: 77.2187 + createCoordinateOffset(user._id.toString(), 3),
              deliveryOtp: await generateUniqueDeliveryOtp(),
              status: 'PLACED',
            },
          ],
          { session: mongoSession },
        );

        const createdOrder = order[0];
        orderDocs.push(createdOrder);

        for (const item of store.items) {
          const menuItem = findRestaurantMenuItem(restaurant, item.menuItemId)?.item;
          if (menuItem) {
            menuItem.stock -= item.quantity;
            menuItem.isAvailable = menuItem.stock > 0;
          }
        }
        await restaurant.save({ session: mongoSession });

        await AdminNotificationModel.create(
          [
            {
              title: 'New customer order',
              body: `${user.displayName} placed a new order for ${store.restaurantName}.`,
              targetRoles: ['SUPER_ADMIN', 'ADMIN', 'MANAGER'],
              relatedUserId: user._id,
            },
          ],
          { session: mongoSession },
        );
      }

      cart.items = [];
      cart.couponCode = undefined;
      cart.discount = 0;
      await cart.save({ session: mongoSession });

      freshSession.createdOrderIds = orderDocs.map((order) => order._id);
      freshSession.status = 'FINALIZED';
      freshSession.paymentStatus = paymentStatus;
      freshSession.paymentReferenceId = paymentReferenceId;
      freshSession.paymentVerifiedAt = paymentVerifiedAt;
      freshSession.failureReason = undefined;
      await freshSession.save({ session: mongoSession });

      createdOrders = orderDocs;
    });

    return createdOrders;
  } finally {
    await mongoSession.endSession();
  }
}

function allocateDiscount(stores, discount) {
  if (!discount || discount <= 0 || stores.length === 0) {
    return;
  }

  const totalSubtotal = stores.reduce((sum, store) => sum + store.subtotal, 0);
  if (totalSubtotal <= 0) {
    return;
  }

  let allocated = 0;
  for (const [index, store] of stores.entries()) {
    const remaining = discount - allocated;
    const proportional =
      index === stores.length - 1
        ? remaining
        : Math.min(remaining, Math.round((discount * store.subtotal) / totalSubtotal));
    store.discount = proportional;
    store.total = Math.max(store.subtotal + store.deliveryFee + store.tax - store.discount, 0);
    allocated += proportional;
  }
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

async function generateUniqueDeliveryOtp() {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const otp = String(1000 + crypto.randomInt(9000));
    const existing = await OrderModel.exists({
      deliveryOtp: otp,
      status: { $nin: ['DELIVERED', 'CANCELLED'] },
    });

    if (!existing) {
      return otp;
    }
  }

  return String(1000 + crypto.randomInt(9000));
}
