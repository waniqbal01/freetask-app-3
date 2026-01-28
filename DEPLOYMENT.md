# Freetask Application Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying the Freetask MVP application, which consists of:
- **Backend**: NestJS API (`freetask-api`)
- **Frontend**: Flutter Web/Mobile application (`freetask_app`)
- **Database**: PostgreSQL

## Prerequisites

- Node.js 18+ and npm
- Flutter SDK 3.0+
- PostgreSQL 14+
- Docker (optional, for containerized deployment)

---

## Local Development Deployment

### 1. Database Setup

**PostgreSQL Installation**:
```bash
# Install PostgreSQL (Windows)
# Download from https://www.postgresql.org/download/windows/

# Create database
psql -U postgres
CREATE DATABASE freetask_db;
```

**Environment Configuration**:
Create `.env` file in `freetask-api/`:
```env
DATABASE_URL="postgresql://postgres:password@localhost:5432/freetask_db"
JWT_SECRET="your-super-secret-jwt-key-change-in-production"
JWT_EXPIRES_IN="15m"
JWT_REFRESH_EXPIRES_IN="7d"
PORT=4000
NODE_ENV="development"
ALLOWED_ORIGINS="http://localhost:3000,http://localhost:8080"
```

### 2. Backend API Setup

```bash
cd freetask-api

# Install dependencies
npm install

# Run database migrations
npx prisma migrate deploy
npx prisma generate

# Seed database with test accounts
npm run seed

# Start development server
npm run start:dev
```

The API will be available at `http://localhost:4000`.

### 3. Frontend Flutter Setup

```bash
cd freetask_app

# Install  dependencies
flutter pub get

# Run web version
flutter run -d chrome

# Or run on mobile (ensure device/emulator is connected)
flutter run
```

---

## Docker Deployment

### Docker Compose (Recommended for Local/Staging)

Create `docker-compose.yml` in the root directory:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:14-alpine
    environment:
      POSTGRES_DB: freetask_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD:-changeme}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build:
      context: ./freetask-api
      dockerfile: Dockerfile
    environment:
      DATABASE_URL: postgresql://postgres:${DB_PASSWORD:-changeme}@postgres:5432/freetask_db
      JWT_SECRET: ${JWT_SECRET}
      JWT_EXPIRES_IN: 15m
      JWT_REFRESH_EXPIRES_IN: 7d
      PORT: 4000
      NODE_ENV: production
      ALLOWED_ORIGINS: ${ALLOWED_ORIGINS}
    ports:
      - "4000:4000"
    depends_on:
      postgres:
        condition: service_healthy
    command: sh -c "npx prisma migrate deploy && npx prisma generate && npm run start:prod"

  web:
    build:
      context: ./freetask_app
      dockerfile: Dockerfile.web
    ports:
      - "8080:80"
    environment:
      API_BASE_URL: http://localhost:4000

volumes:
  postgres_data:
```

**Backend Dockerfile** (`freetask-api/Dockerfile`):
```dockerfile
FROM node:18-alpine AS build

WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/

RUN npm ci

COPY . .

RUN npm run build
RUN npx prisma generate

FROM node:18-alpine

WORKDIR /app

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY package*.json ./

EXPOSE 4000

CMD ["npm", "run", "start:prod"]
```

**Run with Docker Compose**:
```bash
# Set environment variables
export JWT_SECRET="your-production-secret"
export DB_PASSWORD="secure-db-password"
export ALLOWED_ORIGINS="https://yourdomain.com"

# Build and start
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

---

## Cloud Platform Deployment

### Option 1: Render.com

**Backend Deployment**:
1. Create new **Web Service** on Render
2. Connect your GitHub repository
3. Configure:
   - **Build Command**: `cd freetask-api && npm install && npx prisma generate`
   - **Start Command**: `cd freetask-api && npx prisma migrate deploy && npm run start:prod`
   - **Environment Variables**:
     - `DATABASE_URL`: (from Render PostgreSQL service)
     - `JWT_SECRET`: (generate secure random string)
     - `JWT_EXPIRES_IN`: `15m`
     - `JWT_REFRESH_EXPIRES_IN`: `7d`
     - `NODE_ENV`: `production`
     - `ALLOWED_ORIGINS`: Your frontend URL
     - `PORT`: `4000`

**Database**:
1. Create **PostgreSQL** database on Render
2. Copy **Internal Database URL** to `DATABASE_URL` in API service

**Frontend (Flutter Web)**:
1. Build Flutter web: `cd freetask_app && flutter build web`
2. Create **Static Site** on Render
3. Set **Publish Directory**: `freetask_app/build/web`

### Option 2: Railway.app

1. Install Railway CLI: `npm install -g @railway/cli`
2. Login: `railway login`
3. Create project: `railway init`
4. Add PostgreSQL: `railway add postgres`
5. Deploy backend:
   ```bash
   cd freetask-api
   railway up
   ```
6. Set environment variables via Railway dashboard

### Option 3: Fly.io

**Install Fly CLI**:
```bash
# Windows
iwr https://fly.io/install.ps1 -useb | iex
```

