import mongoose from 'mongoose';

const roleDefinitionSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, trim: true },
    name: { type: String, required: true, trim: true },
    permissions: [{ type: String, trim: true }],
    isSystem: { type: Boolean, default: false },
  },
  { _id: false },
);

const managedCategorySchema = new mongoose.Schema(
  {
    id: { type: String, required: true, trim: true },
    name: { type: String, required: true, trim: true },
    isActive: { type: Boolean, default: true },
  },
  { _id: false },
);

const marketingBannerSchema = new mongoose.Schema(
  {
    id: { type: String, required: true, trim: true },
    title: { type: String, required: true, trim: true },
    subtitle: { type: String, required: true, trim: true },
    ctaText: { type: String, trim: true, default: 'Order now' },
    isActive: { type: Boolean, default: true },
  },
  { _id: false },
);

const websiteQrLinkSchema = new mongoose.Schema(
  {
    id: { type: String, required: true, trim: true },
    title: { type: String, required: true, trim: true },
    description: { type: String, trim: true, default: '' },
    url: { type: String, required: true, trim: true },
    isActive: { type: Boolean, default: true },
  },
  { _id: false },
);

const websiteSettingsSchema = new mongoose.Schema(
  {
    headline: { type: String, trim: true, default: 'IndoFeast Website' },
    subtitle: { type: String, trim: true, default: '' },
    qrLinks: { type: [websiteQrLinkSchema], default: [] },
  },
  { _id: false },
);

const adminConfigSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true, default: 'platform' },
    globalCommissionRate: { type: Number, default: 0.18 },
    roleDefinitions: { type: [roleDefinitionSchema], default: [] },
    managedCategories: { type: [managedCategorySchema], default: [] },
    marketingBanners: { type: [marketingBannerSchema], default: [] },
    websiteSettings: { type: websiteSettingsSchema, default: () => ({}) },
  },
  { timestamps: true },
);

export const AdminConfigModel = mongoose.model('AdminConfig', adminConfigSchema);
