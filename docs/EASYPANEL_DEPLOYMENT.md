# Deploying Webstudio on Easypanel

This guide explains how to deploy the Webstudio Builder on [Easypanel](https://easypanel.io).

> ⚠️ **Note**: The official Webstudio team recommends using the hosted version at [webstudio.is](https://webstudio.is) for the Builder and only self-hosting exported projects. Self-hosting the Builder requires more maintenance and configuration.

## Architecture Overview

Webstudio requires three services:

```
┌─────────────────┐     ┌─────────────────┐
│   Builder App   │────▶│   PostgreSQL    │
│   (Remix.js)    │     │   Database      │
│   Port: 3000    │     │   Port: 5432    │
└────────┬────────┘     └─────────────────┘
         │
         └─────────────▶┌─────────────────┐
                        │   PostgREST     │
                        │   Port: 3001    │
                        └─────────────────┘
```

## Prerequisites

- Easypanel installed and running
- Domain name configured (for OAuth callbacks)
- GitHub or Google OAuth application credentials

## Step 1: Create a New Project in Easypanel

1. Log into your Easypanel dashboard
2. Click **Create Project**
3. Name it `webstudio`

## Step 2: Add PostgreSQL Database

1. In your project, click **+ Add Service**
2. Select **Postgres**
3. Configure:
   - **Service Name**: `postgres`
   - **Database Name**: `webstudio`
   - **Username**: `webstudio`
   - **Password**: Generate a strong password (save it!)
4. Click **Create**

## Step 3: Add PostgREST Service

1. Click **+ Add Service**
2. Select **App** (Docker)
3. Configure:
   - **Service Name**: `postgrest`
   - **Image**: `postgrest/postgrest:v12.2.0`
4. Add environment variables:

```
PGRST_DB_URI=postgresql://webstudio:YOUR_PASSWORD@postgres.webstudio.internal:5432/webstudio
PGRST_DB_SCHEMAS=public
PGRST_DB_ANON_ROLE=anon
PGRST_JWT_SECRET=your-jwt-secret-at-least-32-characters-long
PGRST_DB_MAX_ROWS=1000
```

5. **Port**: Set to `3000`
6. Click **Create**

> 💡 Generate JWT_SECRET with: `openssl rand -hex 32`

## Step 4: Add Builder Application

### Option A: Build from GitHub (Recommended)

1. Click **+ Add Service**
2. Select **App** (GitHub)
3. Configure:
   - **Service Name**: `builder`
   - **Repository**: Your forked Webstudio repository
   - **Branch**: `main`
   - **Dockerfile Path**: `Dockerfile`
4. Click **Create**

### Option B: Build from Source

1. Fork the repository: `https://github.com/webstudio-is/webstudio`
2. Connect your GitHub account to Easypanel
3. Select your forked repository
4. Set Dockerfile path to `Dockerfile`

## Step 5: Configure Builder Environment Variables

Add these environment variables to the Builder service:

### Required Variables

```bash
# Database
DATABASE_URL=postgresql://webstudio:YOUR_PASSWORD@postgres.webstudio.internal:5432/webstudio?pgbouncer=true
DIRECT_URL=postgresql://webstudio:YOUR_PASSWORD@postgres.webstudio.internal:5432/webstudio

# PostgREST
POSTGREST_URL=http://postgrest.webstudio.internal:3000
POSTGREST_API_KEY=your-postgrest-api-key

# Authentication (generate with: openssl rand -hex 32)
AUTH_SECRET=your-auth-secret-at-least-32-characters

# Application
DEPLOYMENT_ENVIRONMENT=production
DEPLOYMENT_URL=https://your-domain.com
PORT=3000
FEATURES=*
USER_PLAN=pro
```

### OAuth Configuration (Choose at least one)

**GitHub OAuth:**
```bash
GH_CLIENT_ID=your-github-client-id
GH_CLIENT_SECRET=your-github-client-secret
```

**Google OAuth:**
```bash
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
```

**Development Login (for testing only):**
```bash
DEV_LOGIN=true
```

### Optional: S3 Storage

```bash
S3_BUCKET=your-bucket-name
S3_REGION=us-east-1
S3_ENDPOINT=https://s3.amazonaws.com
S3_ACCESS_KEY_ID=your-access-key
S3_SECRET_ACCESS_KEY=your-secret-key
S3_ACL=public-read
MAX_UPLOAD_SIZE=10
MAX_ASSETS_PER_PROJECT=50
```

## Step 6: Configure Domain

1. Go to Builder service settings
2. Click **Domains**
3. Add your domain (e.g., `webstudio.yourdomain.com`)
4. Enable **HTTPS** (required for OAuth)
5. Update DNS records as instructed

## Step 7: Set Up OAuth Callbacks

### GitHub OAuth

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Create a new OAuth App or edit existing
3. Set **Authorization callback URL** to:
   ```
   https://your-domain.com/auth/github/callback
   ```

### Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create or edit OAuth 2.0 Client
3. Add **Authorized redirect URI**:
   ```
   https://your-domain.com/auth/google/callback
   ```

## Step 8: Run Database Migrations

After all services are running:

1. Go to Builder service in Easypanel
2. Open **Console** or **Terminal**
3. Run:

```bash
cd /app
npx prisma migrate deploy
```

Or use Easypanel's **Execute Command** feature:
```bash
npx prisma migrate deploy
```

## Step 9: Generate PostgREST API Key

The `POSTGREST_API_KEY` should be a JWT token. Generate it using your `JWT_SECRET`:

```javascript
// Use https://jwt.io or run this Node.js script
const jwt = require('jsonwebtoken');
const token = jwt.sign(
  { role: 'anon' },
  'your-jwt-secret-at-least-32-characters-long',
  { expiresIn: '1y' }
);
console.log(token);
```

Or use an online tool like [jwt.io](https://jwt.io):
- **Payload**: `{"role": "anon"}`
- **Secret**: Your `JWT_SECRET` value

## Verification

1. Visit your domain (e.g., `https://webstudio.yourdomain.com`)
2. You should see the Webstudio login page
3. Sign in with GitHub or Google
4. Create a new project to verify everything works

## Troubleshooting

### Builder won't start

Check logs in Easypanel for the Builder service. Common issues:
- Missing environment variables
- Database connection failed
- PostgREST not reachable

### OAuth not working

- Verify callback URLs match exactly
- Ensure HTTPS is enabled
- Check `DEPLOYMENT_URL` matches your domain

### Database connection errors

- Verify PostgreSQL service is running
- Check `DATABASE_URL` uses correct internal hostname
- Ensure password is correct

### PostgREST errors

- Verify `JWT_SECRET` matches in both PostgREST and Builder
- Check `PGRST_DB_URI` uses correct internal hostname
- Ensure `anon` role exists in database

## Resource Recommendations

| Service    | CPU  | RAM   | Storage |
| ---------- | ---- | ----- | ------- |
| PostgreSQL | 0.5  | 512MB | 5GB+    |
| PostgREST  | 0.25 | 256MB | -       |
| Builder    | 1    | 1GB   | 1GB     |

## Alternative: Using MinIO for Asset Storage

If you don't want to use external S3:

1. Add MinIO service in Easypanel
2. Configure with:
   ```
   S3_ENDPOINT=http://minio.webstudio.internal:9000
   S3_BUCKET=webstudio-assets
   S3_ACCESS_KEY_ID=minioadmin
   S3_SECRET_ACCESS_KEY=minioadmin
   ```
3. Create bucket `webstudio-assets` in MinIO console

## Updating Webstudio

1. Pull latest changes to your forked repository
2. In Easypanel, go to Builder service
3. Click **Redeploy**
4. After deployment, run migrations if needed:
   ```bash
   npx prisma migrate deploy
   ```

## Support

- [Webstudio GitHub Issues](https://github.com/webstudio-is/webstudio/issues)
- [Webstudio Discord](https://discord.gg/webstudio)
- [Easypanel Documentation](https://easypanel.io/docs)
