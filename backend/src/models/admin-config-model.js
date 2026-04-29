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

const otpSettingsSchema = new mongoose.Schema(
  {
    enabled: { type: Boolean, default: false },
    providerName: {
      type: String,
      trim: true,
      default: 'Custom SMS API',
    },
    apiUrl: { type: String, trim: true, default: '' },
    httpMethod: {
      type: String,
      trim: true,
      uppercase: true,
      default: 'POST',
    },
    authToken: { type: String, trim: true, default: '' },
    senderId: { type: String, trim: true, default: 'INDOFEAST' },
    messageTemplate: {
      type: String,
      trim: true,
      default:
        'Your IndoFeast OTP is {{OTP}}. It expires in {{EXPIRY_MINUTES}} minutes.',
    },
    requestHeaders: {
      type: String,
      trim: true,
      default: '{"Content-Type":"application/json"}',
    },
    requestBodyTemplate: {
      type: String,
      trim: true,
      default:
        '{"phone":"{{PHONE_NUMBER}}","message":"{{MESSAGE}}","senderId":"{{SENDER_ID}}"}',
    },
    successStatusCodes: { type: [Number], default: [200, 201, 202] },
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
    otpSettings: { type: otpSettingsSchema, default: () => ({}) },
  },
  { timestamps: true },
);

export const AdminConfigModel = mongoose.model('AdminConfig', adminConfigSchema);
