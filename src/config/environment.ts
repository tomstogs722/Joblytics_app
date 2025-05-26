// backend/src/config/environment.ts

import * as dotenv from 'dotenv';

// Load .env file (create one in the backend root if you haven't)
// Example .env content:
// NODE_ENV=development
// PORT=3000
// DATABASE_URL=your_database_connection_string
// JWT_SECRET=your_jwt_secret

dotenv.config({ path: '../../.env' }); // Adjusted path to look for .env in the backend project root

export interface EnvironmentConfig {
  nodeEnv: string;
  port: number;
  databaseUrl?: string;
  jwtSecret?: string;
  // Add other environment variables here
  [key: string]: any; // Allow for additional, untyped variables
}

const config: EnvironmentConfig = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3000', 10),
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
  // Initialize other variables
};

// Function to get a specific config value
export const getEnv = (key: keyof EnvironmentConfig): any => {
  return config[key];
};

// Function to get all configs (use with caution, might expose sensitive info if not handled properly)
export const getAllEnv = (): EnvironmentConfig => {
  return config;
};

// Validate essential configurations (optional but recommended)
if (config.nodeEnv === 'production') {
  if (!config.databaseUrl) {
    console.warn('WARNING: DATABASE_URL is not set for production environment.');
  }
  if (!config.jwtSecret) {
    console.warn('WARNING: JWT_SECRET is not set for production environment.');
  }
}

export default config;
