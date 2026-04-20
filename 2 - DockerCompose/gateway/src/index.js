const express = require("express");

const app = express();
const port = process.env.PORT || 4002;
const CATALOG_URL = process.env.CATALOG_URL;

app.get("/videos", async (req, res) => {
  try {
    const response = await fetch(`${___}/videos`);
    const videos = await response.json();
    res.json(___);
  } catch (error) {
    console.error("Failed to reach catalog service:", error.message);
    res.status(500).json({ error: "Catalog service unavailable" });
  }
});

app.listen(port, () => {
  console.log(`Gateway listening on port ${port}`);
});