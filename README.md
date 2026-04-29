# IndoFeast

Production-ready Flutter Web starter built with Clean Architecture, Riverpod, GoRouter, Dio, Material 3, responsive layouts, and dark mode support, backed by a MongoDB Atlas API.

## Firestore contract

This repo now includes a scalable Firestore schema reference and role-based security rules for these collections:

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

Files added:

- `firestore.rules`
- `firestore.indexes.json`
- `firebase.json`
- `docs/firestore-schema.md`

Deploy with:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## Stack

- Flutter `3.41.7` stable
- Riverpod for state management
- GoRouter for routing
- MongoDB Atlas backend API for auth, approvals, notifications, and document metadata
- Dio for backend API communication
- Material 3 with IndoFeast brand colors

## Folder structure

```text
lib/
  core/
  features/
    auth/
    customer/
    vendor/
    delivery/
    admin/
  models/
  routes/
  services/
  shared/

backend/
  src/
    config/
    middleware/
    models/
    routes/
    services/
```

## Important security note

Do not place your MongoDB Atlas URI directly in a Flutter Web client. Web bundles are public, so any embedded database credentials can be extracted by users. Keep MongoDB behind a secure backend API and connect to that backend from Flutter using `Dio`.

## Run locally

```bash
cd backend
npm install
cp .env.example .env
npm run dev

cd ..
flutter pub get
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:4000/api
```

Local integration notes:

- The Flutter app already defaults to `http://localhost:4000/api` if you do not override `API_BASE_URL`.
- Firebase is optional for local backend-only login. You only need the `FIREBASE_*` `--dart-define` values if you want Firebase-backed messaging or storage features.
- The backend accepts localhost web origins on dynamic ports, so Flutter Web can run from ports such as `http://localhost:64607`.
- `npm run dev` uses plain `node src/server.js` for a more stable local setup. If you explicitly want file watching, use `npm run dev:watch`.
- If MongoDB Atlas is unreachable, the backend starts in demo mode so frontend login and admin UI can still boot locally.

## Deploy on Vercel

This repository can now be deployed to Vercel as a single project:

- Flutter web frontend is built to static output
- Express backend is exposed as `/api` through [api/index.js](api/index.js)

The repository includes:

- [vercel.json](vercel.json)
- [scripts/vercel-build-frontend.sh](scripts/vercel-build-frontend.sh)
- [api/index.js](api/index.js)
- [backend/src/index.js](backend/src/index.js)

Required Vercel environment variables:

```bash
MONGODB_URI=...
JWT_SECRET=...
CLIENT_ORIGIN=https://your-vercel-domain.vercel.app
DEFAULT_ADMIN_EMAIL=...
DEFAULT_ADMIN_PASSWORD=...
DEFAULT_ADMIN_NAME=...
```

Optional payment variables:

```bash
RAZORPAY_KEY_ID=...
RAZORPAY_KEY_SECRET=...
CASHFREE_CLIENT_ID=...
CASHFREE_CLIENT_SECRET=...
CASHFREE_API_VERSION=...
CASHFREE_BASE_URL=...
STRIPE_SECRET_KEY=...
STRIPE_PUBLISHABLE_KEY=...
```

Notes:

- `API_BASE_URL` is optional on Vercel now. If omitted, the frontend automatically uses `/api`.
- SPA routing is handled in `vercel.json` without breaking `/api` routes.

Important limitation on Vercel:

- Uploaded files stored on local disk are not durable on serverless infrastructure.
- This app currently writes uploads to `backend/uploads/`.
- For production, move uploads to persistent storage such as S3, Cloudinary, or Vercel Blob.

Troubleshooting:

- If the browser shows `POST http://localhost:4000/api/auth/login net::ERR_CONNECTION_REFUSED`, nothing is listening on port `4000`. Start the backend first with `cd backend && npm run dev`.
- A startup message about missing Firebase config does not block email login against the backend API. It only means you have not supplied optional `FIREBASE_*` runtime values.

## Auth behavior

- Default seeded admin: `aman@indofeast.com` / `Amazing12@`
- Seeded demo accounts for role testing:
  - `admin@indofeast.com` / `Demo123@`
  - `manager@indofeast.com` / `Demo123@`
  - `vendor@indofeast.com` / `Demo123@`
  - `delivery@indofeast.com` / `Demo123@`
  - `customer@indofeast.com` / `Demo123@`
- Registration requires document upload and creates a `PENDING` account
- Only `APPROVED` users can access dashboards
- Admin-family roles can review pending users and change account status
- New registrations create admin notifications in MongoDB
- Phone OTP is implemented through backend-generated OTP sessions; swap this for an SMS provider such as Twilio in production
