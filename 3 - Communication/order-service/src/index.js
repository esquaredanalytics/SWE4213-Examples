const express = require("express");
const amqp = require("amqplib");

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3001;
const INVENTORY_URL = process.env.INVENTORY_URL || "http://localhost:3000";
const RABBITMQ_URL = process.env.RABBITMQ_URL || "amqp://localhost";

// In-memory order store
const orders = [];
let nextOrderId = 1;
let channel = null; // RabbitMQ channel — set up in main()

// POST /orders — place a new order
app.post("/orders", async (req, res) => {
  const { itemId, quantity, customerName } = req.body;

  if (!itemId || !quantity || !customerName) {
    return res.status(400).json({ error: "itemId, quantity, and customerName are required" });
  }

  try {
    // TODO (Part 2): Call the inventory service to reserve stock.
    //
    // Make a PUT request to: `${INVENTORY_URL}/items/${itemId}/reserve`
    // with a JSON body: { quantity }
    const response = await fetch(`${INVENTORY_URL}/items/${itemId}/reserve`, {//makes an HTTP request to another service and waits for a response ( in this case we are calling the inventory service to reserve a specific item)
      method: "PUT",//inicates we are updating a resource (reserving inventory) rather than creating or retrieving data
      headers: { "Content-Type": "application/json"},
      body: JSON.stringify({quantity}),//sends the quantity to reserve
    });
     if(!response.ok) {
      const err = await response.json(); //extracts the error message from the response body if the reservation fails (e.g., not enough stock)
      throw new Error(err.error || "Inventory reservation failed");//throws an error with the message from the inventory service or a default message if the reservation fails
     }

    // Build and store the confirmed order
    const order = {
      id: nextOrderId++,
      itemId,
      quantity,
      customerName,
      status: "confirmed",
      createdAt: new Date().toISOString(),
    };
    orders.push(order);

    // TODO (Part 3): Publish an "order.placed" event to RabbitMQ.
    const connection = await connectWithRetry(RABBITMQ_URL);
    const channel = await connection.createChannel();
    await channel.assertQueue("order.placed", { durable: false });

    channel.sendToQueue("order.placed", Buffer.from(JSON.stringify(order)));

    console.log("Published event to order.placed queue:", order);

    res.status(201).json(order);
  } catch (err) {
    console.error("Order failed:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /orders — list all orders
app.get("/orders", (req, res) => {
  res.json(orders);
});

async function connectWithRetry(url, retries = 10, delay = 3000) {
  for (let i = 1; i <= retries; i++) {
    try {
      return await amqp.connect(url);
    } catch (err) {
      console.log(`RabbitMQ not ready, retrying (${i}/${retries})...`);
      await new Promise((res) => setTimeout(res, delay));
    }
  }
  throw new Error("Could not connect to RabbitMQ after retries");
}

async function main() {
  // TODO (Part 3): Connect to RabbitMQ and store the channel.
  //
  const connection = await connectWithRetry(RABBITMQ_URL);
  channel = await connection.createChannel();
  await channel.assertQueue("order.placed", { durable: false });
  console.log("Connected to RabbitMQ");

  app.listen(PORT, () => {
    console.log(`Order service running on port ${PORT}`);
  });
}

main().catch(console.error);
