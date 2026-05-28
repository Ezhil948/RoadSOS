-- ============================================================
-- RoadSOS MySQL Full Schema + Sample Data
-- DB: roadsos_db | User: roadsos_admin | Pass: roadsos_pass
-- Run: mysql -u root -p < schema.sql
-- ============================================================

-- Step 1: Create database and user
CREATE DATABASE IF NOT EXISTS roadsos_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'roadsos_admin'@'localhost' IDENTIFIED BY 'roadsos_pass';
GRANT ALL PRIVILEGES ON roadsos_db.* TO 'roadsos_admin'@'localhost';
FLUSH PRIVILEGES;

USE roadsos_db;

-- ============================================================
-- TABLE 1: sos_alerts
-- ============================================================
CREATE TABLE IF NOT EXISTS sos_alerts (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    latitude            DOUBLE NOT NULL,
    longitude           DOUBLE NOT NULL,
    severity            ENUM('minor','moderate','critical') DEFAULT 'critical',
    message             TEXT,
    device_id           VARCHAR(100),
    status              ENUM('active','resolved','false_alarm') DEFAULT 'active',
    accident_report_id  INT DEFAULT NULL,
    alerted_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolved_at         DATETIME DEFAULT NULL,
    INDEX idx_sos_status (status),
    INDEX idx_sos_location (latitude, longitude),
    INDEX idx_sos_device (device_id),
    INDEX idx_sos_alerted (alerted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- TABLE 2: accident_reports
-- ============================================================
CREATE TABLE IF NOT EXISTS accident_reports (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    latitude    DOUBLE NOT NULL,
    longitude   DOUBLE NOT NULL,
    severity    ENUM('minor','moderate','critical') DEFAULT 'moderate',
    casualties  SMALLINT DEFAULT 0,
    description TEXT,
    image_path  VARCHAR(500),
    status      ENUM('open','attended','resolved') DEFAULT 'open',
    reported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_acc_severity (severity),
    INDEX idx_acc_status (status),
    INDEX idx_acc_location (latitude, longitude),
    INDEX idx_acc_reported (reported_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- FK: sos_alerts -> accident_reports
ALTER TABLE sos_alerts
  ADD CONSTRAINT fk_sos_accident
  FOREIGN KEY (accident_report_id) REFERENCES accident_reports(id)
  ON DELETE SET NULL;

-- ============================================================
-- TABLE 3: ai_analysis_results
-- ============================================================
CREATE TABLE IF NOT EXISTS ai_analysis_results (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    accident_report_id  INT UNIQUE DEFAULT NULL,
    detected_objects    TEXT,         -- JSON array of class names
    severity_estimate   VARCHAR(50),
    confidence_score    FLOAT,
    vehicles_count      SMALLINT DEFAULT 0,
    persons_detected    TINYINT(1) DEFAULT 0,
    recommendations     TEXT,         -- JSON array
    model_used          VARCHAR(100) DEFAULT 'yolov8n',
    analyzed_at         DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ai_report FOREIGN KEY (accident_report_id)
        REFERENCES accident_reports(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- TABLE 4: cached_services  (OSM data stored locally)
-- ============================================================
CREATE TABLE IF NOT EXISTS cached_services (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    osm_id       VARCHAR(100),
    name         VARCHAR(255) NOT NULL,
    service_type ENUM('police','hospital','ambulance','towing','puncture','showroom') NOT NULL,
    latitude     DOUBLE NOT NULL,
    longitude    DOUBLE NOT NULL,
    phone        VARCHAR(50),
    address      TEXT,
    country_code VARCHAR(10) DEFAULT 'IN',
    is_verified  TINYINT(1) DEFAULT 0,
    is_active    TINYINT(1) DEFAULT 1,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE INDEX idx_cs_osm_id (osm_id),
    INDEX idx_cs_type (service_type),
    INDEX idx_cs_location (latitude, longitude),
    INDEX idx_cs_country (country_code),
    INDEX idx_cs_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- TABLE 5: emergency_numbers  (per country lookup)
-- ============================================================
CREATE TABLE IF NOT EXISTS emergency_numbers (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    country_code        VARCHAR(10) NOT NULL UNIQUE,
    country_name        VARCHAR(100),
    police              VARCHAR(20),
    ambulance           VARCHAR(20),
    fire                VARCHAR(20),
    national_emergency  VARCHAR(20) DEFAULT '112',
    INDEX idx_en_country (country_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- TABLE 6: service_feedback  (user ratings)
-- ============================================================
CREATE TABLE IF NOT EXISTS service_feedback (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    service_id   INT NOT NULL,
    rating       SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment      TEXT,
    device_id    VARCHAR(100),
    submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fb_service FOREIGN KEY (service_id)
        REFERENCES cached_services(id) ON DELETE CASCADE,
    INDEX idx_fb_service (service_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- TABLE 7: app_logs  (audit + analytics)
-- ============================================================
CREATE TABLE IF NOT EXISTS app_logs (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    event_type  VARCHAR(100) NOT NULL,
    latitude    DOUBLE,
    longitude   DOUBLE,
    device_id   VARCHAR(100),
    metadata    TEXT,             -- JSON
    logged_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_log_event (event_type),
    INDEX idx_log_time (logged_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- SAMPLE DATA
-- ============================================================

-- Emergency numbers (global coverage)
INSERT IGNORE INTO emergency_numbers
  (country_code, country_name, police, ambulance, fire, national_emergency) VALUES
('IN',      'India',          '100', '108', '101', '112'),
('US',      'United States',  '911', '911', '911', '911'),
('GB',      'United Kingdom', '999', '999', '999', '999'),
('AU',      'Australia',      '000', '000', '000', '000'),
('DE',      'Germany',        '110', '112', '112', '112'),
('FR',      'France',         '17',  '15',  '18',  '112'),
('JP',      'Japan',          '110', '119', '119', '110'),
('SG',      'Singapore',      '999', '995', '995', '995'),
('AE',      'UAE',            '999', '998', '997', '999'),
('CA',      'Canada',         '911', '911', '911', '911'),
('DEFAULT', 'International',  '112', '112', '112', '112');

-- Sample cached services (Chennai / Bengaluru area for demo)
INSERT IGNORE INTO cached_services
  (osm_id, name, service_type, latitude, longitude, phone, address, country_code) VALUES
('osm_p1', 'Adyar Police Station',         'police',    13.0002, 80.2565, '044-24910100', 'Adyar, Chennai', 'IN'),
('osm_p2', 'Anna Nagar Police Station',    'police',    13.0850, 80.2101, '044-26213400', 'Anna Nagar, Chennai', 'IN'),
('osm_p3', 'Koramangala Police Station',   'police',    12.9352, 77.6245, '080-25630100', 'Koramangala, Bengaluru', 'IN'),
('osm_h1', 'Apollo Hospitals Chennai',     'hospital',  13.0604, 80.2496, '044-28290200', 'Greams Road, Chennai', 'IN'),
('osm_h2', 'Fortis Hospital Bangalore',    'hospital',  12.9366, 77.6101, '080-66214444', 'Bannerghatta, Bengaluru', 'IN'),
('osm_h3', 'Government General Hospital', 'hospital',  13.0832, 80.2788, '044-25305000', 'Park Town, Chennai', 'IN'),
('osm_a1', 'Chennai 108 Ambulance Bay',   'ambulance', 13.0500, 80.2120, '108',           'Central Depot, Chennai', 'IN'),
('osm_a2', 'Bengaluru CATS Ambulance',    'ambulance', 12.9716, 77.5946, '108',           'Cubbon Park, Bengaluru', 'IN'),
('osm_t1', 'Chennai Towing Services',     'towing',    13.0827, 80.2707, '9840012345',    'Anna Salai, Chennai', 'IN'),
('osm_t2', 'Bengaluru 24hr Towing',       'towing',    12.9716, 77.5946, '9900012345',    'MG Road, Bengaluru', 'IN'),
('osm_r1', 'Ram Tyre Puncture Shop',      'puncture',  13.0400, 80.2300, '9841012345',    'T Nagar, Chennai', 'IN'),
('osm_r2', 'Raj Auto Puncture Works',     'puncture',  12.9800, 77.6100, '9880012345',    'Indiranagar, Bengaluru', 'IN'),
('osm_s1', 'Hyundai Authorized Showroom', 'showroom',  13.0500, 80.2450, '044-43555555',  'Nungambakkam, Chennai', 'IN'),
('osm_s2', 'Maruti Suzuki Service',       'showroom',  12.9600, 77.6200, '080-43666666',  'Koramangala, Bengaluru', 'IN');

-- Sample SOS alert
INSERT IGNORE INTO sos_alerts
  (latitude, longitude, severity, message, device_id, status)
VALUES
  (13.0827, 80.2707, 'critical', 'Test SOS from demo', 'demo_device_001', 'resolved'),
  (12.9716, 77.5946, 'moderate', 'Minor road incident', 'demo_device_002', 'active');

-- Sample accident report
INSERT IGNORE INTO accident_reports
  (latitude, longitude, severity, casualties, description, status)
VALUES
  (13.0700, 80.2600, 'moderate', 2, 'Two vehicle collision near Chennai signal', 'open'),
  (12.9500, 77.6000, 'minor',    0, 'Single vehicle skid, no injuries', 'resolved');

-- ============================================================
-- VERIFICATION QUERIES (run to check setup)
-- ============================================================
-- SELECT COUNT(*) AS emergency_countries FROM emergency_numbers;
-- SELECT COUNT(*) AS cached_services FROM cached_services;
-- SELECT table_name, table_rows FROM information_schema.tables
--   WHERE table_schema = 'roadsos_db' ORDER BY table_name;
