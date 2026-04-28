import mongoose from 'mongoose';

import { ACCOUNT_STATUSES, USER_ROLES } from '../constants/auth-constants.js';

const documentSchema = new mongoose.Schema(
  {
    originalName: { type: String, trim: true },
    mimeType: { type: String, trim: true },
    size: { type: Number },
    path: { type: String, trim: true },
    uploadedAt: { type: Date, default: Date.now },
  },
  { _id: false },
);

const walletTransactionSchema = new mongoose.Schema(
  {
    amount: { type: Number, required: true },
    type: { type: String, enum: ['CREDIT', 'DEBIT'], required: true },
    description: { type: String, required: true, trim: true },
    category: {
      type: String,
      enum: [
        'WALLET_TOP_UP',
        'ORDER_PAYMENT',
        'ORDER_REFUND',
        'DELIVERY_EARNING',
        'DELIVERY_PAYOUT',
        'ADJUSTMENT',
      ],
      default: 'ADJUSTMENT',
    },
    orderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Order' },
    createdAt: { type: Date, default: Date.now },
  },
  { _id: false },
);

const deliveryProfileSchema = new mongoose.Schema(
  {
    isOnline: { type: Boolean, default: false },
    currentZone: { type: String, trim: true, default: 'Central Zone' },
    vehicleLabel: { type: String, trim: true, default: 'Bike' },
    lastSeenAt: { type: Date },
  },
  { _id: false },
);

const userSchema = new mongoose.Schema(
  {
    displayName: { type: String, required: true, trim: true },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    phoneNumber: { type: String, required: true, trim: true },
    businessName: { type: String, trim: true },
    passwordHash: { type: String, required: true },
    role: {
      type: String,
      enum: USER_ROLES,
      required: true,
      default: 'CUSTOMER',
    },
    customRoleKey: { type: String, trim: true },
    customRoleName: { type: String, trim: true },
    permissions: [{ type: String, trim: true }],
    status: {
      type: String,
      enum: ACCOUNT_STATUSES,
      required: true,
      default: 'PENDING',
    },
    walletBalance: { type: Number, default: 0 },
    walletTransactions: { type: [walletTransactionSchema], default: [] },
    deliveryProfile: deliveryProfileSchema,
    document: documentSchema,
    rejectionReason: { type: String, trim: true },
  },
  { timestamps: true },
);

export const UserModel = mongoose.model('User', userSchema);
