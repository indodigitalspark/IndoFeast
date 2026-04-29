import { resolveMenuItemId } from './menu-item-ids.js';

export function serializeUser(user) {
  return {
    id: user._id.toString(),
    email: user.email,
    displayName: user.displayName,
    phoneNumber: user.phoneNumber,
    businessName: user.businessName || null,
    role: user.role,
    customRoleKey: user.customRoleKey || null,
    customRoleName: user.customRoleName || null,
    permissions: user.permissions || [],
    status: user.status,
    walletBalance: user.walletBalance ?? 0,
    walletTransactions: (user.walletTransactions || []).map((transaction) => ({
      amount: transaction.amount,
      type: transaction.type,
      description: transaction.description,
      category: transaction.category || 'ADJUSTMENT',
      orderId: transaction.orderId?.toString() || null,
      createdAt: transaction.createdAt?.toISOString(),
    })),
    deliveryProfile: user.deliveryProfile
        ? {
            isOnline: user.deliveryProfile.isOnline ?? false,
            currentZone: user.deliveryProfile.currentZone || 'Central Zone',
            vehicleLabel: user.deliveryProfile.vehicleLabel || 'Bike',
            lastSeenAt: user.deliveryProfile.lastSeenAt?.toISOString() || null,
          }
        : null,
    createdAt: user.createdAt?.toISOString(),
    documentUrl: user.document?.path || null,
    documentName: user.document?.originalName || null,
    rejectionReason: user.rejectionReason || null,
  };
}

export function serializeNotification(notification) {
  return {
    id: notification._id.toString(),
    title: notification.title,
    body: notification.body,
    createdAt: notification.createdAt?.toISOString(),
    targetRoles: notification.targetRoles,
    isRead: notification.isRead,
    relatedUserId: notification.relatedUserId?.toString() || null,
  };
}

export function serializeRestaurant(restaurant) {
  return {
    id: restaurant._id.toString(),
    ownerId: restaurant.ownerId?.toString() || null,
    name: restaurant.name,
    cuisine: restaurant.cuisine,
    category: restaurant.category,
    rating: restaurant.rating,
    deliveryTime: restaurant.deliveryTime,
    priceLevel: restaurant.priceLevel,
    offerText: restaurant.offerText,
    description: restaurant.description,
    accentColor: restaurant.accentColor,
    heroTag: restaurant.heroTag,
    storeStatus: restaurant.storeStatus || 'OPEN',
    commissionRate: restaurant.commissionRate ?? 0.18,
    pendingSettlementAmount: restaurant.pendingSettlementAmount ?? 0,
    lifetimeSettlementAmount: restaurant.lifetimeSettlementAmount ?? 0,
    settlementHistory: (restaurant.settlementHistory || []).map((entry) => ({
      orderId: entry.orderId?.toString() || null,
      grossAmount: entry.grossAmount ?? 0,
      commissionAmount: entry.commissionAmount ?? 0,
      netAmount: entry.netAmount ?? 0,
      status: entry.status ?? 'PENDING',
      createdAt: entry.createdAt?.toISOString(),
    })),
    menuItems: (restaurant.menuItems || []).map((item, index) => ({
      itemId: resolveMenuItemId(item, index),
      name: item.name,
      description: item.description,
      category: item.category,
      price: item.price,
      stock: item.stock ?? 0,
      imagePath: item.imagePath || null,
      isAvailable: item.isAvailable ?? true,
      isVeg: item.isVeg,
      bestseller: item.bestseller,
      discountPercent: item.discountPercent ?? 0,
      preparationTimeMin: item.preparationTimeMin ?? 20,
      preparationTimeMax: item.preparationTimeMax ?? 25,
      addOns: item.addOns || [],
      customizationOptions: item.customizationOptions || [],
    })),
    reviews: (restaurant.reviews || []).map((review) => ({
      orderId: review.orderId?.toString(),
      userId: review.userId?.toString(),
      userName: review.userName,
      rating: review.rating,
      review: review.review,
      createdAt: review.createdAt?.toISOString(),
    })),
  };
}

export function serializeCoupon(coupon) {
  return {
    id: coupon._id.toString(),
    code: coupon.code,
    title: coupon.title,
    description: coupon.description,
    discountType: coupon.discountType,
    discountValue: coupon.discountValue,
    minOrderValue: coupon.minOrderValue,
  };
}

