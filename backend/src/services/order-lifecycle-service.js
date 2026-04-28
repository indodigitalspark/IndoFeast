export async function cancelOrder({
  order,
  restaurant,
  reason = 'Order cancelled.',
}) {
  if (['DELIVERED', 'CANCELLED'].includes(order.status)) {
    return;
  }

  await restoreStock(restaurant, order);
  order.status = 'CANCELLED';
  order.cancelledAt = new Date();
  order.cancellationReason = reason;
  order.deliveryPartnerId = undefined;
  order.deliveryPartnerName = undefined;
  order.deliveryAcceptedAt = undefined;
  order.assignedAt = undefined;
  order.pickupConfirmedAt = undefined;

  if (order.settlementStatus === 'PENDING' && order.vendorSettlementAmount > 0) {
    restaurant.pendingSettlementAmount = Math.max(
      (restaurant.pendingSettlementAmount || 0) - order.vendorSettlementAmount,
      0,
    );
    order.settlementStatus = 'REVERSED';
  }

  await restaurant.save();
  await order.save();
}

export async function markOrderDelivered({ order, restaurant }) {
  if (order.status === 'DELIVERED') {
    return;
  }

  const grossAmount = order.total || 0;
  const commissionAmount = Math.round(grossAmount * (restaurant.commissionRate || 0));
  const vendorSettlementAmount = Math.max(grossAmount - commissionAmount, 0);
  const deliveryPartnerPayoutAmount = 35 + Math.round(grossAmount * 0.08);

  order.status = 'DELIVERED';
  order.deliveredAt = new Date();
  order.commissionAmount = commissionAmount;
  order.vendorSettlementAmount = vendorSettlementAmount;
  order.deliveryPartnerPayoutAmount = deliveryPartnerPayoutAmount;
  order.settlementStatus = 'PENDING';
  if (order.paymentMethod === 'COD') {
    order.paymentStatus = 'PAID';
    order.paymentVerifiedAt = new Date();
  }

  restaurant.pendingSettlementAmount =
    (restaurant.pendingSettlementAmount || 0) + vendorSettlementAmount;
  restaurant.lifetimeSettlementAmount =
    (restaurant.lifetimeSettlementAmount || 0) + vendorSettlementAmount;
  restaurant.settlementHistory.push({
    orderId: order._id,
    grossAmount,
    commissionAmount,
    netAmount: vendorSettlementAmount,
    status: 'PENDING',
    createdAt: new Date(),
  });

  await restaurant.save();
  await order.save();
}

export async function restoreStock(restaurant, order) {
  for (const orderedItem of order.items) {
    const menuItem = restaurant.menuItems.find(
      (entry) => entry.itemId === orderedItem.menuItemId,
    );
    if (menuItem) {
      menuItem.stock += orderedItem.quantity;
      menuItem.isAvailable = menuItem.stock > 0;
    }
  }
}
