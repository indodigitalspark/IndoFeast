import { getOrCreateAdminConfig } from './admin-config-service.js';

const DEFAULT_HEADERS = { 'Content-Type': 'application/json' };
const DEFAULT_MESSAGE_TEMPLATE =
  'Your IndoFeast OTP is {{OTP}}. It expires in {{EXPIRY_MINUTES}} minutes.';
const DEFAULT_BODY_TEMPLATE =
  '{"phone":"{{PHONE_NUMBER}}","message":"{{MESSAGE}}","senderId":"{{SENDER_ID}}"}';
const DEFAULT_SUCCESS_STATUS_CODES = [200, 201, 202];

export async function sendRegistrationOtp({
  phoneNumber,
  role,
  code,
  expiryMinutes = 5,
}) {
  const config = await getOrCreateAdminConfig();
  const settings = normalizeOtpSettings(config.otpSettings);
  const replacements = buildTemplateReplacements({
    phoneNumber,
    role,
    code,
    expiryMinutes,
    providerName: settings.providerName,
    senderId: settings.senderId,
    messageTemplate: settings.messageTemplate,
  });

  if (!settings.enabled || !settings.apiUrl) {
    return {
      mode: 'preview',
      providerName: settings.providerName,
      message: `OTP generated for ${phoneNumber}.`,
      otpPreview: code,
    };
  }

  const response = await dispatchOtpRequest(settings, replacements);
  const responsePreview = truncateResponseText(response.bodyText);

  return {
    mode: 'provider',
    providerName: settings.providerName,
    message: `OTP sent to ${phoneNumber} via ${settings.providerName}.`,
    providerStatus: response.status,
    providerResponsePreview: responsePreview,
  };
}

function normalizeOtpSettings(input) {
  return {
    enabled: input?.enabled === true,
    providerName: String(input?.providerName || 'Custom SMS API').trim(),
    apiUrl: String(input?.apiUrl || '').trim(),
    httpMethod: String(input?.httpMethod || 'POST').trim().toUpperCase(),
    authToken: String(input?.authToken || '').trim(),
    senderId: String(input?.senderId || 'INDOFEAST').trim(),
    messageTemplate:
      String(input?.messageTemplate || '').trim() || DEFAULT_MESSAGE_TEMPLATE,
    requestHeaders:
      String(input?.requestHeaders || '').trim() ||
      JSON.stringify(DEFAULT_HEADERS),
    requestBodyTemplate:
      String(input?.requestBodyTemplate || '').trim() || DEFAULT_BODY_TEMPLATE,
    successStatusCodes: Array.isArray(input?.successStatusCodes) &&
        input.successStatusCodes.length > 0
      ? input.successStatusCodes
          .map((item) => Number(item))
          .filter((item) => Number.isInteger(item) && item >= 100 && item <= 599)
      : [...DEFAULT_SUCCESS_STATUS_CODES],
  };
}

function buildTemplateReplacements({
  phoneNumber,
  role,
  code,
  expiryMinutes,
  providerName,
  senderId,
  messageTemplate,
}) {
  const replacements = {
    PHONE_NUMBER: String(phoneNumber || '').trim(),
    ROLE: String(role || '').trim().toUpperCase(),
    OTP: String(code || '').trim(),
    EXPIRY_MINUTES: String(expiryMinutes),
    PROVIDER_NAME: String(providerName || '').trim(),
    SENDER_ID: String(senderId || '').trim(),
  };

  return {
    ...replacements,
    MESSAGE: applyTemplate(messageTemplate, replacements),
  };
}

async function dispatchOtpRequest(settings, replacements) {
  const headers = parseJsonObject(
    settings.requestHeaders,
    'OTP request headers',
  );
  const interpolatedHeaders = interpolateValue(
    settings.authToken
      ? { ...headers, Authorization: `Bearer ${settings.authToken}` }
      : headers,
    replacements,
  );
  const method = settings.httpMethod;
  const url = applyTemplate(settings.apiUrl, replacements);
  const requestInit = {
    method,
    headers: interpolatedHeaders,
  };

  if (method !== 'GET' && method !== 'HEAD') {
    const bodyTemplate = parseJsonValue(
      settings.requestBodyTemplate,
      'OTP request body template',
    );
    const resolvedBody = interpolateValue(bodyTemplate, replacements);

    if (typeof resolvedBody === 'string') {
      requestInit.body = resolvedBody;
    } else {
      requestInit.body = JSON.stringify(resolvedBody);
    }

    if (!requestInit.headers['Content-Type']) {
      requestInit.headers['Content-Type'] = 'application/json';
    }
  }

  const response = await fetch(url, requestInit);
  const bodyText = await response.text();
  const isAccepted =
    response.ok || settings.successStatusCodes.includes(response.status);

  if (!isAccepted) {
    throw new Error(
      `OTP provider rejected the request with status ${response.status}. ${truncateResponseText(bodyText)}`,
    );
  }

  return {
    status: response.status,
    bodyText,
  };
}

function parseJsonObject(value, label) {
  const parsed = parseJsonValue(value, label);
  if (parsed == null || Array.isArray(parsed) || typeof parsed !== 'object') {
    throw new Error(`${label} must be a JSON object.`);
  }
  return parsed;
}

function parseJsonValue(value, label) {
  try {
    return JSON.parse(value);
  } catch (error) {
    throw new Error(`${label} must be valid JSON.`);
  }
}

function interpolateValue(value, replacements) {
  if (typeof value === 'string') {
    return applyTemplate(value, replacements);
  }

  if (Array.isArray(value)) {
    return value.map((item) => interpolateValue(item, replacements));
  }

  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [
        key,
        interpolateValue(item, replacements),
      ]),
    );
  }

  return value;
}

function applyTemplate(template, replacements) {
  return String(template || '').replace(/\{\{([A-Z_]+)\}\}/g, (_, key) => {
    return replacements[key] ?? '';
  });
}

function truncateResponseText(value) {
  const normalized = String(value || '').replace(/\s+/g, ' ').trim();
  if (!normalized) {
    return '';
  }

  return normalized.length > 160
    ? `${normalized.slice(0, 157)}...`
    : normalized;
}
