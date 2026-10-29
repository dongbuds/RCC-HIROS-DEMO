# syntax=docker/dockerfile:1
#
# RCC-HIROS-DEMO image
# Next.js 16 (standalone output) + Prisma 7 (client generated into src/generated/prisma)
# Runner keeps full node_modules so `npx prisma db push` can run at deploy time.

FROM node:22-slim AS deps
WORKDIR /app
COPY package.json package-lock.json prisma.config.ts ./
COPY prisma ./prisma
# prisma.config.ts validation requires DATABASE_URL to exist; build-time placeholder only
ENV DATABASE_URL="mysql://placeholder:placeholder@127.0.0.1:3306/placeholder"
RUN apt-get update -y && apt-get install -y --no-install-recommends openssl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN npm ci --no-audit --no-fund

FROM node:22-slim AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1 \
    DATABASE_URL="mysql://placeholder:placeholder@127.0.0.1:3306/placeholder" \
    JWT_SECRET="build-time-placeholder-secret" \
    NEXT_PUBLIC_KIOSK_SERVICE_URL="http://127.0.0.1:8765"
RUN npx prisma generate && npm run build

FROM node:22-slim AS runner
WORKDIR /app
RUN apt-get update -y && apt-get install -y --no-install-recommends openssl ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /app ./
# Standalone server.js resolves static assets relative to its own directory:
# place them there too, while full node_modules stay at /app for the prisma CLI.
RUN cp -r /app/.next/static /app/.next/standalone/.next/static \
    && cp -r /app/public /app/.next/standalone/public
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
EXPOSE 3000
# standalone server.js (emitted by "output: standalone") serves the app;
# full node_modules stay available for `npx prisma db push` migrations from a compose run.
CMD ["node", ".next/standalone/server.js"]
