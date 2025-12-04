# LearnLynk 

This repository contains the complete implementation for the LearnLynk.



## Setup Instructions

### Backend (Supabase)

1. Create a Supabase project at https://supabase.com
2. Run `backend/schema.sql` in SQL Editor
3. Run `backend/rls_policies.sql` in SQL Editor
4. Deploy Edge Function:
supabase functions deploy create-task


### Frontend (Next.js)

1. Navigate to frontend:
cd frontend


2. Install dependencies:
npm install


3. Create `.env.local`:
NEXT_PUBLIC_SUPABASE_URL=your-project-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key


4. Run dev server:
npm run dev


5. Visit: http://localhost:3000/dashboard/today

## Technologies Used

- **Database**: Supabase Postgres with RLS
- **Backend**: Supabase Edge Functions (Deno/TypeScript)
- **Frontend**: Next.js 15, React Query, Tailwind CSS
- **Language**: TypeScript throughout

## Stripe Answer

### Payment Flow Implementation

The Stripe Checkout flow for application fees follows this architecture:

1. **Payment Request Creation**: When a user initiates payment for an application, insert a record into `payment_requests` table with `status: 'pending'`, storing the `application_id`, `amount_cents`, and a unique `idempotency_key` to prevent duplicate charges.

2. **Stripe Session Creation**: Call `stripe.checkout.sessions.create()` with the application fee amount, passing the `payment_request.id` as `metadata.payment_request_id` and setting `success_url` and `cancel_url` to handle post-payment redirects. Store the returned `session.id` and `payment_intent.id` in the `payment_requests` table.

3. **Checkout Redirect**: Redirect the user to the Stripe-hosted checkout page using `session.url`. This offloads PCI compliance and provides a secure payment interface.

4. **Webhook Handling**: Configure a webhook endpoint (`/api/webhooks/stripe`) that listens for `checkout.session.completed` events. Verify the webhook signature using `stripe.webhooks.constructEvent()` to prevent spoofing, then extract `metadata.payment_request_id` to identify which payment succeeded.

5. **Payment Confirmation**: Upon receiving a valid webhook, update `payment_requests.status` to `'completed'`, store `stripe_payment_intent_id`, and record `completed_at` timestamp. Use a database transaction to ensure atomicity.

6. **Application Stage Update**: Within the same transaction, update the related `applications` table: set `status` to `'paid'` or `'under_review'`, insert a timeline event (e.g., "Payment received: $X"), and trigger any post-payment workflows (document requests, counselor assignment).

7. **Idempotency & Retry Handling**: Use the `idempotency_key` to detect duplicate webhook deliveries (Stripe retries on 5xx errors). Check if `payment_requests.status` is already `'completed'` before processing, and always return `200 OK` quickly (within 5 seconds) to acknowledge receipt, performing heavy operations asynchronously if needed.

This design ensures payment reliability, audit trails via the `payment_requests` table, and seamless integration with the existing application workflow.

---

**Completed by**: Saad Momin 
**Date**: December 4, 2025
