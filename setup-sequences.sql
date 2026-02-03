-- Create all sequences for Freetask database
-- Run this BEFORE importing the main SQL file

-- Sequences for all tables with auto-increment IDs
CREATE SEQUENCE IF NOT EXISTS "AdminLog_id_seq";
CREATE SEQUENCE IF NOT EXISTS "ChatMessage_id_seq";
CREATE SEQUENCE IF NOT EXISTS "DeviceToken_id_seq";
CREATE SEQUENCE IF NOT EXISTS "Escrow_id_seq";
CREATE SEQUENCE IF NOT EXISTS "Job_id_seq";
CREATE SEQUENCE IF NOT EXISTS "Notification_id_seq";
CREATE SEQUENCE IF NOT EXISTS "Payment_id_seq";
CREATE SEQUENCE IF NOT EXISTS "PortfolioItem_id_seq";
CREATE SEQUENCE IF NOT EXISTS "Review_id_seq";
CREATE SEQUENCE IF NOT EXISTS "Service_id_seq";
CREATE SEQUENCE IF NOT EXISTS "Session_id_seq";
CREATE SEQUENCE IF NOT EXISTS "User_id_seq";
CREATE SEQUENCE IF NOT EXISTS "Withdrawal_id_seq";

-- Verify sequences created
SELECT sequence_name 
FROM information_schema.sequences 
WHERE sequence_schema = 'public'
ORDER BY sequence_name;