**Deploy Backend**:
```bash
cd freetask-api

# Initialize Fly app
fly launch --name freetask-api

# Create PostgreSQL database
fly postgres create --name freetask-db

# Attach database
fly postgres attach freetask-db

# Set secrets
fly secrets set JWT_SECRET="your-secret" JWT_EXPIRES_IN="15m" JWT_REFRESH_EXPIRES_IN="7d"

# Deploy
fly deploy
```

---

## Environment Variables Reference

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string | Yes | `postgresql://user:pass@host:5432/db` |
| `JWT_SECRET` | Secret for JWT signing | Yes | `super-secret-change-me` |
| `JWT_EXPIRES_IN` | Access token expiry | No | `15m` (default) |
| `JWT_REFRESH_EXPIRES_IN` | Refresh token expiry | No | `7d` (default) |
| `PORT` | API server port | No | `4000` (default) |
| `NODE_ENV` | Environment mode | No | `development` / `production` |
| `ALLOWED_ORIGINS` | CORS allowed origins (comma-separated) | Yes (prod) | `https://app.freetask.com` |
| `TRUST_PROXY` | Enable proxy headers | No | `true` |
| `BILLPLZ_API_KEY` | Billplz Secret Key | Yes | `(get from dashboard)` |
| `BILLPLZ_COLLECTION_ID` | Billplz Collection ID | Yes | `(get from dashboard)` |
| `BILLPLZ_X_SIGNATURE_KEY`| Billplz X-Signature Key | Yes | `(get from dashboard)` |
| `BILLPLZ_SANDBOX` | Sandbox Mode | No | `true` / `false` |

---

## SSL/TLS Configuration

### Let's Encrypt (Free SSL)

For cloud deployments, most platforms (Render, Railway, Fly.io) provide **automatic SSL** via Let's Encrypt.

### Custom Domain Setup

1. **Add custom domain** in your cloud platform dashboard
2. **Update DNS records**:
   - Add `A` record pointing to platform's IP
   - Or add `CNAME` record to platform subdomain
3. **Enable SSL** (automatic on most platforms)
4. **Update `ALLOWED_ORIGINS`** in environment variables

---

## Database Migrations

**Apply migrations**:
```bash
npx prisma migrate deploy
```

**Create new migration**:
```bash
npx prisma migrate dev --name migration_name
```

**Reset database** (development only):
```bash
npx prisma migrate reset
```

---

## Seed Data

Run seeder to create test accounts:
```bash
npm run seed
```

This creates:
- **CLIENT**: `client@example.com` / `password123`
- **FREELANCER**: `freelancer@example.com` / `password123`
- **ADMIN**: `admin@example.com` / `admin123`

---

## Monitoring and Logging

### Application Logs

**View logs (Docker)**:
```bash
docker-compose logs -f api
```

**View logs (Cloud Platform)**:
- Render: Dashboard → Logs tab
- Railway: `railway logs`
- Fly.io: `fly logs`

### Health Check Endpoint

API provides health check at:
```
GET /health
```

Response:
```json
{
  "status": "ok",
  "database": "connected",
  "uptime": 12345
}
```

---

## Troubleshooting

### Database Connection Issues

**Error**: `Cannot connect to database`

**Solution**:
1. Verify `DATABASE_URL` is correct
2. Ensure PostgreSQL is running
3. Check network connectivity
4. Verify database exists

### CORS Errors

**Error**: `CORS policy blocked`

**Solution**:
1. Add frontend URL to `ALLOWED_ORIGINS`
2. Ensure format is correct (no trailing slash)
3. Restart API server

### Migration Failures

**Error**: `Migration failed`

**Solution**:
1. Check database is accessible
2. Ensure no conflicting migrations
3. Use `npx prisma migrate reset` (dev only)
4. Check migration files in `prisma/migrations/`

---

## Security Best Practices

1. **Never commit `.env` files** - Use `.env.example` as template
2. **Use strong JWT secrets** - Generate with `openssl rand -base64 32`
3. **Enable HTTPS** in production - Use SSL certificates
4. **Restrict CORS origins** - Never use `*` in production
5. **Update dependencies regularly** - Run `npm audit` and fix vulnerabilities
6. **Use environment-specific configs** - Separate dev/staging/prod configs
7. **Enable rate limiting** - Already implemented in API
8. **Monitor logs** - Set up log aggregation (Sentry, Datadog)

---

## Scaling Considerations

### Horizontal Scaling

- Use load balancer (Nginx, Caddy) to distribute traffic
- Run multiple API instances behind load balancer
- Use connection pooling for database (`pgBouncer`)

### Database Optimization

- Add indexes for frequently queried fields
- Use database read replicas for read-heavy operations
- Implement caching layer (Redis) for frequently accessed data

---

## Backup and Recovery

### Database Backups

**Manual backup**:
```bash
pg_dump -U postgres freetask_db > backup.sql
```

**Restore from backup**:
```bash
psql -U postgres freetask_db < backup.sql
```

**Automated backups** (Cloud platforms):
- Render: Automatic daily backups (paid plans)
- Railway: Configure via dashboard
- Fly.io: Use Fly Postgres built-in backups

---

## Support

For deployment issues, refer to:
- [NestJS Documentation](https://docs.nestjs.com)
- [Prisma Documentation](https://www.prisma.io/docs)
- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/web)

