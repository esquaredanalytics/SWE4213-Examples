FROM node:18-slim

WORKDIR /app

# Install backend dependencies
COPY backend/package*.json ./backend/
RUN cd backend && npm install --omit=dev

# Copy built frontend (must be built before docker build)
COPY frontend/dist ./frontend/dist

# Copy backend source
COPY backend/src ./backend/src

WORKDIR /app/backend

EXPOSE 3000
CMD ["node", "src/index.js"]