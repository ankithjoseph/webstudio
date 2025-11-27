# Webstudio Builder - Production Dockerfile for Easypanel
# Multi-stage build for the monorepo

# ============================================
# Stage 1: Base with pnpm
# ============================================
FROM node:20-alpine AS base
RUN corepack enable && corepack prepare pnpm@9.14.4 --activate
RUN apk add --no-cache libc6-compat

# ============================================
# Stage 2: Install dependencies
# ============================================
FROM base AS deps
WORKDIR /app

# Copy package files for dependency installation
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY patches/ ./patches/

# Copy all package.json files from packages and apps
COPY packages/asset-uploader/package.json ./packages/asset-uploader/
COPY packages/authorization-token/package.json ./packages/authorization-token/
COPY packages/css-data/package.json ./packages/css-data/
COPY packages/css-engine/package.json ./packages/css-engine/
COPY packages/dashboard/package.json ./packages/dashboard/
COPY packages/design-system/package.json ./packages/design-system/
COPY packages/domain/package.json ./packages/domain/
COPY packages/feature-flags/package.json ./packages/feature-flags/
COPY packages/fonts/package.json ./packages/fonts/
COPY packages/generate-arg-types/package.json ./packages/generate-arg-types/
COPY packages/html-data/package.json ./packages/html-data/
COPY packages/http-client/package.json ./packages/http-client/
COPY packages/icons/package.json ./packages/icons/
COPY packages/image/package.json ./packages/image/
COPY packages/postgrest/package.json ./packages/postgrest/
COPY packages/prisma-client/package.json ./packages/prisma-client/
COPY packages/project/package.json ./packages/project/
COPY packages/project-build/package.json ./packages/project-build/
COPY packages/react-sdk/package.json ./packages/react-sdk/
COPY packages/sdk/package.json ./packages/sdk/
COPY packages/sdk-cli/package.json ./packages/sdk-cli/
COPY packages/sdk-components-animation/package.json ./packages/sdk-components-animation/
COPY packages/sdk-components-react/package.json ./packages/sdk-components-react/
COPY packages/sdk-components-react-radix/package.json ./packages/sdk-components-react-radix/
COPY packages/sdk-components-react-remix/package.json ./packages/sdk-components-react-remix/
COPY packages/sdk-components-react-router/package.json ./packages/sdk-components-react-router/
COPY packages/template/package.json ./packages/template/
COPY packages/trpc-interface/package.json ./packages/trpc-interface/
COPY packages/tsconfig/package.json ./packages/tsconfig/
COPY apps/builder/package.json ./apps/builder/

# Install all dependencies
RUN pnpm install --frozen-lockfile

# ============================================
# Stage 3: Build the application
# ============================================
FROM base AS builder
WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/packages/*/node_modules ./packages/
COPY --from=deps /app/apps/builder/node_modules ./apps/builder/

# Copy source code
COPY . .

# Generate Prisma client
RUN pnpm --filter=@webstudio-is/prisma-client generate

# Build all packages and the builder app
RUN pnpm build

# ============================================
# Stage 4: Production runner
# ============================================
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 webstudio

# Copy built application
COPY --from=builder --chown=webstudio:nodejs /app/apps/builder/build ./build
COPY --from=builder --chown=webstudio:nodejs /app/apps/builder/public ./public
COPY --from=builder --chown=webstudio:nodejs /app/apps/builder/package.json ./

# Copy node_modules (needed for runtime dependencies)
COPY --from=builder --chown=webstudio:nodejs /app/node_modules ./node_modules

USER webstudio

EXPOSE 3000

# Start the Remix server
CMD ["node", "node_modules/@remix-run/serve/dist/cli.js", "build/server/index.js"]
