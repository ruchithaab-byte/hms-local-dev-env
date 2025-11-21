-- Create databases for HMS services
-- This script runs automatically when Postgres container first starts

-- BFF Service Database
CREATE DATABASE bff_db;

-- Workflow Service Database
CREATE DATABASE workflow_db;

-- Projector Service Database
CREATE DATABASE projector_db;

-- Grant privileges (optional, but good practice)
GRANT ALL PRIVILEGES ON DATABASE bff_db TO postgres;
GRANT ALL PRIVILEGES ON DATABASE workflow_db TO postgres;
GRANT ALL PRIVILEGES ON DATABASE projector_db TO postgres;

