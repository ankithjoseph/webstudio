# Webstudio Builder - Production Dockerfile for Easypanel
# Multi-stage build for the monorepo

# ============================================
# Stage 1: Base with pnpm
# ============================================
FROM node:20-alpine AS base
RUN corepack enable && corepack prepare pnpm@9.14.4 --activate
RUN apk add --no-cache libc6-compat openssl

# ============================================
# Stage 2: Build the application
# ============================================
FROM base AS builder
WORKDIR /app

# Copy everything and install + build in one stage
COPY . .

# Install all dependencies
RUN pnpm install --frozen-lockfile

# Generate Prisma client
RUN pnpm --filter=@webstudio-is/prisma-client generate

# Build all packages and the builder app
RUN pnpm build

# Deploy the builder app to a standalone directory
# pnpm deploy creates a self-contained directory without symlinks
RUN pnpm --filter=@webstudio-is/builder deploy --prod /app/deployed

# Copy the build output into the deployed directory
RUN cp -r /app/apps/builder/build /app/deployed/build
RUN cp -r /app/apps/builder/public /app/deployed/public

# Debug: List contents to verify
RUN ls -la /app/deployed/
RUN ls -la /app/deployed/build/ || echo "No build directory"
RUN ls -la /app/deployed/build/server/ || echo "No server directory"

# ============================================
# Stage 3: Production runner
# ============================================
FROM node:20-alpine AS runner
WORKDIR /app

# Install openssl for Prisma
RUN apk add --no-cache openssl

ENV NODE_ENV=production
ENV PORT=3000

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 webstudio

# Copy the deployed application with build output included
COPY --from=builder --chown=webstudio:nodejs /app/deployed ./

USER webstudio

EXPOSE 3000

# Start the Remix server
CMD ["node", "node_modules/@remix-run/serve/dist/cli.js", "build/server/index.js"]
