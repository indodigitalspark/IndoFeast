import mongoose from 'mongoose';

const menuItemSchema = new mongoose.Schema(
  {
    itemId: { type: String, required: true, trim: true },
    name: { type: String, required: true, trim: true },
    description: { type: String, required: true, trim: true },
    category: { type: String, trim: true, default: 'Main Course' },
    price: { type: Number, required: true },
    stock: { type: Number, default: 25 },
    imagePath: { type: String, trim: true },
    isAvailable: { type: Boolean, default: true },
    isVeg: { type: Boolean, default: false },
    bestseller: { type: Boolean, default: false },
    discountPercent: { type: Number, default: 0 },
    preparationTimeMin: { type: Number, default: 20 },
    preparationTimeMax: { type: Number, default: 25 },
    addOns: [{ type: String, trim: true }],
    customizationOptions: [{ type: String, trim: true }],
  },
  { _id: false },
);

const restaurantSchema = new mongoose.Schema(
  {
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    name: { type: String, required: true, trim: true },
    cuisine: [{ type: String, trim: true }],
    category: { type: String, required: true, trim: true },
    rating: { type: Number, required: true },
    deliveryTime: { type: Number, required: true },
    priceLevel: { type: String, required: true, trim: true },
    offerText: { type: String, trim: true },
    description: { type: String, trim: true },
    accentColor: { type: String, trim: true },
    heroTag: { type: String, trim: true },
    storeStatus: {
      type: String,
      enum: ['OPEN', 'CLOSED'],
      default: 'OPEN',
    },
    commissionRate: { type: Number, default: 0.18 },
    pendingSettlementAmount: { type: Number, default: 0 },
    lifetimeSettlementAmount: { type: Number, default: 0 },
    settlementHistory: [
      {
        orderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Order' },
        grossAmount: { type: Number, default: 0 },
        commissionAmount: { type: Number, default: 0 },
        netAmount: { type: Number, default: 0 },
        status: {
          type: String,
          enum: ['PENDING', 'SETTLED', 'REVERSED'],
          default: 'PENDING',
        },
        createdAt: { type: Date, default: Date.now },
      },
    ],
    menuItems: [menuItemSchema],
    reviews: [
      {
        orderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Order' },
        userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        userName: { type: String, trim: true },
        rating: { type: Number },
        review: { type: String, trim: true },
        createdAt: { type: Date, default: Date.now },
      },
    ],
  },
  { timestamps: true },
);

export const RestaurantModel = mongoose.model('Restaurant', restaurantSchema);
