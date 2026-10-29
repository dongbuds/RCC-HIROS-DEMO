import { PrismaClient } from "../generated/prisma/client";
import { PrismaMariaDb } from "@prisma/adapter-mariadb";

// Parse DATABASE_URL (mysql://user:pass@host:port/db) with graceful fallbacks
// to the original local XAMPP values (localhost / root / rcc_hiros), so this
// works both in the Docker stack (host "db") and as a bare dev server.
function parseDatabaseUrl(url: string | undefined) {
  if (!url) return null;
  try {
    const u = new URL(url);
    const database = u.pathname?.replace(/^\//, "");
    if (!database) return null;
    return {
      host: u.hostname || "localhost",
      port: Number(u.port || 3306),
      user: decodeURIComponent(u.username || "root"),
      password: decodeURIComponent(u.password || ""),
      database,
    };
  } catch {
    return null;
  }
}

const fromUrl = parseDatabaseUrl(process.env.DATABASE_URL);

const adapter = new PrismaMariaDb({
  host: fromUrl?.host ?? "localhost",
  port: fromUrl?.port ?? 3306,
  user: fromUrl?.user ?? "root",
  password: fromUrl?.password ?? "",
  database: fromUrl?.database ?? "rcc_hiros",
  connectionLimit: 10,
});

// ═══════════════════════════════════════════════════════════════
// RCC-HIROS — Prisma client singleton
// ═══════════════════════════════════════════════════════════════

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const db =
  globalForPrisma.prisma ??
  new PrismaClient({
    adapter,
    log: process.env.NODE_ENV === "development" ? ["error", "warn"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = db;
