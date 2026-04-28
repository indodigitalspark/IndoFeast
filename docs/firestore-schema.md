# Firestore Schema

This schema is designed for a role-aware IndoFeast deployment with these top-level collections:

- `users`
- `vendors`
- `delivery_partners`
- `products`
- `categories`
- `orders`
- `order_items`
- `payments`
- `roles`
- `permissions`
- `wallets`
- `reviews`
- `bookings`

## Global document contract

Every document must include:

- `id`: `string`
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`

Recommended write pattern:

- Use the Firestore document id as the `id` field value.
- Set `createdAt` with `FieldValue.serverTimestamp()` on create.
- Set `updatedAt` with `FieldValue.serverTimestamp()` on every create and update.
- Keep foreign keys as string ids to avoid deep nesting and to scale query patterns cleanly.

## Roles used by rules

- `SUPER_ADMIN`
- `ADMIN`
- `MANAGER`
- `VENDOR`
- `DELIVERY_PARTNER`
- `CUSTOMER`

The security rules expect the signed-in user's document to live at `users/{auth.uid}` and include:

- `role`
- `status`
- `permissions`

`status` should typically be one of:

- `PENDING`
- `APPROVED`
- `REJECTED`
- `SUSPENDED`

## Collection structure

### `users/{userId}`

```json
{
  "id": "uid",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "email": "customer@indofeast.com",
  "displayName": "Aman Raj",
  "phoneNumber": "+919999999999",
  "role": "CUSTOMER",
  "status": "APPROVED",
  "permissions": ["orders:read"],
  "photoUrl": "https://...",
  "walletBalance": 0
}
```

### `vendors/{vendorId}`

```json
{
  "id": "vendor_001",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "ownerUserId": "uid",
  "name": "IndoFeast Kitchen",
  "slug": "indofeast-kitchen",
  "status": "ACTIVE",
  "isPublished": true,
  "phoneNumber": "+919999999999",
  "email": "vendor@indofeast.com",
  "address": "Mumbai",
  "geoPoint": "GeoPoint",
  "categoryIds": ["cat_north_indian"],
  "averageRating": 4.7
}
```

### `delivery_partners/{partnerId}`

```json
{
  "id": "uid",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "userId": "uid",
  "status": "ACTIVE",
  "isOnline": false,
  "vehicleType": "BIKE",
  "phoneNumber": "+919999999999",
  "currentZone": "Central Zone",
  "lastSeenAt": "Timestamp"
}
```

### `products/{productId}`

```json
{
  "id": "product_001",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "vendorId": "uid",
  "categoryId": "cat_north_indian",
  "name": "Butter Chicken",
  "description": "Rich tomato gravy",
  "price": 349,
  "currency": "INR",
  "status": "ACTIVE",
  "isPublished": true,
  "imageUrls": ["https://..."],
  "isVeg": false,
  "stockQuantity": 100
}
```

### `categories/{categoryId}`

```json
{
  "id": "cat_north_indian",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "name": "North Indian",
  "slug": "north-indian",
  "isActive": true,
  "sortOrder": 1
}
```

### `orders/{orderId}`

```json
{
  "id": "order_001",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "customerId": "uid_customer",
  "vendorId": "uid_vendor",
  "deliveryPartnerId": "uid_delivery",
  "status": "PLACED",
  "paymentStatus": "PENDING",
  "subtotal": 699,
  "deliveryFee": 49,
  "discount": 50,
  "grandTotal": 698,
  "currency": "INR",
  "deliveryAddress": {
    "line1": "Andheri West",
    "city": "Mumbai",
    "state": "Maharashtra",
    "postalCode": "400053"
  }
}
```

### `order_items/{orderItemId}`

```json
{
  "id": "order_item_001",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "orderId": "order_001",
  "productId": "product_001",
  "vendorId": "uid_vendor",
  "name": "Butter Chicken",
  "price": 349,
  "quantity": 2,
  "lineTotal": 698
}
```

### `payments/{paymentId}`

```json
{
  "id": "payment_001",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "orderId": "order_001",
  "customerId": "uid_customer",
  "vendorId": "uid_vendor",
  "amount": 698,
  "currency": "INR",
  "method": "RAZORPAY",
  "provider": "RAZORPAY",
  "providerPaymentId": "pay_xxx",
  "status": "PAID"
}
```

### `roles/{roleId}`

```json
{
  "id": "role_vendor",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "key": "VENDOR",
  "name": "Vendor",
  "description": "Vendor role for store management",
  "permissionIds": ["perm_products_write", "perm_orders_read"]
}
```

### `permissions/{permissionId}`

```json
{
  "id": "perm_products_write",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "key": "products:write",
  "name": "Manage products",
  "description": "Create and update products"
}
```

### `wallets/{walletId}`

```json
{
  "id": "wallet_uid_customer",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "userId": "uid_customer",
  "balance": 1200,
  "currency": "INR",
  "lastTransactionAt": "Timestamp",
  "status": "ACTIVE"
}
```

Recommended companion collection later if you need ledger depth:

- `wallet_transactions`

### `reviews/{reviewId}`

```json
{
  "id": "review_001",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "orderId": "order_001",
  "productId": "product_001",
  "vendorId": "uid_vendor",
  "customerId": "uid_customer",
  "rating": 5,
  "comment": "Excellent food",
  "isPublished": true
}
```

### `bookings/{bookingId}`

```json
{
  "id": "booking_001",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "customerId": "uid_customer",
  "vendorId": "uid_vendor",
  "bookingDate": "Timestamp",
  "guestCount": 4,
  "status": "PENDING",
  "specialRequest": "Window seat"
}
```

## Security model summary

- Users can read their own profile.
- Admin-family roles can manage operational collections.
- Vendors can manage their own vendor profile and products and access their own orders.
- Delivery partners can access their own partner profile and assigned orders.
- Customers can create and read their own orders, bookings, reviews, and own profile.
- Payments, wallets, roles, and permissions are locked down to admin-family or explicit permission-based writes.

## Deployment

If Firebase CLI is already configured for the target project:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```
