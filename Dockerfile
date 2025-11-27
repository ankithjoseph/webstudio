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
# This is simpler and more reliable for pnpm workspaces
COPY . .

# Install all dependencies
RUN pnpm install --frozen-lockfile

# Generate Prisma client
RUN pnpm --filter=@webstudio-is/prisma-client generate

# Build all packages and the builder app
RUN pnpm build

# Prune dev dependencies for production
RUN pnpm prune --prod

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

# Copy built application and dependencies
COPY --from=builder --chown=webstudio:nodejs /app/apps/builder/build ./build
COPY --from=builder --chown=webstudio:nodejs /app/apps/builder/public ./public
COPY --from=builder --chown=webstudio:nodejs /app/apps/builder/package.json ./
COPY --from=builder --chown=webstudio:nodejs /app/node_modules ./node_modules

# Copy Prisma schema and generated client (required at runtime)
COPY --from=builder --chown=webstudio:nodejs /app/packages/prisma-client ./packages/prisma-client

USER webstudio

EXPOSE 3000

# Start the Remix server
CMD ["node", "node_modules/@remix-run/serve/dist/cli.js", "build/server/index.js"]
