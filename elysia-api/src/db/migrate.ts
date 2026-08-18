import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import postgres from "postgres";
import { env } from "../config/env";

async function runMigrate() {
  console.log("Running migrations...");
  const migrationClient = postgres(env.DATABASE_URL, { max: 1 });
  const db = drizzle(migrationClient);
  await migrate(db, { migrationsFolder: "src/db/migrations" });
  console.log("Migrations complete!");
  await migrationClient.end();
  process.exit(0);
}

runMigrate().catch((err) => {
  console.error("Migration failed:", err);
  process.exit(1);
});
