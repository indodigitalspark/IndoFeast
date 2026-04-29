import mongoose from 'mongoose';

const checkoutSessionItemSchema = new mongoose.Schema(
  {
    menuItemId: { type: String, required: true, trim: true },
    name: { type: String, required: true, trim: true },
    price: { type: Number, required: true },
    quantity: { type: Number, required: true, min: 1 },
  },
  { _id: false },
);

const checkoutSessionStoreSchema = new mongoose.Schema(
  {
    restaurantId: { type: mongoose.Schema.Types.ObjectId, ref: 'Restaurant', required: true },
    restaurantName: { type: String, required: true, trim: true },
    itemCount: { type: Number, default: 0 },
    items: { type: [checkoutSessionItemSchema], default: [] },
    subtotal: { type: Number, required: true, default: 0 },
    deliveryFee: { type: Number, required: true, default: 0 },
    tax: { type: Number, required: true, default: 0 },
    discount: { type: Number, required: true, default: 0 },
    total: { type: Number, required: true, default: 0 },
  },
  { _id: false },
);

const checkoutSessionSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    orderGroupId: { type: String, required: true, trim: true },
    orderMode: {
      type: String,
      enum: ['DELIVERY', 'PICKUP', 'DINE_IN'],
      required: true,
      default: 'DELIVERY',
    },
    paymentMethod: {
      type: String,
      enum: ['COD', 'WALLET', 'RAZORPAY', 'CASHFREE', 'STRIPE'],
      required: true,
      default: 'COD',
    },
    status: {
      type: String,
      enum: ['PENDING_PAYMENT', 'PAYMENT_VERIFIED', 'FINALIZED', 'FAILED', 'REFUNDED'],
      default: 'PENDING_PAYMENT',
    },
    paymentStatus: {
      type: String,
      enum: [
        'PENDING',
        'PAID',
        'PENDING_COD_COLLECTION',
        'FAILED',
        'REFUNDED',
        'PARTIALLY_REFUNDED',
      ],
      default: 'PENDING',
    },
    paymentProviderOrderId: { type: String, trim: true },
    paymentReferenceId: { type: String, trim: true },
    paymentClientSecret: { type: String, trim: true },
    paymentSessionId: { type: String, trim: true },
    paymentVerifiedAt: { type: Date },
    couponCode: { type: String, trim: true },
    discount: { type: Number, default: 0 },
    subtotal: { type: Number, required: true, default: 0 },
    deliveryFee: { type: Number, required: true, default: 0 },
    tax: { type: Number, required: true, default: 0 },
    total: { type: Number, required: true, default: 0 },
    stores: { type: [checkoutSessionStoreSchema], default: [] },
    createdOrderIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Order' }],
    failureReason: { type: String, trim: true },
    refundedAt: { type: Date },
  },
  { timestamps: true },
);

export const CheckoutSessionModel = mongoose.model(
  'CheckoutSession',
  checkoutSessionSchema,
);
