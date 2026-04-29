import crypto from 'node:crypto';

import { env } from '../config/env.js';

export async function createProviderPayment({ order, user }) {
  switch (order.paymentMethod) {
    case 'RAZORPAY':
      return createRazorpayOrder(order);
    case 'CASHFREE':
      return createCashfreeOrder(order, user);
    case 'STRIPE':
      return createStripePaymentIntent(order, user);
    case 'COD':
      return {
        provider: 'COD',
        paymentStatus: 'PENDING_COD_COLLECTION',
      };
    case 'WALLET':
      return {
        provider: 'WALLET',
        paymentStatus: 'PAID',
        verifiedAt: new Date(),
      };
    default:
      throw new Error('Unsupported payment method.');
  }
}

export async function verifyProviderPayment({ order, payload }) {
  switch (order.paymentMethod) {
    case 'RAZORPAY':
      return verifyRazorpayPayment(order, payload);
    case 'CASHFREE':
      return verifyCashfreePayment(order);
    case 'STRIPE':
      return verifyStripePayment(order);
    case 'WALLET':
      return { status: 'PAID', verifiedAt: new Date() };
    case 'COD':
      return { status: 'PENDING_COD_COLLECTION' };
    default:
      throw new Error('Unsupported payment method.');
  }
}

export async function refundProviderPayment({ order, amount, reason }) {
  switch (order.paymentMethod) {
    case 'RAZORPAY':
      return createRazorpayRefund(order, amount, reason);
    case 'CASHFREE':
      return createCashfreeRefund(order, amount, reason);
    case 'STRIPE':
      return createStripeRefund(order, amount, reason);
    case 'WALLET':
      return {
        refundId: `wallet_refund_${crypto.randomUUID()}`,
        status: 'SUCCESS',
      };
    case 'COD':
      return {
        refundId: `cod_refund_${crypto.randomUUID()}`,
        status: 'SUCCESS',
      };
    default:
      throw new Error('Unsupported payment method.');
  }
}

function buildBasicAuth(key, secret) {
  return `Basic ${Buffer.from(`${key}:${secret}`).toString('base64')}`;
}

async function createRazorpayOrder(order) {
  if (!env.razorpayKeyId || !env.razorpayKeySecret) {
    return mockProviderResponse('RAZORPAY', order);
  }

  const response = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: {
      Authorization: buildBasicAuth(env.razorpayKeyId, env.razorpayKeySecret),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      amount: order.total * 100,
      currency: 'INR',
      receipt: order._id.toString(),
      notes: {
        orderId: order._id.toString(),
      },
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.error?.description || 'Razorpay order creation failed.');
  }

  return {
    provider: 'RAZORPAY',
    providerOrderId: data.id,
    sessionPayload: {
      keyId: env.razorpayKeyId,
      orderId: data.id,
      amount: data.amount,
      currency: data.currency,
    },
    paymentStatus: 'PENDING',
  };
}

async function verifyRazorpayPayment(order, payload) {
  if (!env.razorpayKeySecret) {
    return {
      status: 'PAID',
      referenceId: payload.razorpay_payment_id || `mock_pay_${order._id}`,
      verifiedAt: new Date(),
    };
  }

  const razorpayPaymentId = String(payload.razorpay_payment_id || '').trim();
  const razorpaySignature = String(payload.razorpay_signature || '').trim();
  const providerOrderId = order.paymentProviderOrderId;
  if (!razorpayPaymentId || !razorpaySignature || !providerOrderId) {
    throw new Error('Razorpay verification requires payment id and signature.');
  }

  const generatedSignature = crypto
    .createHmac('sha256', env.razorpayKeySecret)
    .update(`${providerOrderId}|${razorpayPaymentId}`)
    .digest('hex');

  if (generatedSignature !== razorpaySignature) {
    throw new Error('Razorpay payment signature verification failed.');
  }

  return {
    status: 'PAID',
    referenceId: razorpayPaymentId,
    verifiedAt: new Date(),
  };
}

async function createCashfreeOrder(order, user) {
  if (!env.cashfreeClientId || !env.cashfreeClientSecret) {
    return mockProviderResponse('CASHFREE', order);
  }

  const response = await fetch(`${env.cashfreeBaseUrl}/orders`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-version': env.cashfreeApiVersion,
      'x-client-id': env.cashfreeClientId,
      'x-client-secret': env.cashfreeClientSecret,
    },
    body: JSON.stringify({
      order_id: order._id.toString(),
      order_currency: 'INR',
      order_amount: order.total,
      customer_details: {
        customer_id: user._id.toString(),
        customer_phone: user.phoneNumber,
        customer_name: user.displayName,
        customer_email: user.email,
      },
      order_note: `IndoFeast order ${order._id}`,
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.message || 'Cashfree order creation failed.');
  }

  return {
    provider: 'CASHFREE',
    providerOrderId: String(data.cf_order_id),
    sessionId: data.payment_session_id,
    sessionPayload: {
      paymentSessionId: data.payment_session_id,
      orderId: data.order_id || order._id.toString(),
    },
    paymentStatus: 'PENDING',
  };
}

