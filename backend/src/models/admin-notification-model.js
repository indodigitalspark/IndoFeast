import mongoose from 'mongoose';

const adminNotificationSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true },
    body: { type: String, required: true, trim: true },
    targetRoles: [{ type: String, trim: true }],
    isRead: { type: Boolean, default: false },
    relatedUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

export const AdminNotificationModel = mongoose.model(
  'AdminNotification',
  adminNotificationSchema,
);
