import mongoose from 'mongoose';

const cartItemSchema = new mongoose.Schema(
  {
    restaurantId: { type: mongoose.Schema.Types.ObjectId, ref: 'Restaurant', required: true },
    restaurantName: { type: String, required: true, trim: true },
    menuItemId: { type: String, required: true, trim: true },
    name: { type: String, required: true, trim: true },
    price: { type: Number, required: true },
    quantity: { type: Number, required: true, min: 1, default: 1 },
  },
  { _id: false },
);

const cartSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
    items: { type: [cartItemSchema], default: [] },
    couponCode: { type: String, trim: true },
    discount: { type: Number, default: 0 },
    orderMode: {
      type: String,
      enum: ['DELIVERY', 'PICKUP', 'DINE_IN'],
      default: 'DELIVERY',
    },
    paymentMethod: {
      type: String,
      enum: ['COD', 'WALLET', 'RAZORPAY', 'CASHFREE', 'STRIPE'],
      default: 'COD',
    },
  },
  { timestamps: true },
);

export const CartModel = mongoose.model('Cart', cartSchema);
