import fs from 'fs';
import postgres from 'postgres';
import { env } from '../config/env';

async function run() {
  const sqlContent = fs.readFileSync('src/db/migrations/0001_melodic_karnak.sql', 'utf-8');
  
  // Clean up drizzle's comment breaks
  const queries = sqlContent.split('--> statement-breakpoint').map(q => q.trim()).filter(q => q.length > 0);
  
  const sql = postgres(env.DATABASE_URL, { max: 1 });
  
  try {
    for (const query of queries) {
      console.log(`Executing: ${query.substring(0, 50)}...`);
      await sql.unsafe(query);
    }
    
    // Also mark 0000 and 0001 as applied in drizzle migrations table if it exists
    try {
       await sql.unsafe(`
         CREATE TABLE IF NOT EXISTS "__drizzle_migrations" (
            id SERIAL PRIMARY KEY,
            hash text NOT NULL,
            created_at bigint
         );
       `);
       // just insert a dummy so drizzle doesn't try to run 0000 next time
       await sql.unsafe(`INSERT INTO "__drizzle_migrations" (hash, created_at) VALUES ('manual_0000', extract(epoch from now()) * 1000)`);
       await sql.unsafe(`INSERT INTO "__drizzle_migrations" (hash, created_at) VALUES ('manual_0001', extract(epoch from now()) * 1000)`);
    } catch(e) {}
    
    console.log("Applied manually.");
  } catch (err) {
    console.error(err);
    process.exit(1);
  } finally {
    await sql.end();
  }
}

run();
