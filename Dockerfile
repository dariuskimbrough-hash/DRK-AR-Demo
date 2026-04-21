# ============================================================
# Dockerfile — Packages the app into a container (the "shipping box")
#
# A container is like a lunchbox:
#   - Everything the app needs is packed inside
#   - It runs the EXACT same way on every machine
#   - No more "it works on my laptop!" problems
# ============================================================

# Start from an official, secure base image (Node.js 20 LTS)
# Using the "slim" variant = smaller image = faster deploys
FROM node:20-slim AS base

# Create a non-root user — security best practice
# Apps should never run as "root" (admin), same as your laptop
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# ---- DEPENDENCY LAYER ----
# Copy package files first (before the rest of the code)
# Docker caches this layer — if package.json hasn't changed,
# it won't re-download all dependencies on the next build. Faster!
FROM base AS deps
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# ---- BUILD LAYER ----
# Install ALL dependencies (including dev tools) to compile/build
FROM base AS build
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build        # Compile TypeScript, bundle assets, etc.

# ---- PRODUCTION IMAGE ----
# Only copy what's needed to RUN the app (not the build tools)
# This keeps the final image lean and secure
FROM base AS production

# Copy the compiled app and production-only node_modules
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./

# Switch to the non-root user
USER appuser

# Tell Docker this app listens on port 3000
EXPOSE 3000

# Health check — Kubernetes uses this to know if the app is alive
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start the application
CMD ["node", "dist/server.js"]
