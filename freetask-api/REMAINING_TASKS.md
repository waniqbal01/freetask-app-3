# Perkara Yang Masih Tinggal untuk Billplz Payment Integration

## 🔴 CRITICAL - Perlu Action Segera

### 1. Configure Billplz Credentials dalam `.env`

**Status:** ⏳ Waiting for user action

**Apa yang perlu dibuat:**
1. Dapatkan credentials dari [Billplz Sandbox](https://www.billplz-sandbox.com)
2. Update file `freetask-api\.env` dengan credentials sebenar:

```bash
BILLPLZ_API_KEY=your-actual-api-key
BILLPLZ_COLLECTION_ID=your-actual-collection-id
BILLPLZ_X_SIGNATURE_KEY=your-actual-signature-key
BILLPLZ_SANDBOX=true
```

**Verify Configuration:**
```powershell
cd freetask-api
node test-billplz-config.js
```

**Importance:** Payment will NOT work without these credentials!

---

### 2. CORS Headers for Webhook

**Status:** ⚠️ Potential Issue

**Problem:**
Webhook endpoint mungkin perlu additional headers. CORS config sekarang ada:
```typescript
allowedHeaders: 'Content-Type, Authorization'
```

Tapi Billplz webhook send `X-Signature` header yang mungkin blocked.

**Solution:**

Edit `freetask-api\src\main.ts` line 77:

```typescript
// BEFORE
allowedHeaders: 'Content-Type, Authorization',

// AFTER
allowedHeaders: 'Content-Type, Authorization, X-Signature',
```

Ini memastikan Billplz webhook headers tidak di-block oleh CORS.

---

## 🟡 IMPORTANT - Untuk Production

### 3. Production Environment Variables

Bila nak guna production Billplz (bukan sandbox), perlu update:

**In `.env` (Production):**
```bash
BILLPLZ_SANDBOX=false
BILLPLZ_API_KEY=production-api-key
BILLPLZ_COLLECTION_ID=production-collection-id
BILLPLZ_X_SIGNATURE_KEY=production-signature-key

# Production URLs
API_URL=https://freetask-api.onrender.com
APP_URL=https://your-production-app-url.com
```

**In `freetask_app\lib\core\env.dart`:**
```dart
// For production build
return 'https://freetask-api.onrender.com';
```

---

### 4. Webhook URL Configuration in Billplz Dashboard

**For Production:**
1. Login ke Billplz Dashboard (production)
2. Navigate: Settings → Webhooks
3. Add webhook URL: `https://freetask-api.onrender.com/payments/webhook`
4. Set matching X-Signature key

**For Local Testing:**
Guna [ngrok](https://ngrok.com):
```powershell
ngrok http 4000
```
Then configure webhook URL: `https://your-ngrok-url.ngrok.io/payments/webhook`

---

## 🟢 TESTING - Selepas Configure

### 5. End-to-End Payment Testing

**Test Flow:**
1. ✅ Create job as client → Hire freelancer
2. ✅ Job status should be `AWAITING_PAYMENT`
3. ✅ Click "Bayar Sekarang" button
4. ✅ Redirect to Billplz payment page
5. ✅ Complete payment (use sandbox test cards)
6. ✅ Verify redirect back to app
7. ✅ Check job status → `IN_PROGRESS`
8. ✅ Check payment status → `COMPLETED`
9. ✅ Check escrow created → `HELD`
10. ✅ Check notifications sent

**Test in Prisma Studio:**
```powershell
cd freetask-api
npx prisma studio
```

Check tables:
- `Job` - status should change
- `Payment` - should have record dengan status COMPLETED
- `Escrow` - should be created dengan status HELD
- `Notification` - should have 2 records (client & freelancer)

---

### 6. Error Handling Testing

**Test Scenarios:**

**A. Invalid Credentials**
- Set wrong API key
- Try create payment
- Should get clear error: "Billplz authentication failed"

**B. Missing Credentials**
- Remove BILLPLZ_API_KEY from .env
- Restart server
- Should see error log: "❌ BILLPLZ_API_KEY is not configured!"

**C. Failed Payment**
- Create payment
- Cancel payment dalam Billplz page
- Check payment status → should be `FAILED`
- Check notification sent to client

**D. Retry Payment**
- For failed payment
- Click retry button
- Should get new Billplz URL
- Complete payment successfully

---

## 📋 Quick Checklist

Copy this checklist untuk track progress:

```markdown
### Configuration
- [ ] Dapatkan Billplz sandbox credentials
- [ ] Update .env dengan credentials
- [ ] Run test-billplz-config.js untuk verify
- [ ] Fix CORS headers (add X-Signature)
- [ ] Restart backend server

### Testing
- [ ] Test payment creation (check logs)
- [ ] Test redirect to Billplz
- [ ] Test payment completion
- [ ] Test webhook callback
- [ ] Verify job status change
- [ ] Verify escrow creation
- [ ] Verify notifications sent
- [ ] Test payment retry
- [ ] Test failed payment handling

### Production Preparation
- [ ] Get production Billplz credentials
- [ ] Configure production .env
- [ ] Update Flutter app production URL
- [ ] Configure webhook URL in Billplz dashboard
- [ ] Test payment in production
```

---

## 🔧 Optional Improvements

### 7. Payment Status Display Enhancement

Sekarang payment info displayed dalam job detail screen. Boleh improve dengan:

- Add payment history page (sudah ada `payment_history_screen.dart`)
- Add payment receipt download
- Add payment timeline/history
- Better error messages untuk user

### 8. Notification Enhancements

Current notifications basic. Boleh improve:

- Add deep links (click notification → go to job)
- Add payment receipt dalam notification
- Add email notifications (optional)
- Better notification grouping

### 9. Admin Panel Integration

Admin boleh:
- View all payments
- Refund payments (API already exists)
- View payment analytics
- Handle payment disputes

---

## 📝 Summary

**Yang MESTI dibuat sekarang:**
1. ✅ Code improvements - DONE
2. ⏳ Configure .env dengan Billplz credentials - **WAITING**
3. ⏳ Add X-Signature to CORS headers - **RECOMMENDED**
4. ⏳ Test payment flow - **AFTER CONFIG**

**Yang optional tapi best untuk ada:**
- Webhook URL configuration (untuk production)
- Production credentials setup
- Enhanced payment UI/UX
- Admin payment management

**Current Status:**
- Backend code: ✅ Ready
- Frontend code: ✅ Ready
- Configuration: ⏳ Pending user credentials
- Testing: ⏳ Cannot test without credentials

**Next Immediate Steps:**
1. Add X-Signature to CORS headers
2. Get Billplz sandbox credentials
3. Update .env file
4. Test payment creation

Sila follow steps dalam order untuk smooth setup!
