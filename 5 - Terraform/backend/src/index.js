const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// ── Database ─────────────────────────────────────────────────────────────────

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || "5432"),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false,
});

async function seed() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS profile (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      title TEXT NOT NULL,
      bio TEXT NOT NULL,
      location TEXT NOT NULL,
      email TEXT NOT NULL,
      github TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS skills (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      level TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS projects (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL,
      url TEXT NOT NULL
    );
  `);

  const { rowCount } = await pool.query("SELECT 1 FROM profile LIMIT 1");
  if (rowCount > 0) return;

  await pool.query(`
    INSERT INTO profile (name, title, bio, location, email, github) VALUES
    ('Alex Johnson', 'Full-Stack Developer',
     'I build web applications with a focus on clean architecture and great user experience.',
     'Toronto, Canada', 'alex@example.com', 'https://github.com/alexjohnson');

    INSERT INTO skills (name, level) VALUES
    ('JavaScript', 'Expert'),
    ('React', 'Expert'),
    ('Node.js', 'Advanced'),
    ('PostgreSQL', 'Advanced'),
    ('Docker', 'Intermediate'),
    ('Terraform', 'Intermediate');

    INSERT INTO projects (name, description, url) VALUES
    ('Portfolio API', 'A REST API backed by PostgreSQL, deployed to Azure with Terraform.', 'https://github.com/alexjohnson/portfolio-api'),
    ('Video Streaming App', 'Microservices-based video platform running on AKS.', 'https://github.com/alexjohnson/video-streaming'),
    ('Chat App', 'Real-time chat using WebSockets and RabbitMQ.', 'https://github.com/alexjohnson/chat-app');
  `);

  console.log("Database seeded.");
}

// ── API Routes ────────────────────────────────────────────────────────────────

app.get("/api/profile", async (req, res) => {
  const { rows } = await pool.query("SELECT * FROM profile LIMIT 1");
  res.json(rows[0]);
});

app.get("/api/skills", async (req, res) => {
  const { rows } = await pool.query("SELECT * FROM skills ORDER BY id");
  res.json(rows);
});

app.get("/api/projects", async (req, res) => {
  const { rows } = await pool.query("SELECT * FROM projects ORDER BY id");
  res.json(rows);
});

// ── Serve Frontend ────────────────────────────────────────────────────────────

const FRONTEND = path.join(__dirname, "../../frontend/dist");
app.use(express.static(FRONTEND));
app.get("*", (req, res) => res.sendFile(path.join(FRONTEND, "index.html")));

// ── Start ─────────────────────────────────────────────────────────────────────

app.listen(PORT, async () => {
  console.log(`Server running on port ${PORT}`);
  try {
    await seed();
  } catch (err) {
    console.error("Seed failed:", err.message);
  }
});