async function verifyCashfreePayment(order) {
  if (!env.cashfreeClientId || !env.cashfreeClientSecret) {
    return {
      status: 'PAID',
      referenceId: order.paymentProviderOrderId || `mock_cf_${order._id}`,
      verifiedAt: new Date(),
    };
  }

  const response = await fetch(
    `${env.cashfreeBaseUrl}/orders/${encodeURIComponent(order.paymentProviderOrderId || order._id.toString())}`,
    {
      headers: {
        'x-api-version': env.cashfreeApiVersion,
        'x-client-id': env.cashfreeClientId,
        'x-client-secret': env.cashfreeClientSecret,
      },
    },
  );
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.message || 'Cashfree payment verification failed.');
  }

  if (String(data.order_status).toUpperCase() !== 'PAID') {
    throw new Error('Cashfree payment is not marked as PAID yet.');
  }

  return {
    status: 'PAID',
    referenceId: String(data.cf_order_id || order.paymentProviderOrderId || ''),
    verifiedAt: new Date(),
  };
}

async function createStripePaymentIntent(order, user) {
  if (!env.stripeSecretKey) {
    return mockProviderResponse('STRIPE', order);
  }

  const body = new URLSearchParams({
    amount: String(order.total * 100),
    currency: 'inr',
    'metadata[orderId]': order._id.toString(),
    'metadata[userId]': user._id.toString(),
    description: `IndoFeast order ${order._id}`,
  });

  const response = await fetch('https://api.stripe.com/v1/payment_intents', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.stripeSecretKey}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.error?.message || 'Stripe PaymentIntent creation failed.');
  }

  return {
    provider: 'STRIPE',
    providerOrderId: data.id,
    clientSecret: data.client_secret,
    sessionPayload: {
      publishableKey: env.stripePublishableKey,
      paymentIntentId: data.id,
      clientSecret: data.client_secret,
    },
    paymentStatus: data.status === 'succeeded' ? 'PAID' : 'PENDING',
    verifiedAt: data.status === 'succeeded' ? new Date() : null,
  };
}

async function verifyStripePayment(order) {
  if (!env.stripeSecretKey) {
    return {
      status: 'PAID',
      referenceId: order.paymentProviderOrderId || `mock_pi_${order._id}`,
      verifiedAt: new Date(),
    };
  }

  const response = await fetch(
    `https://api.stripe.com/v1/payment_intents/${encodeURIComponent(order.paymentProviderOrderId)}`,
    {
      headers: {
        Authorization: `Bearer ${env.stripeSecretKey}`,
      },
    },
  );
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.error?.message || 'Stripe payment verification failed.');
  }

  if (data.status !== 'succeeded') {
    throw new Error(`Stripe payment is ${data.status}, not succeeded.`);
  }

  return {
    status: 'PAID',
    referenceId: data.id,
    verifiedAt: new Date(),
  };
}

async function createRazorpayRefund(order, amount, reason) {
  if (!env.razorpayKeyId || !env.razorpayKeySecret) {
    return mockRefundResponse('RAZORPAY', amount);
  }

  const response = await fetch(
    `https://api.razorpay.com/v1/payments/${encodeURIComponent(order.paymentReferenceId)}/refund`,
    {
      method: 'POST',
      headers: {
        Authorization: buildBasicAuth(env.razorpayKeyId, env.razorpayKeySecret),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amount * 100,
        notes: { reason },
      }),
    },
  );
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.error?.description || 'Razorpay refund failed.');
  }

  return {
    refundId: data.id,
    status: data.status || 'processed',
  };
}

async function createCashfreeRefund(order, amount, reason) {
  if (!env.cashfreeClientId || !env.cashfreeClientSecret) {
    return mockRefundResponse('CASHFREE', amount);
  }

  const refundId = `refund_${crypto.randomUUID()}`;
  const response = await fetch(
    `${env.cashfreeBaseUrl}/orders/${encodeURIComponent(order.paymentProviderOrderId || order._id.toString())}/refunds`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-version': env.cashfreeApiVersion,
        'x-client-id': env.cashfreeClientId,
        'x-client-secret': env.cashfreeClientSecret,
      },
      body: JSON.stringify({
        refund_amount: amount,
        refund_id: refundId,
        refund_note: reason,
        refund_speed: 'STANDARD',
      }),
    },
  );
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.message || 'Cashfree refund failed.');
  }

  const first = Array.isArray(data) ? data[0] : data;
  return {
    refundId: first?.cf_refund_id || refundId,
    status: first?.refund_status || 'SUCCESS',
  };
}

async function createStripeRefund(order, amount, reason) {
  if (!env.stripeSecretKey) {
    return mockRefundResponse('STRIPE', amount);
  }

  const body = new URLSearchParams({
    payment_intent: order.paymentProviderOrderId,
    amount: String(amount * 100),
    reason: 'requested_by_customer',
    'metadata[note]': reason,
  });
  const response = await fetch('https://api.stripe.com/v1/refunds', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.stripeSecretKey}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.error?.message || 'Stripe refund failed.');
  }

  return {
    refundId: data.id,
    status: data.status || 'succeeded',
  };
}

function mockProviderResponse(provider, order) {
  return {
    provider,
    providerOrderId: `${provider.toLowerCase()}_${crypto.randomUUID()}`,
    sessionId: `${provider.toLowerCase()}_session_${crypto.randomUUID()}`,
    clientSecret: `${provider.toLowerCase()}_secret_${crypto.randomUUID()}`,
    sessionPayload: {
      mock: true,
      orderId: order._id.toString(),
      provider,
    },
    paymentStatus: 'PENDING',
  };
}

function mockRefundResponse(provider, amount) {
  return {
    refundId: `${provider.toLowerCase()}_refund_${crypto.randomUUID()}`,
    status: 'SUCCESS',
    amount,
  };
}
