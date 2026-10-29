# syntax=docker/dockerfile:1
#
# RCC-HIROS-DEMO image
# Next.js 16 (standalone output) + Prisma 7 (client generated into src/generated/prisma)
# Runner keeps full node_modules so `npx prisma db push` can run at deploy time.

FROM node:22-slim AS deps
WORKDIR /app
COPY package.json package-lock.json prisma.config.ts ./
COPY prisma ./prisma
RUN npm ci --no-audit --no-fund

FROM node:22-slim AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npx prisma generate && npm run build

FROM node:22-slim AS runner
WORKDIR /app
COPY --from=build /app ./
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
EXPOSE 3000
# standalone server.js (emitted by "output: standalone") serves the app;
# full node_modules stay available for `npx prisma db push` migrations from a compose run.
CMD ["node", ".next/standalone/server.js"]
