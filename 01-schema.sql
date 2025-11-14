-- Chain of Custody Database Schema
-- Supports Hot & Cold Blockchain System

CREATE DATABASE IF NOT EXISTS coc_evidence;
USE coc_evidence;

-- Evidence metadata table
CREATE TABLE IF NOT EXISTS evidence_metadata (
    evidence_id VARCHAR(64) PRIMARY KEY,
    case_id VARCHAR(64) NOT NULL,
    evidence_type VARCHAR(50) NOT NULL,
    file_size BIGINT,
    ipfs_hash VARCHAR(128),
    sha256_hash VARCHAR(64) NOT NULL,
    collected_timestamp TIMESTAMP NOT NULL,
    collected_by VARCHAR(128),
    location VARCHAR(255),
    description TEXT,
    blockchain_type ENUM('hot', 'cold') NOT NULL,
    transaction_id VARCHAR(128),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_case_id (case_id),
    INDEX idx_blockchain_type (blockchain_type),
    INDEX idx_collected_timestamp (collected_timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Chain of custody events table
CREATE TABLE IF NOT EXISTS custody_events (
    event_id INT AUTO_INCREMENT PRIMARY KEY,
    evidence_id VARCHAR(64) NOT NULL,
    event_type ENUM('collected', 'transferred', 'analyzed', 'archived', 'disposed') NOT NULL,
    from_handler VARCHAR(128),
    to_handler VARCHAR(128),
    timestamp TIMESTAMP NOT NULL,
    location VARCHAR(255),
    notes TEXT,
    blockchain_tx_id VARCHAR(128),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (evidence_id) REFERENCES evidence_metadata(evidence_id) ON DELETE CASCADE,
    INDEX idx_evidence_id (evidence_id),
    INDEX idx_event_type (event_type),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- User access logs table
CREATE TABLE IF NOT EXISTS access_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(128) NOT NULL,
    evidence_id VARCHAR(64),
    action ENUM('view', 'download', 'upload', 'modify', 'delete') NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT,
    success BOOLEAN DEFAULT TRUE,
    notes TEXT,
    INDEX idx_user_id (user_id),
    INDEX idx_evidence_id (evidence_id),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- IPFS pinned files tracking
CREATE TABLE IF NOT EXISTS ipfs_pins (
    pin_id INT AUTO_INCREMENT PRIMARY KEY,
    ipfs_hash VARCHAR(128) UNIQUE NOT NULL,
    evidence_id VARCHAR(64),
    file_name VARCHAR(255),
    file_size BIGINT,
    pinned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    pin_status ENUM('pinned', 'unpinned', 'pinning', 'failed') DEFAULT 'pinning',
    node_id VARCHAR(128),
    FOREIGN KEY (evidence_id) REFERENCES evidence_metadata(evidence_id) ON DELETE SET NULL,
    INDEX idx_ipfs_hash (ipfs_hash),
    INDEX idx_evidence_id (evidence_id),
    INDEX idx_pin_status (pin_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Cases table
CREATE TABLE IF NOT EXISTS cases (
    case_id VARCHAR(64) PRIMARY KEY,
    case_name VARCHAR(255) NOT NULL,
    case_number VARCHAR(100) UNIQUE NOT NULL,
    case_type VARCHAR(50),
    investigating_agency VARCHAR(255),
    lead_investigator VARCHAR(128),
    status ENUM('open', 'under_investigation', 'closed', 'archived') DEFAULT 'open',
    opened_date DATE NOT NULL,
    closed_date DATE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_case_number (case_number),
    INDEX idx_status (status),
    INDEX idx_opened_date (opened_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add foreign key to evidence_metadata
ALTER TABLE evidence_metadata 
ADD CONSTRAINT fk_case 
FOREIGN KEY (case_id) REFERENCES cases(case_id) ON DELETE CASCADE;

-- Blockchain synchronization status
CREATE TABLE IF NOT EXISTS blockchain_sync (
    sync_id INT AUTO_INCREMENT PRIMARY KEY,
    blockchain_type ENUM('hot', 'cold') NOT NULL,
    last_block_number BIGINT,
    last_sync_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sync_status ENUM('syncing', 'synced', 'error') DEFAULT 'syncing',
    error_message TEXT,
    UNIQUE KEY uk_blockchain_type (blockchain_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert initial sync status
INSERT INTO blockchain_sync (blockchain_type, last_block_number, sync_status) 
VALUES ('hot', 0, 'synced'), ('cold', 0, 'synced')
ON DUPLICATE KEY UPDATE last_sync_timestamp = CURRENT_TIMESTAMP;

-- Create views for common queries

-- View: Active cases with evidence count
CREATE OR REPLACE VIEW v_active_cases AS
SELECT 
    c.case_id,
    c.case_name,
    c.case_number,
    c.status,
    c.investigating_agency,
    c.lead_investigator,
    c.opened_date,
    COUNT(DISTINCT e.evidence_id) as evidence_count,
    SUM(e.file_size) as total_evidence_size
FROM cases c
LEFT JOIN evidence_metadata e ON c.case_id = e.case_id
WHERE c.status IN ('open', 'under_investigation')
GROUP BY c.case_id;

-- View: Recent custody events
CREATE OR REPLACE VIEW v_recent_custody_events AS
SELECT 
    ce.event_id,
    ce.evidence_id,
    em.case_id,
    ce.event_type,
    ce.from_handler,
    ce.to_handler,
    ce.timestamp,
    ce.location,
    em.evidence_type
FROM custody_events ce
JOIN evidence_metadata em ON ce.evidence_id = em.evidence_id
ORDER BY ce.timestamp DESC
LIMIT 100;

-- Sample data for testing
INSERT INTO cases (case_id, case_name, case_number, case_type, investigating_agency, lead_investigator, opened_date)
VALUES 
    ('CASE-001', 'Sample Investigation Case', 'INV-2025-001', 'Digital Forensics', 'AUB Security', 'Dr. Hussein Bakri', '2025-01-01'),
    ('CASE-002', 'Test Evidence Case', 'INV-2025-002', 'Cybercrime', 'Law Enforcement', 'Officer Smith', '2025-01-15');

GRANT ALL PRIVILEGES ON coc_evidence.* TO 'cocuser'@'%';
FLUSH PRIVILEGES;

SELECT 'Database schema created successfully!' as message;
