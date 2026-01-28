# Billplz Payment Gateway Setup Guide

## Overview
Panduan lengkap untuk setup dan test Billplz payment integration dalam Freetask App.

## Prerequisites

1. **Billplz Account** - Daftar di [Billplz Sandbox](https://www.billplz-sandbox.com) untuk testing
2. **Collection ID** - Perlu create collection dulu dalam Billplz dashboard

## Step 1: Dapatkan Billplz Credentials

### Untuk Testing (Sandbox Mode)

1. Pergi ke https://www.billplz-sandbox.com
2. Login atau register account baru
3. Navigate ke **Settings** → **API Keys**
4. Copy credentials berikut:
   - **API Secret Key** (contoh: `f9a98086-2db1-4560-b89d-836bdcd14e47`)
   - **X Signature Key** (contoh: `b131381e4889549f07762cbf4ea7b8a49c46399f...`)

5. Navigate ke **Collections**
6. Create collection baru atau copy existing **Collection ID** (contoh: `3jlmivsp`)

### Untuk Production

1. Pergi ke https://www.billplz.com
2. Complete account verification
3. Dapatkan credentials yang sama dari production dashboard
4. Set `BILLPLZ_SANDBOX=false` dalam `.env`

## Step 2: Configure Environment Variables

Edit file `.env` dalam folder `freetask-api`:

```bash
# Billplz Payment Gateway - SANDBOX MODE
BILLPLZ_API_KEY=your-api-secret-key-here
BILLPLZ_COLLECTION_ID=your-collection-id-here
BILLPLZ_X_SIGNATURE_KEY=your-x-signature-key-here
BILLPLZ_SANDBOX=true

# App URLs for payment callbacks
API_URL=http://localhost:4000
APP_URL=http://localhost:51785
```

**IMPORTANT**: Gantikan `your-api-secret-key-here`, `your-collection-id-here`, dan `your-x-signature-key-here` dengan credentials sebenar dari Billplz dashboard.

## Step 3: Restart Backend Server

```powershell
cd freetask-api
npm run start:dev
```

Check logs untuk verify Billplz initialized successfully:
```
[Nest] INFO [BillplzService] ⚠️  Using Billplz SANDBOX mode for testing
```

## Step 4: Test Payment Flow

### Test dalam Local Development

1. **Create Job**
   - Login sebagai client
   - Create job atau hire freelancer
   - Job status akan jadi `AWAITING_PAYMENT`

2. **Initiate Payment**
   - Buka job detail screen
   - Click "Bayar Sekarang" button
   - App akan call `POST /payments/create`
   - Backend akan create Billplz bill dan return payment URL

3. **Complete Payment**
   - Browser akan redirect ke Billplz payment page
   - Dalam sandbox mode, gunakan test payment credentials
   - Click "Pay Now"
   - Selepas payment complete, redirect kembali ke app

4. **Verify**
   - Job status should change dari `AWAITING_PAYMENT` → `IN_PROGRESS`
   - Payment record dalam database status `COMPLETED`
   - Escrow record created dengan status `HELD`
   - Notifications sent kepada client dan freelancer

### Test Billplz Sandbox Payment

Dalam Billplz Sandbox, anda boleh test payment tanpa charge sebenar:

1. Pilih payment method (FPX, Credit Card, etc)
2. Use test credentials provided by Billplz
3. Complete mock payment
4. Webhook akan trigger automatically

## Step 5: Setup Webhook (for Production)

Untuk production, perlu configure webhook URL dalam Billplz dashboard:

1. Pergi ke Billplz Dashboard → **Settings** → **Webhooks**
2. Add webhook URL: `https://your-api-domain.com/payments/webhook`
3. Set `X-Signature` key (sama dengan `BILLPLZ_X_SIGNATURE_KEY`)

Untuk local testing dengan webhook:
- Gunakan [ngrok](https://ngrok.com) untuk expose local backend
- Run: `ngrok http 4000`
- Gunakan ngrok URL sebagai webhook (contoh: `https://abc123.ngrok.io/payments/webhook`)

## Troubleshooting

### Error: "BILLPLZ_API_KEY is not configured"

**Sebab**: Environment variables tidak di-load atau salah configure

**Penyelesaian**:
1. Verify `.env` file ada dalam `freetask-api` folder
2. Check credentials betul-betul copy dari Billplz
3. Restart backend server: `npm run start:dev`

### Error 400: "Bad Request" from Billplz

**Sebab**: Invalid credentials atau collection ID salah

**Penyelesaian**:
1. Double check API Key dan Collection ID
2. Pastikan guna Sandbox credentials kalau set `BILLPLZ_SANDBOX=true`
3. Check Billplz logs dalam dashboard untuk error details

### Error 401: "Authentication Failed"

**Sebab**: API Key tidak sah atau expired

**Penyelesaian**:
1. Regenerate API key dari Billplz dashboard
2. Update `.env` dengan API key baru
3. Restart server

### Payment Created but Webhook Not Triggered

**Sebab**: Webhook URL tidak accessible atau X-Signature salah

**Penyelesaian**:
1. Verify webhook URL accessible (guna ngrok untuk local)
2. Check `BILLPLZ_X_SIGNATURE_KEY` match dengan dashboard
3. Check backend logs untuk webhook errors

### CORS Error

**Sebab**: Frontend cannot access backend API

**Penyelesaian**:
1. Check `main.ts` ada enable CORS:
```typescript
app.enableCors({
  origin: true,
  credentials: true,
});
```
2. Verify `API_URL` dalam `.env` betul

## Testing Checklist

- [ ] Backend logs show "Using Billplz SANDBOX mode for testing"
- [ ] Can create payment (POST /payments/create returns payment URL)
- [ ] Redirect to Billplz payment page works
- [ ] Can complete payment dalam Billplz sandbox
- [ ] Redirect back to app after payment
- [ ] Job status changes to IN_PROGRESS
- [ ] Payment status changes to COMPLETED
- [ ] Escrow created with HELD status
- [ ] Notifications sent successfully
- [ ] Payment retry works untuk failed payments

## Next Steps

Selepas test dalam sandbox mode successful:

1. Dapatkan production credentials dari Billplz
2. Update `.env` dengan production credentials
3. Set `BILLPLZ_SANDBOX=false`
4. Configure production webhook URL
5. Test sekali lagi dalam production environment
6. Deploy to Render/production server

## Support

Jika ada masalah:
- Check Billplz documentation: https://www.billplz.com/api
- Check backend logs untuk detailed error messages
- Verify semua environment variables set betul
- Test API connection dengan Postman/Insomnia