export function serializeCart(cart) {
  const items = cart?.items || [];
  const subtotal = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const discount = cart?.discount || 0;
  const storeMap = new Map();

  for (const item of items) {
    const key = item.restaurantId.toString();
    const store = storeMap.get(key) || {
      storeId: key,
      storeName: item.restaurantName,
      itemCount: 0,
      subtotal: 0,
      items: [],
    };

    store.itemCount += item.quantity;
    store.subtotal += item.price * item.quantity;
    store.items.push({
      restaurantId: key,
      restaurantName: item.restaurantName,
      menuItemId: item.menuItemId,
      name: item.name,
      price: item.price,
      quantity: item.quantity,
    });
    storeMap.set(key, store);
  }

  const storeGroups = [...storeMap.values()].map((store) => {
    const deliveryFee = cart?.orderMode === 'DELIVERY' ? 40 : 0;
    const tax = Math.round(store.subtotal * 0.05);
    return {
      ...store,
      deliveryFee,
      tax,
      total: store.subtotal + deliveryFee + tax,
    };
  });
  const deliveryFee = storeGroups.reduce((sum, store) => sum + store.deliveryFee, 0);
  const tax = storeGroups.reduce((sum, store) => sum + store.tax, 0);
  const grandTotal = Math.max(subtotal + deliveryFee + tax - discount, 0);

  return {
    items: items.map((item) => ({
      restaurantId: item.restaurantId.toString(),
      restaurantName: item.restaurantName,
      menuItemId: item.menuItemId,
      name: item.name,
      price: item.price,
      quantity: item.quantity,
    })),
    couponCode: cart?.couponCode || null,
    discount,
    storeGroups,
    orderMode: cart?.orderMode || 'DELIVERY',
    paymentMethod: cart?.paymentMethod || 'COD',
    subtotal,
    deliveryFee,
    tax,
    total: grandTotal,
    grandTotal,
    grandItemCount: items.reduce((sum, item) => sum + item.quantity, 0),
    splitOrderMessage:
      storeGroups.length > 1
        ? 'Items will be placed as separate store orders after one combined checkout.'
        : 'Your order will be placed with the selected store after checkout.',
  };
}

export function serializeOrder(order) {
  const tracking = buildTrackingSnapshot(order);

  return {
    id: order._id.toString(),
    restaurantId: order.restaurantId.toString(),
    restaurantName: order.restaurantName,
    items: (order.items || []).map((item) => ({
      menuItemId: item.menuItemId,
      name: item.name,
      price: item.price,
      quantity: item.quantity,
    })),
    orderMode: order.orderMode,
    paymentMethod: order.paymentMethod || 'COD',
    paymentStatus: order.paymentStatus || 'PENDING',
    paymentProviderOrderId: order.paymentProviderOrderId || null,
    paymentReferenceId: order.paymentReferenceId || null,
    paymentClientSecret: order.paymentClientSecret || null,
    paymentSessionId: order.paymentSessionId || null,
    paymentVerifiedAt: order.paymentVerifiedAt?.toISOString() || null,
    checkoutSessionId: order.checkoutSessionId?.toString() || null,
    orderGroupId: order.orderGroupId || null,
    splitSequence: order.splitSequence ?? 1,
    refundedAmount: order.refundedAmount ?? 0,
    couponCode: order.couponCode || null,
    discount: order.discount,
    subtotal: order.subtotal,
    deliveryFee: order.deliveryFee ?? 0,
    tax: order.tax ?? 0,
    total: order.total,
    status: order.status,
    customerName: order.customerName || 'Customer',
    customerPhoneNumber: order.customerPhoneNumber || '',
    pickupAddress: order.pickupAddress || '',
    pickupLatitude: order.pickupLatitude ?? null,
    pickupLongitude: order.pickupLongitude ?? null,
    deliveryAddress: order.deliveryAddress || '',
    deliveryLatitude: order.deliveryLatitude ?? null,
    deliveryLongitude: order.deliveryLongitude ?? null,
    deliveryOtp: order.deliveryOtp || null,
    deliveryPartnerId: order.deliveryPartnerId?.toString() || null,
    deliveryPartnerName: order.deliveryPartnerName || null,
    deliveryPartnerLatitude: order.deliveryPartnerLatitude ?? null,
    deliveryPartnerLongitude: order.deliveryPartnerLongitude ?? null,
    locationUpdatedAt: order.locationUpdatedAt?.toISOString() || null,
    deliveryAcceptedAt: order.deliveryAcceptedAt?.toISOString() || null,
    assignedAt: order.assignedAt?.toISOString() || null,
    pickupConfirmedAt: order.pickupConfirmedAt?.toISOString() || null,
    deliveredAt: order.deliveredAt?.toISOString() || null,
    cancelledAt: order.cancelledAt?.toISOString() || null,
    cancellationReason: order.cancellationReason || null,
    commissionAmount: order.commissionAmount ?? 0,
    vendorSettlementAmount: order.vendorSettlementAmount ?? 0,
    deliveryPartnerPayoutAmount: order.deliveryPartnerPayoutAmount ?? 0,
    settlementStatus: order.settlementStatus || 'PENDING',
    refunds: (order.refunds || []).map((refund) => ({
      refundId: refund.refundId || null,
      providerRefundId: refund.providerRefundId || null,
      amount: refund.amount ?? 0,
      status: refund.status || 'SUCCESS',
      reason: refund.reason || null,
      createdAt: refund.createdAt?.toISOString() || null,
    })),
    review: order.review?.rating
        ? {
            rating: order.review.rating,
            comment: order.review.comment,
            createdAt: order.review.createdAt?.toISOString(),
          }
        : null,
    tracking,
    createdAt: order.createdAt?.toISOString(),
    updatedAt: order.updatedAt?.toISOString(),
  };
}

export function serializeCheckoutSession(checkoutSession) {
  return {
    id: checkoutSession._id.toString(),
    orderGroupId: checkoutSession.orderGroupId,
    orderMode: checkoutSession.orderMode,
    paymentMethod: checkoutSession.paymentMethod,
    status: checkoutSession.status,
    paymentStatus: checkoutSession.paymentStatus,
    paymentProviderOrderId: checkoutSession.paymentProviderOrderId || null,
    paymentReferenceId: checkoutSession.paymentReferenceId || null,
    paymentSessionId: checkoutSession.paymentSessionId || null,
    subtotal: checkoutSession.subtotal ?? 0,
    discount: checkoutSession.discount ?? 0,
    deliveryFee: checkoutSession.deliveryFee ?? 0,
    tax: checkoutSession.tax ?? 0,
    grandTotal: checkoutSession.total ?? 0,
    stores: (checkoutSession.stores || []).map((store) => ({
      storeId: store.restaurantId?.toString() || '',
      storeName: store.restaurantName,
      itemCount: store.itemCount ?? 0,
      subtotal: store.subtotal ?? 0,
      deliveryFee: store.deliveryFee ?? 0,
      tax: store.tax ?? 0,
      discount: store.discount ?? 0,
      total: store.total ?? 0,
      items: (store.items || []).map((item) => ({
        menuItemId: item.menuItemId,
        name: item.name,
        price: item.price,
        quantity: item.quantity,
      })),
    })),
    createdOrderIds: (checkoutSession.createdOrderIds || []).map((id) => id.toString()),
  };
}

function buildTrackingSnapshot(order) {
  const startLatitude = order.status === 'OUT_FOR_DELIVERY'
    ? order.deliveryPartnerLatitude ?? order.pickupLatitude
    : order.pickupLatitude;
  const startLongitude = order.status === 'OUT_FOR_DELIVERY'
    ? order.deliveryPartnerLongitude ?? order.pickupLongitude
    : order.pickupLongitude;
  const endLatitude = order.deliveryLatitude;
  const endLongitude = order.deliveryLongitude;
  const distanceKm = roughDistanceKm(
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
  );
  const trafficLabel = distanceKm > 7 ? 'Heavy' : distanceKm > 4 ? 'Moderate' : 'Light';
  const trafficFactor = trafficLabel === 'Heavy' ? 1.5 : trafficLabel === 'Moderate' ? 1.25 : 1.0;
  const baseEtaMinutes = distanceKm <= 0
    ? order.status === 'DELIVERED'
      ? 0
      : 8
    : Math.max(Math.round(distanceKm * 3 * trafficFactor), 6);
  const delayReason = inferDelayReason(order, baseEtaMinutes);

  return {
    distanceKm,
    etaMinutes: order.status === 'DELIVERED' ? 0 : baseEtaMinutes,
    trafficLabel,
    delayReason,
    canTrackLive: order.status === 'OUT_FOR_DELIVERY',
    routeStage:
      order.status === 'OUT_FOR_DELIVERY'
        ? 'DELIVERY_PARTNER_TO_CUSTOMER'
        : 'STORE_TO_CUSTOMER',
  };
}

function roughDistanceKm(latA, lonA, latB, lonB) {
  if (
    latA == null ||
    lonA == null ||
    latB == null ||
    lonB == null
  ) {
    return 0;
  }

  const rough = ((Math.abs(latA - latB) + Math.abs(lonA - lonB)) * 55);
  return Number(rough.toFixed(1));
}

function inferDelayReason(order, etaMinutes) {
  if (order.status === 'DELIVERED' || order.status === 'CANCELLED') {
    return null;
  }

  const ageMinutes = Math.max(
    Math.round((Date.now() - new Date(order.createdAt).getTime()) / 60000),
    0,
  );
  if (ageMinutes <= etaMinutes + 8) {
    return null;
  }

  if (order.status === 'PLACED' || order.status === 'ACCEPTED') {
    return 'Restaurant preparing delay';
  }
  if (order.status === 'PREPARING') {
    return 'Restaurant preparing delay';
  }
  if (order.status === 'OUT_FOR_DELIVERY') {
    return 'Heavy traffic';
  }

  return 'Delivery partner delay';
}
