/*
=============================================================================
MOLINO VI HEALTH CARE MANAGEMENT SYSTEM
Database: 	molino_vi_hcms
Version: 	3.1
Author: 	Radiant
Leader:		VALENCIA, DIANE ANGELINE M.
Members:	GENEROSO, ALDRIN E.
			MOLIT, JONATHAN R.
			PERLAS, RASHEED ALLEN E.
			SECADRON, ISAIAH M.
			SOL, JOHN CARLO D.
            FIGURA, RHAYAN L.
Date: AY 2025-2026 | 2nd Semester

Description: 	Comprehensive backend database for Molino VI Health Center,
				covering patient management, appointment tracking, vaccination
				records, family linkage, nursing assessments, and reporting.
				Normalized to 3NF. Includes stored procedures, triggers,
				transactions, roles/privileges, and complex reporting queries.
 =============================================================================
*/
-- =============================================================================
-- SECTION 0: DATABASE INITIALIZATION
-- =============================================================================

DROP DATABASE IF EXISTS molino_vi_hcms;
CREATE DATABASE molino_vi_hcms
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE molino_vi_hcms;

-- Disable FK checks during creation for ordering flexibility
SET FOREIGN_KEY_CHECKS = 0;


-- =============================================================================
-- SECTION 1: SCHEMA DESIGN & NORMALIZATION (DDL)
-- All tables normalized to 3NF.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 LOOKUP / REFERENCE TABLES
-- -----------------------------------------------------------------------------

-- Notification Types (lookup, referenced by Notification)
CREATE TABLE Notification_type (
    notification_type_id    INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    type_name               VARCHAR(100)    NOT NULL,
    description             TEXT,
    PRIMARY KEY (notification_type_id),
    UNIQUE KEY uq_notification_type_name (type_name)
) ENGINE=InnoDB COMMENT='Lookup table for categories of system notifications.';


-- Vaccine Master List (lookup for Vaccine_record)
CREATE TABLE Vaccine (
    vaccine_id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    vaccine_name            VARCHAR(150)    NOT NULL,
    manufacturer            VARCHAR(150),
    dose_series             TINYINT         UNSIGNED NOT NULL DEFAULT 1
                                            COMMENT 'Total doses required in the series',
    target_disease          VARCHAR(200),
    route_of_administration ENUM('Intramuscular','Subcutaneous','Oral','Intradermal','Intranasal')
                                            NOT NULL DEFAULT 'Intramuscular',
    is_active               TINYINT(1)      NOT NULL DEFAULT 1,
    PRIMARY KEY (vaccine_id),
    UNIQUE KEY uq_vaccine_name_manufacturer (vaccine_name, manufacturer)
) ENGINE=InnoDB COMMENT='Master list of vaccines available at the health center.';


-- Medication Master List
CREATE TABLE Medication (
    medication_id           INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    medication_name         VARCHAR(200)    NOT NULL,
    generic_name            VARCHAR(200),
    category                VARCHAR(100)    COMMENT 'e.g., Antibiotic, Analgesic, Antihypertensive',
    dosage_form             VARCHAR(100)    COMMENT 'e.g., Tablet, Syrup, Capsule',
    unit_of_measure         VARCHAR(50)     COMMENT 'e.g., mg, ml, IU',
    stock_quantity          INT             UNSIGNED NOT NULL DEFAULT 0,
    reorder_level           INT             UNSIGNED NOT NULL DEFAULT 10,
    is_active               TINYINT(1)      NOT NULL DEFAULT 1,
    PRIMARY KEY (medication_id),
    UNIQUE KEY uq_medication_name_form (medication_name, dosage_form)
) ENGINE=InnoDB COMMENT='Master inventory of medications maintained at the health center.';


-- -----------------------------------------------------------------------------
-- 1.2 FAMILY TABLE
-- Supports household-level linkage for community health profiling.
-- -----------------------------------------------------------------------------

CREATE TABLE Family (
    family_id               INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    family_name             VARCHAR(200)    NOT NULL
                                            COMMENT 'Household surname or identifier',
    address_line1           VARCHAR(255)    NOT NULL,
    address_line2           VARCHAR(255),
    barangay                VARCHAR(100)    NOT NULL DEFAULT 'Molino VI',
    municipality            VARCHAR(100)    NOT NULL DEFAULT 'Bacoor City',
    province                VARCHAR(100)    NOT NULL DEFAULT 'Cavite',
    zip_code                CHAR(4),
    household_head_id       INT             UNSIGNED
                                            COMMENT 'FK to Patient — set after patient records created',
    date_registered         DATE            NOT NULL DEFAULT (CURRENT_DATE),
    is_4ps_beneficiary      TINYINT(1)      NOT NULL DEFAULT 0
                                            COMMENT 'Pantawid Pamilyang Pilipino Program beneficiary flag',
    notes                   TEXT,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (family_id)
) ENGINE=InnoDB COMMENT='Household/family unit for community-level health tracking.';


-- -----------------------------------------------------------------------------
-- 1.3 USERS TABLE (Staff / System Accounts)
-- Stores health center staff credentials and basic profiling.
-- -----------------------------------------------------------------------------

CREATE TABLE Users (
    user_id                 INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    username                VARCHAR(80)     NOT NULL,
    password_hash           VARCHAR(255)    NOT NULL
                                            COMMENT 'Bcrypt or Argon2 hash — never store plaintext',
    role                    ENUM('Admin','Nurse','Doctor','Encoder','ViewOnly')
                                            NOT NULL DEFAULT 'Encoder',
    first_name              VARCHAR(100)    NOT NULL,
    middle_name             VARCHAR(100),
    last_name               VARCHAR(100)    NOT NULL,
    date_of_birth           DATE,
    contact_number          VARCHAR(20),
    email                   VARCHAR(150)    NOT NULL,
    address                 VARCHAR(500),
    is_active               TINYINT(1)      NOT NULL DEFAULT 1,
    last_login              TIMESTAMP       NULL,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_users_username   (username),
    UNIQUE KEY uq_users_email      (email)
) ENGINE=InnoDB COMMENT='System user accounts for health center staff.';


-- -----------------------------------------------------------------------------
-- 1.4 NURSE TABLE
-- Extends Users for nursing-specific credentials.
-- -----------------------------------------------------------------------------

CREATE TABLE Nurse (
    nurse_id                INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id                 INT             UNSIGNED NOT NULL,
    prc_license_number      VARCHAR(50)     NOT NULL
                                            COMMENT 'PRC (Professional Regulation Commission) license',
    license_expiry          DATE            NOT NULL,
    specialization          VARCHAR(150),
    date_hired              DATE            NOT NULL,
    employment_status       ENUM('Regular','Contractual','Volunteer','Seconded')
                                            NOT NULL DEFAULT 'Regular',
    PRIMARY KEY (nurse_id),
    UNIQUE KEY uq_nurse_prc (prc_license_number),
    UNIQUE KEY uq_nurse_user (user_id),
    CONSTRAINT fk_nurse_user
        FOREIGN KEY (user_id) REFERENCES Users (user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Nursing staff credentials linked to system user accounts.';


-- -----------------------------------------------------------------------------
-- 1.5 PATIENT TABLE
-- Core patient record with full basic profiling and family linkage.
-- -----------------------------------------------------------------------------

CREATE TABLE Patient (
    patient_id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    family_id               INT             UNSIGNED
                                            COMMENT 'FK to Family — nullable for unlinked patients',

    -- Basic Profiling (Requirement)
    first_name              VARCHAR(100)    NOT NULL,
    middle_name             VARCHAR(100),
    last_name               VARCHAR(100)    NOT NULL,
    suffix                  VARCHAR(10)     COMMENT 'Jr., Sr., III, etc.',
    date_of_birth           DATE            NOT NULL,
    sex                     ENUM('Male','Female')   NOT NULL,
    civil_status            ENUM('Single','Married','Widowed','Separated','Annulled')
                                            NOT NULL DEFAULT 'Single',
    contact_number          VARCHAR(20),
    email                   VARCHAR(150),
    address_line1           VARCHAR(255)    NOT NULL,
    address_line2           VARCHAR(255),
    barangay                VARCHAR(100)    NOT NULL DEFAULT 'Molino VI',
    municipality            VARCHAR(100)    NOT NULL DEFAULT 'Bacoor City',
    province                VARCHAR(100)    NOT NULL DEFAULT 'Cavite',
    zip_code                CHAR(4),

    -- Family role (self-referencing not needed; family table handles it)
    relationship_to_head    VARCHAR(50)     COMMENT 'e.g., Head, Spouse, Child, Sibling, Other',

    -- Clinical Flags
    blood_type              ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-','Unknown')
                                            NOT NULL DEFAULT 'Unknown',
    is_pwd                  TINYINT(1)      NOT NULL DEFAULT 0  COMMENT 'Person with Disability',
    is_senior_citizen       TINYINT(1)      NOT NULL DEFAULT 0,
    is_pregnant             TINYINT(1)      NOT NULL DEFAULT 0,
    patient_status          ENUM('Active','Inactive','Deceased','Transferred')
                                            NOT NULL DEFAULT 'Active',
    philhealth_number       VARCHAR(30),
    registration_date       DATE            NOT NULL DEFAULT (CURRENT_DATE),
    registered_by           INT             UNSIGNED COMMENT 'FK to Users',

    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (patient_id),
    UNIQUE KEY uq_patient_philhealth (philhealth_number),
    KEY idx_patient_family   (family_id),
    KEY idx_patient_lastname (last_name),
    KEY idx_patient_dob      (date_of_birth),

    CONSTRAINT fk_patient_family
        FOREIGN KEY (family_id) REFERENCES Family (family_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_patient_registered_by
        FOREIGN KEY (registered_by) REFERENCES Users (user_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Master patient registry with full demographic profiling.';


-- Now that Patient exists, add the FK for household_head in Family
ALTER TABLE Family
    ADD CONSTRAINT fk_family_household_head
        FOREIGN KEY (household_head_id) REFERENCES Patient (patient_id)
        ON DELETE SET NULL ON UPDATE CASCADE;


-- -----------------------------------------------------------------------------
-- 1.6 APPOINTMENT TABLE
-- -----------------------------------------------------------------------------

CREATE TABLE Appointment (
    appointment_id          INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    patient_id              INT             UNSIGNED NOT NULL,
    nurse_id                INT             UNSIGNED,
    appointment_date        DATE            NOT NULL,
    appointment_time        TIME            NOT NULL,
    appointment_type        ENUM('Consultation','Vaccination','Prenatal','Postnatal',
                                 'Immunization','Follow-up','Emergency','Others')
                                            NOT NULL DEFAULT 'Consultation',
    reason_for_visit        TEXT,
    status                  ENUM('Scheduled','Completed','Cancelled','No-Show','Rescheduled')
                                            NOT NULL DEFAULT 'Scheduled',
    notes                   TEXT,
    created_by              INT             UNSIGNED,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (appointment_id),
    KEY idx_appt_patient    (patient_id),
    KEY idx_appt_nurse      (nurse_id),
    KEY idx_appt_date       (appointment_date),

    CONSTRAINT fk_appt_patient
        FOREIGN KEY (patient_id) REFERENCES Patient (patient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_appt_nurse
        FOREIGN KEY (nurse_id) REFERENCES Nurse (nurse_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_appt_created_by
        FOREIGN KEY (created_by) REFERENCES Users (user_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Appointment scheduling between patients and nursing staff.';


-- -----------------------------------------------------------------------------
-- 1.7 HISTORY TABLE
-- -----------------------------------------------------------------------------

CREATE TABLE History (
    history_id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    patient_id              INT             UNSIGNED NOT NULL,
    recorded_by             INT             UNSIGNED COMMENT 'FK to Users (nurse/encoder)',
    record_date             DATE            NOT NULL DEFAULT (CURRENT_DATE),

    -- Chief Complaint / HPI
    chief_complaint         TEXT,
    history_of_present_illness TEXT,

    -- Social History
    smoking_status          ENUM('Non-smoker','Current smoker','Former smoker','Unknown')
                                            NOT NULL DEFAULT 'Unknown',
    alcohol_use             ENUM('None','Occasional','Moderate','Heavy','Unknown')
                                            NOT NULL DEFAULT 'Unknown',
    illicit_drug_use        TINYINT(1)      NOT NULL DEFAULT 0,

    -- Family History
    family_hx_hypertension  TINYINT(1)      NOT NULL DEFAULT 0,
    family_hx_diabetes      TINYINT(1)      NOT NULL DEFAULT 0,
    family_hx_asthma        TINYINT(1)      NOT NULL DEFAULT 0,
    family_hx_cancer        TINYINT(1)      NOT NULL DEFAULT 0,
    family_hx_others        TEXT,

    -- Past Medical History
    known_allergies         TEXT,
    previous_hospitalizations TEXT,
    past_surgeries          TEXT,
    chronic_conditions      TEXT            COMMENT 'e.g., Hypertension, Diabetes, Asthma',

    -- Lifestyle (sleep_pattern, skin_care, wound_care consolidated below)
    diet_description        TEXT,
    exercise_habits         TEXT,
    others                  TEXT            COMMENT 'Consolidates: sleep pattern, skin care, wound care, and any miscellaneous health history notes.',

    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (history_id),
    KEY idx_history_patient (patient_id),

    CONSTRAINT fk_history_patient
        FOREIGN KEY (patient_id) REFERENCES Patient (patient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_history_recorded_by
        FOREIGN KEY (recorded_by) REFERENCES Users (user_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Patient health history records.';


-- -----------------------------------------------------------------------------
-- 1.8 PHYSICAL ASSESSMENT TABLE
-- -----------------------------------------------------------------------------

CREATE TABLE Physical_assessment (
    assessment_id           INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    patient_id              INT             UNSIGNED NOT NULL,
    appointment_id          INT             UNSIGNED
                                            COMMENT 'Linked appointment, if applicable',
    assessed_by             INT             UNSIGNED COMMENT 'FK to Users (nurse)',
    assessment_date         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Vital Signs
    temperature_celsius     DECIMAL(4,1)    COMMENT 'Body temperature in °C',
    pulse_rate_bpm          SMALLINT        UNSIGNED COMMENT 'Beats per minute',
    respiratory_rate_bpm    SMALLINT        UNSIGNED COMMENT 'Breaths per minute',
    bp_systolic_mmhg        SMALLINT        UNSIGNED COMMENT 'Systolic BP in mmHg',
    bp_diastolic_mmhg       SMALLINT        UNSIGNED COMMENT 'Diastolic BP in mmHg',
    oxygen_saturation_pct   DECIMAL(5,2)    COMMENT 'SpO2 in %',
    weight_kg               DECIMAL(5,2),
    height_cm               DECIMAL(5,2),
    bmi                     DECIMAL(5,2)    COMMENT 'Computed or stored BMI',

    -- Head-to-Toe Assessment (structured fields)
    general_appearance      TEXT,
    heent                   TEXT            COMMENT 'Head, Eyes, Ears, Nose, Throat',
    chest_lungs             TEXT,
    cardiovascular          TEXT,
    abdomen                 TEXT,
    musculoskeletal         TEXT,
    neurological            TEXT,

    others                  TEXT            COMMENT 'Consolidates: orientation, skin turgor, mucous membrane, peripheral sounds, neck vein distention, sputum, and any additional assessment findings.',

    assessment_summary      TEXT,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (assessment_id),
    KEY idx_pa_patient      (patient_id),
    KEY idx_pa_appointment  (appointment_id),

    CONSTRAINT fk_pa_patient
        FOREIGN KEY (patient_id) REFERENCES Patient (patient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_pa_appointment
        FOREIGN KEY (appointment_id) REFERENCES Appointment (appointment_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_pa_assessed_by
        FOREIGN KEY (assessed_by) REFERENCES Users (user_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Physical assessment records.';


-- -----------------------------------------------------------------------------
-- 1.9 ADMISSION DATA TABLE
-- -----------------------------------------------------------------------------

CREATE TABLE Admission_data (
    admission_id            INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    patient_id              INT             UNSIGNED NOT NULL,
    admitted_by             INT             UNSIGNED COMMENT 'FK to Users',
    admission_date          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    admission_reason        TEXT            NOT NULL,
    discharge_date          DATETIME,
    discharge_summary       TEXT,
    admission_status        ENUM('Admitted','Discharged','Transferred','Absconded','Deceased')
                                            NOT NULL DEFAULT 'Admitted',
    ward_bed_number         VARCHAR(20),
    referring_facility      VARCHAR(200),
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (admission_id),
    KEY idx_admission_patient (patient_id),

    CONSTRAINT fk_admission_patient
        FOREIGN KEY (patient_id) REFERENCES Patient (patient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_admission_admitted_by
        FOREIGN KEY (admitted_by) REFERENCES Users (user_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Inpatient admission records for patients.';


-- -----------------------------------------------------------------------------
-- 1.10 VACCINE RECORD TABLE 
-- -----------------------------------------------------------------------------

CREATE TABLE Vaccine_record (
    vaccine_record_id       INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    patient_id              INT             UNSIGNED NOT NULL,
    vaccine_id              INT             UNSIGNED NOT NULL,
    appointment_id          INT             UNSIGNED
                                            COMMENT 'Associated appointment if applicable',
    administered_by         INT             UNSIGNED COMMENT 'FK to Users (nurse/encoder)',
    dose_number             TINYINT         UNSIGNED NOT NULL DEFAULT 1
                                            COMMENT 'Which dose in the series (1, 2, 3…)',
    date_administered       DATE            NOT NULL,
    lot_number              VARCHAR(50),
    site_of_injection       VARCHAR(100)    COMMENT 'e.g., Left Deltoid, Right Thigh',
    next_due_date           DATE            COMMENT 'Scheduled date for next dose if applicable',
    adverse_reaction        TEXT            COMMENT 'Any AEFI (Adverse Events Following Immunization)',
    is_complete             TINYINT(1)      NOT NULL DEFAULT 0
                                            COMMENT '1 = full series completed for this vaccine',
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (vaccine_record_id),
    UNIQUE KEY uq_vr_patient_vaccine_dose (patient_id, vaccine_id, dose_number),
    KEY idx_vr_patient      (patient_id),
    KEY idx_vr_vaccine      (vaccine_id),
    KEY idx_vr_date         (date_administered),

    CONSTRAINT fk_vr_patient
        FOREIGN KEY (patient_id) REFERENCES Patient (patient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_vr_vaccine
        FOREIGN KEY (vaccine_id) REFERENCES Vaccine (vaccine_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_vr_appointment
        FOREIGN KEY (appointment_id) REFERENCES Appointment (appointment_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_vr_administered_by
        FOREIGN KEY (administered_by) REFERENCES Users (user_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Individual vaccination records per patient per vaccine dose.';


-- -----------------------------------------------------------------------------
-- 1.11 PRESCRIPTION / MEDICATION DISPENSING TABLE
-- -----------------------------------------------------------------------------

CREATE TABLE Prescription (
    prescription_id         INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    patient_id              INT             UNSIGNED NOT NULL,
    appointment_id          INT             UNSIGNED,
    medication_id           INT             UNSIGNED NOT NULL,
    prescribed_by           INT             UNSIGNED COMMENT 'FK to Users',
    prescription_date       DATE            NOT NULL DEFAULT (CURRENT_DATE),
    dosage_instructions     VARCHAR(255)    NOT NULL
                                            COMMENT 'e.g., 500mg twice daily after meals',
    quantity_dispensed      INT             UNSIGNED NOT NULL DEFAULT 0,
    duration_days           SMALLINT        UNSIGNED,
    status                  ENUM('Active','Completed','Discontinued','On-Hold')
                                            NOT NULL DEFAULT 'Active',
    notes                   TEXT,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (prescription_id),
    KEY idx_rx_patient      (patient_id),
    KEY idx_rx_medication   (medication_id),

    CONSTRAINT fk_rx_patient
        FOREIGN KEY (patient_id) REFERENCES Patient (patient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_rx_appointment
        FOREIGN KEY (appointment_id) REFERENCES Appointment (appointment_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_rx_medication
        FOREIGN KEY (medication_id) REFERENCES Medication (medication_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_rx_prescribed_by
        FOREIGN KEY (prescribed_by) REFERENCES Users (user_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Medication prescriptions and dispensing records per patient visit.';


-- -----------------------------------------------------------------------------
-- 1.12 NOTIFICATION TABLE
-- -----------------------------------------------------------------------------

CREATE TABLE Notification (
    notification_id         INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    notification_type_id    INT             UNSIGNED NOT NULL,
    recipient_user_id       INT             UNSIGNED NOT NULL
                                            COMMENT 'The staff member receiving the notification',
    patient_id              INT             UNSIGNED
                                            COMMENT 'Related patient, if applicable',
    message                 TEXT            NOT NULL,
    is_read                 TINYINT(1)      NOT NULL DEFAULT 0,
    read_at                 TIMESTAMP       NULL,
    priority                ENUM('Low','Normal','High','Urgent')
                                            NOT NULL DEFAULT 'Normal',
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (notification_id),
    KEY idx_notif_recipient (recipient_user_id),
    KEY idx_notif_patient   (patient_id),

    CONSTRAINT fk_notif_type
        FOREIGN KEY (notification_type_id) REFERENCES Notification_type (notification_type_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_notif_recipient
        FOREIGN KEY (recipient_user_id) REFERENCES Users (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_notif_patient
        FOREIGN KEY (patient_id) REFERENCES Patient (patient_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='In-system notifications dispatched to health center staff.';


-- -----------------------------------------------------------------------------
-- 1.13 REPORT TABLE
-- -----------------------------------------------------------------------------

CREATE TABLE Report (
    report_id               INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    report_type             VARCHAR(100)    NOT NULL
                                            COMMENT 'e.g., Monthly Immunization, Census, Utilization',
    report_period_start     DATE            NOT NULL,
    report_period_end       DATE            NOT NULL,
    generated_by            INT             UNSIGNED,
    generated_at            TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    parameters_json         JSON            COMMENT 'Filters/parameters used to generate the report',
    status                  ENUM('Draft','Final','Archived')
                                            NOT NULL DEFAULT 'Draft',
    notes                   TEXT,

    PRIMARY KEY (report_id),
    KEY idx_report_type (report_type),

    CONSTRAINT fk_report_generated_by
        FOREIGN KEY (generated_by) REFERENCES Users (user_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_report_period
        CHECK (report_period_end >= report_period_start)
) ENGINE=InnoDB COMMENT='Metadata registry for generated health center reports.';


-- -----------------------------------------------------------------------------
-- 1.14 AUDIT LOG TABLE (supports trigger-based auditing)
-- -----------------------------------------------------------------------------

CREATE TABLE Audit_log (
    log_id                  BIGINT          UNSIGNED NOT NULL AUTO_INCREMENT,
    table_name              VARCHAR(100)    NOT NULL,
    record_id               INT             UNSIGNED NOT NULL,
    action                  ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    changed_by              INT             UNSIGNED COMMENT 'FK to Users',
    changed_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    old_values_json         JSON            COMMENT 'Snapshot of values before change',
    new_values_json         JSON            COMMENT 'Snapshot of values after change',
    ip_address              VARCHAR(45),
    notes                   TEXT,

    PRIMARY KEY (log_id),
    KEY idx_audit_table  (table_name),
    KEY idx_audit_record (record_id),
    KEY idx_audit_user   (changed_by)
) ENGINE=InnoDB COMMENT='System-wide audit trail for INSERT/UPDATE/DELETE operations.';

-- Re-enable FK checks
SET FOREIGN_KEY_CHECKS = 1;


-- =============================================================================
-- SECTION 2: SEED / REFERENCE DATA (DML)
-- This is where we insert data
-- =============================================================================

-- Notification types
INSERT INTO Notification_type (type_name, description) VALUES
('Appointment Reminder',    'Automated reminder for upcoming appointments'),
('Vaccination Due',         'Alert for patients with upcoming or overdue vaccines'),
('Low Stock Alert',         'Medication inventory below reorder level'),
('Patient Status Change',   'Triggered when a patient status is updated'),
('Admission Alert',         'Notification when a patient is admitted or discharged'),
('System Alert',            'General system-level notifications for administrators');

-- Vaccines (DOH Philippines EPI Program + common vaccines)
INSERT INTO Vaccine (vaccine_name, manufacturer, dose_series, target_disease, route_of_administration) VALUES
('BCG',                         'Serum Institute of India',  1,  'Tuberculosis',                  'Intradermal'),
('Hepatitis B (Birth Dose)',     'GSK',                       1,  'Hepatitis B',                   'Intramuscular'),
('Pentavalent (DPT-HepB-Hib)',  'GSK',                       3,  'Diphtheria, Pertussis, Tetanus, Hepatitis B, Hib', 'Intramuscular'),
('Oral Polio Vaccine (OPV)',     'Bio Farma',                 3,  'Poliomyelitis',                 'Oral'),
('Inactivated Polio Vaccine (IPV)', 'Sanofi Pasteur',        1,  'Poliomyelitis',                 'Intramuscular'),
('Pneumococcal Conjugate (PCV)','Pfizer',                    3,  'Pneumococcal Disease',          'Intramuscular'),
('Measles, Mumps, Rubella (MMR)','Merck',                    2,  'Measles, Mumps, Rubella',       'Subcutaneous'),
('Tetanus Toxoid (TT)',          'Serum Institute of India',  5,  'Tetanus (Maternal & Neonatal)', 'Intramuscular'),
('Influenza',                   'Sanofi Pasteur',            1,  'Influenza',                     'Intramuscular'),
('COVID-19 (Pfizer)',           'Pfizer',                    2,  'COVID-19',                      'Intramuscular'),
('Human Papillomavirus (HPV)',   'GSK',                       2,  'HPV-related cancers',           'Intramuscular'),
('Typhoid',                     'Sanofi Pasteur',            1,  'Typhoid Fever',                 'Intramuscular');

-- Sample medications
INSERT INTO Medication (medication_name, generic_name, category, dosage_form, unit_of_measure, stock_quantity, reorder_level) VALUES
('Biogesic',        'Paracetamol',          'Analgesic/Antipyretic',    'Tablet',   'mg',   500,    50),
('Amoxicillin 500', 'Amoxicillin',          'Antibiotic',               'Capsule',  'mg',   300,    30),
('Amlodipine 5mg',  'Amlodipine',           'Antihypertensive',         'Tablet',   'mg',   200,    20),
('Metformin 500mg', 'Metformin HCl',        'Antidiabetic',             'Tablet',   'mg',   200,    20),
('Salbutamol MDI',  'Salbutamol',           'Bronchodilator',           'Inhaler',  'mcg',  50,     10),
('ORS Sachet',      'Oral Rehydration Salts','Rehydration',             'Sachet',   'g',    400,    40),
('Ferrous Sulfate',  'Ferrous Sulfate',      'Iron Supplement',          'Tablet',   'mg',   300,    30),
('Folic Acid 400mcg','Folic Acid',           'Vitamin/Supplement',      'Tablet',   'mcg',  300,    30);

-- Sample Users (passwords are placeholder hashes)
INSERT INTO Users (username, password_hash, role, first_name, middle_name, last_name, date_of_birth, contact_number, email, address, is_active) VALUES
('admin.generoso',    '@bhcmADMIN#001', 'Admin',   'Aldrin',    'Elois',     'Generoso',    '1985-03-15', '09171234567', 'aldrin.generoso@bhc-molinovi.ph', 'Blk 1 Lot 2, Molino VI, Bacoor City, Cavite', 1),
('admin.perlas',    '@bhcmADMIN#002', 'Admin',   'Allen',    'Cruz',     'Perlas',    '1985-03-15', '09171234576', 'allen.perlas@bhc-molinovi.ph', 'Blk 1 Lot 2, Molino VI, Bacoor City, Cavite', 1),
('nurse.secadron',     '@bhcmNURSE#001', 'Nurse',   'Isaiah',     'Mendez', 'Secadron',     '1990-07-22', '09281234567', 'isaiah.secadron@bhc-molinovi.ph',   'Blk 3 Lot 5, Molino VI, Bacoor City, Cavite', 1),
('nurse.molit', '@bhcmNURSE#002', 'Nurse',   'Jonathan',      'Rosales',   'Molit', '1992-11-08', '09391234567', 'jonathan.molit@bhc-molinovi.ph', 'Blk 7 Lot 1, Molino VI, Bacoor City, Cavite', 1),
('encoder.sol',     '@bhcmENC#001',   'Encoder', 'John',   'Molina',      'Sol',       '1995-05-30', '09501234567', 'john.sol@bhc-molinovi.ph',   'Blk 2 Lot 8, Molino VI, Bacoor City, Cavite', 1),
('encoder.figura',     '@bhcmENC#002',   'Encoder', 'Rhayan',   'Losaria',      'Figura',       '1995-01-01', '09501234599', 'rhayan.figura@bhc-molinovi.ph',   'Blk 2 Lot 8, Molino VI, Bacoor City, Cavite', 1),
('doctor.valencia',  '@bhcmDOC#001',   'Doctor',  'Diane Angeline',    'Militares',    'Valencia',   '1978-05-19', '09995538443', 'diane.valencia@bhc-molinovi.ph','Blk 5 Lot 3, Molino VI, Bacoor City, Cavite', 1);

-- Nurse records (linked to user accounts)
INSERT INTO Nurse (user_id, prc_license_number, license_expiry, specialization, date_hired, employment_status) VALUES
(2, 'PRC-RN-0012345', '2027-06-30', 'Community Health Nursing',   '2018-01-15', 'Regular'),
(3, 'PRC-RN-0023456', '2026-12-31', 'Maternal and Child Health',  '2020-06-01', 'Regular');

-- Sample Families
INSERT INTO Family (family_name, address_line1, barangay, municipality, province, zip_code, date_registered, is_4ps_beneficiary) VALUES
('Dela Rosa Family', 'Blk 10 Lot 3 Sitio Malaya',          'Molino VI', 'Bacoor City', 'Cavite', '4102', '2023-01-10', 1),
('Gonzales Family',  'Blk 4 Lot 12 Purok 2',               'Molino VI', 'Bacoor City', 'Cavite', '4102', '2023-03-22', 0),
('Ramos Family',     '123 Sampaguita St.',                 'Molino VI', 'Bacoor City', 'Cavite', '4102', '2024-01-05', 0),
('Aquino Family',    'Blk 8 Lot 6 Sitio Bagong Pag-asa',   'Molino VI', 'Bacoor City', 'Cavite', '4102', '2024-07-18', 1);

-- Sample Patients
INSERT INTO Patient (family_id, first_name, middle_name, last_name, date_of_birth, sex, civil_status,
    contact_number, email, address_line1, barangay, municipality, province, zip_code,
    relationship_to_head, blood_type, is_senior_citizen, philhealth_number, registration_date, registered_by) VALUES
(1, 'Roberto',  'Cruz',     'Dela Rosa', '1978-04-12', 'Male',   'Married', '09171112233', NULL,                       'Blk 10 Lot 3 Sitio Malaya', 'Molino VI', 'Bacoor City', 'Cavite', '4102', 'Head',   'O+', 0, 'PH-10001234', '2023-01-10', 4),
(1, 'Lourdes',  'Santos',   'Dela Rosa', '1982-09-25', 'Female', 'Married', '09182223344', NULL,                       'Blk 10 Lot 3 Sitio Malaya', 'Molino VI', 'Bacoor City', 'Cavite', '4102', 'Spouse', 'A+', 0, 'PH-10001235', '2023-01-10', 4),
(1, 'Miguel',   NULL,       'Dela Rosa', '2010-06-15', 'Male',   'Single',  NULL,          NULL,                       'Blk 10 Lot 3 Sitio Malaya', 'Molino VI', 'Bacoor City', 'Cavite', '4102', 'Child',  'O+', 0, NULL,          '2023-01-10', 4),
(1, 'Sofia',    NULL,       'Dela Rosa', '2015-02-28', 'Female', 'Single',  NULL,          NULL,                       'Blk 10 Lot 3 Sitio Malaya', 'Molino VI', 'Bacoor City', 'Cavite', '4102', 'Child',  'A+', 0, NULL,          '2023-01-10', 4),
(2, 'Pedro',    'Reyes',    'Gonzales',  '1955-11-03', 'Male',   'Married', '09193334455', 'pedro.gonzales@email.com', 'Blk 4 Lot 12 Purok 2',      'Molino VI', 'Bacoor City', 'Cavite', '4102', 'Head',   'B+', 1, 'PH-20002345', '2023-03-22', 4),
(2, 'Carmen',   'Flores',   'Gonzales',  '1958-07-19', 'Female', 'Married', '09204445566', NULL,                       'Blk 4 Lot 12 Purok 2',      'Molino VI', 'Bacoor City', 'Cavite', '4102', 'Spouse', 'O-', 1, 'PH-20002346', '2023-03-22', 4),
(3, 'Kristine', 'Luna',     'Ramos',     '1995-08-30', 'Female', 'Single',  '09215556677', 'kristine.ramos@email.com', '123 Sampaguita St.',        'Molino VI', 'Bacoor City', 'Cavite', '4102', 'Head',   'AB+',0, 'PH-30003456', '2024-01-05', 4),
(4, 'Baby',     NULL,       'Aquino',    '2024-03-10', 'Male',   'Single',  NULL,          NULL,                       'Blk 8 Lot 6 Sitio Bagong Pag-asa', 'Molino VI', 'Bacoor City', 'Cavite', '4102', 'Child', 'Unknown', 0, NULL, '2024-07-18', 4);

-- Update household heads
UPDATE Family SET household_head_id = 1 WHERE family_id = 1;
UPDATE Family SET household_head_id = 5 WHERE family_id = 2;
UPDATE Family SET household_head_id = 7 WHERE family_id = 3;

-- Sample Appointments
INSERT INTO Appointment (patient_id, nurse_id, appointment_date, appointment_time, appointment_type, reason_for_visit, status, created_by) VALUES
(1, 1, '2026-05-05', '08:30:00', 'Consultation',  'High blood pressure follow-up',    'Completed',  4),
(2, 2, '2026-05-05', '09:00:00', 'Prenatal',      'First prenatal check-up',          'Completed',  4),
(3, 1, '2026-05-10', '10:00:00', 'Immunization',  'Regular immunization schedule',    'Completed',  4),
(5, 1, '2026-05-12', '08:00:00', 'Consultation',  'Diabetes and BP management',       'Completed',  4),
(7, 2, '2026-05-20', '14:00:00', 'Consultation',  'Routine health check',             'Scheduled',  4),
(8, 2, '2026-05-22', '09:30:00', 'Vaccination',   'BCG and Hep B birth dose',         'Completed',  4),
(3, 1, '2026-06-10', '10:00:00', 'Immunization',  '2nd dose Pentavalent',             'Scheduled',  4);

-- Sample Vaccine Records
INSERT INTO Vaccine_record (patient_id, vaccine_id, appointment_id, administered_by, dose_number, date_administered, lot_number, site_of_injection, is_complete) VALUES
(3, 3,  3, 2, 1, '2026-05-10', 'LOT-PV-001', 'Left Thigh',    0),
(3, 4,  3, 2, 1, '2026-05-10', 'LOT-OP-001', NULL,            0),
(8, 1,  6, 3, 1, '2026-05-22', 'LOT-BC-001', 'Left Arm',      1),
(8, 2,  6, 3, 1, '2026-05-22', 'LOT-HB-001', 'Right Thigh',   1),
(5, 9,  4, 2, 1, '2026-05-12', 'LOT-FL-001', 'Right Deltoid', 1),
(1, 9,  1, 2, 1, '2026-05-05', 'LOT-FL-001', 'Left Deltoid',  1),
(7, 11, NULL, 3, 1, '2024-02-15', 'LOT-HP-001', 'Right Deltoid', 0);

-- Sample History Records
INSERT INTO History (patient_id, recorded_by, record_date, chief_complaint, smoking_status, alcohol_use,
    family_hx_hypertension, family_hx_diabetes, chronic_conditions, others) VALUES
(1, 2, '2026-05-05', 'Persistent headache and dizziness', 'Former smoker', 'Occasional',
    1, 0, 'Hypertension (Stage 2)', 'Sleep: 6-7 hrs/night, mild insomnia. Skin care: dry skin on extremities. No open wounds.'),
(5, 2, '2026-05-12', 'Elevated blood glucose, fatigue', 'Non-smoker', 'None',
    1, 1, 'Type 2 Diabetes Mellitus; Hypertension', 'Sleep: 7-8 hrs. Skin: intact, no lesions. No wounds noted.');

-- Sample Physical Assessments
INSERT INTO Physical_assessment (patient_id, appointment_id, assessed_by, assessment_date,
    temperature_celsius, pulse_rate_bpm, respiratory_rate_bpm, bp_systolic_mmhg, bp_diastolic_mmhg,
    oxygen_saturation_pct, weight_kg, height_cm, bmi, general_appearance, others) VALUES
(1, 1, 2, '2026-05-05 08:35:00',
    36.8, 88, 18, 155, 95, 97.00, 72.0, 165.0, 27.98,
    'Conscious, coherent, ambulatory, in no acute distress',
    'Orientation: Oriented to person, place, time. Skin turgor: slightly reduced. Mucous membranes: dry. Peripheral sounds: clear bilaterally. No NVD. No sputum production.'),
(5, 4, 2, '2026-05-12 08:10:00',
    36.5, 78, 16, 148, 92, 98.00, 68.5, 158.0, 27.46,
    'Elderly male, conscious, cooperative, slightly pale',
    'Orientation: fully oriented. Skin turgor: decreased (elderly). Mucous membranes: dry. Peripheral sounds: clear. No NVD. No sputum.');

-- Sample Prescriptions
INSERT INTO Prescription (patient_id, appointment_id, medication_id, prescribed_by, prescription_date, dosage_instructions, quantity_dispensed, duration_days, status) VALUES
(1, 1, 3,  5, '2026-05-05', 'Amlodipine 5mg once daily in the morning',    30, 30, 'Active'),
(5, 4, 3,  5, '2026-05-12', 'Amlodipine 5mg once daily',                   30, 30, 'Active'),
(5, 4, 4,  5, '2026-05-12', 'Metformin 500mg twice daily with meals',       60, 30, 'Active');

-- Sample Admission
INSERT INTO Admission_data (patient_id, admitted_by, admission_date, admission_reason, admission_status, ward_bed_number) VALUES
(1, 2, '2025-12-01 14:00:00', 'Hypertensive emergency; BP 180/110 at triage', 'Discharged', 'Bed A-3');

UPDATE Admission_data SET discharge_date = '2025-12-03 10:00:00',
    discharge_summary = 'Patient stabilized. BP reduced to 135/85. Prescribed Amlodipine. Advised lifestyle changes.'
WHERE admission_id = 1;


-- =============================================================================
-- SECTION 3: STORED PROCEDURES
-- =============================================================================

DELIMITER $$

-- -----------------------------------------------------------------------------
-- SP 1: Register a New Family Unit with a Head Patient
-- Wraps family + patient creation in a single transaction.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_register_family_unit (
    -- Family parameters
    IN  p_family_name           VARCHAR(200),
    IN  p_address_line1         VARCHAR(255),
    IN  p_address_line2         VARCHAR(255),
    IN  p_barangay              VARCHAR(100),
    IN  p_municipality          VARCHAR(100),
    IN  p_province              VARCHAR(100),
    IN  p_zip_code              CHAR(4),
    IN  p_is_4ps                TINYINT(1),

    -- Head-of-household patient parameters
    IN  p_first_name            VARCHAR(100),
    IN  p_middle_name           VARCHAR(100),
    IN  p_last_name             VARCHAR(100),
    IN  p_date_of_birth         DATE,
    IN  p_sex                   VARCHAR(10),
    IN  p_civil_status          VARCHAR(20),
    IN  p_contact_number        VARCHAR(20),
    IN  p_email                 VARCHAR(150),
    IN  p_blood_type            VARCHAR(5),
    IN  p_philhealth_number     VARCHAR(30),
    IN  p_registered_by         INT UNSIGNED,

    -- Output
    OUT p_family_id             INT UNSIGNED,
    OUT p_patient_id            INT UNSIGNED,
    OUT p_result_message        VARCHAR(255)
)
BEGIN
    DECLARE v_family_id     INT UNSIGNED DEFAULT 0;
    DECLARE v_patient_id    INT UNSIGNED DEFAULT 0;
    DECLARE v_error_state   INT DEFAULT 0;
    DECLARE v_error_msg     TEXT DEFAULT '';

    -- Error handler: set flag and rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET v_error_state = 1;
        ROLLBACK;
        SET p_family_id      = 0;
        SET p_patient_id     = 0;
        SET p_result_message = CONCAT('ERROR: ', v_error_msg);
    END;

    START TRANSACTION;

    -- Step 1: Insert the family record (no head yet)
    INSERT INTO Family (family_name, address_line1, address_line2, barangay,
                        municipality, province, zip_code, is_4ps_beneficiary, date_registered)
    VALUES (p_family_name, p_address_line1, p_address_line2, p_barangay,
            p_municipality, p_province, p_zip_code, p_is_4ps, CURRENT_DATE);

    SET v_family_id = LAST_INSERT_ID();

    -- Step 2: Insert the head-of-household patient
    INSERT INTO Patient (family_id, first_name, middle_name, last_name, date_of_birth,
                         sex, civil_status, contact_number, email, address_line1,
                         barangay, municipality, province, zip_code,
                         relationship_to_head, blood_type, philhealth_number,
                         registration_date, registered_by)
    VALUES (v_family_id, p_first_name, p_middle_name, p_last_name, p_date_of_birth,
            p_sex, p_civil_status, p_contact_number, p_email, p_address_line1,
            p_barangay, p_municipality, p_province, p_zip_code,
            'Head', p_blood_type, p_philhealth_number, CURRENT_DATE, p_registered_by);

    SET v_patient_id = LAST_INSERT_ID();

    -- Step 3: Update the family's household head reference
    UPDATE Family SET household_head_id = v_patient_id WHERE family_id = v_family_id;

    COMMIT;

    -- Return output values
    SET p_family_id      = v_family_id;
    SET p_patient_id     = v_patient_id;
    SET p_result_message = CONCAT('SUCCESS: Family ID ', v_family_id,
                                   ' and Patient ID ', v_patient_id, ' created.');
END$$


-- -----------------------------------------------------------------------------
-- SP 2: Log a Vaccination Record
-- Validates dose sequence and marks series complete when appropriate.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_log_vaccination (
    IN  p_patient_id        INT UNSIGNED,
    IN  p_vaccine_id        INT UNSIGNED,
    IN  p_appointment_id    INT UNSIGNED,
    IN  p_administered_by   INT UNSIGNED,
    IN  p_dose_number       TINYINT UNSIGNED,
    IN  p_date_administered DATE,
    IN  p_lot_number        VARCHAR(50),
    IN  p_site_of_injection VARCHAR(100),
    IN  p_adverse_reaction  TEXT,

    OUT p_record_id         INT UNSIGNED,
    OUT p_result_message    VARCHAR(500)
)
BEGIN
    DECLARE v_dose_series       TINYINT UNSIGNED DEFAULT 1;
    DECLARE v_prev_dose_count   TINYINT UNSIGNED DEFAULT 0;
    DECLARE v_is_complete       TINYINT(1) DEFAULT 0;
    DECLARE v_next_due_date     DATE DEFAULT NULL;
    DECLARE v_error_msg         TEXT DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_record_id      = 0;
        SET p_result_message = CONCAT('ERROR: ', v_error_msg);
    END;

    START TRANSACTION;

    -- Validate: patient exists
    IF NOT EXISTS (SELECT 1 FROM Patient WHERE patient_id = p_patient_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Patient not found.';
    END IF;

    -- Validate: vaccine exists; get dose series
    SELECT dose_series INTO v_dose_series
    FROM Vaccine WHERE vaccine_id = p_vaccine_id;

    IF v_dose_series IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vaccine not found.';
    END IF;

    -- Validate: dose sequence (must not skip doses)
    SELECT COUNT(*) INTO v_prev_dose_count
    FROM Vaccine_record
    WHERE patient_id = p_patient_id AND vaccine_id = p_vaccine_id;

    IF p_dose_number != (v_prev_dose_count + 1) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Dose number is out of sequence for this patient and vaccine.';
    END IF;

    -- Determine if the series is now complete
    IF p_dose_number >= v_dose_series THEN
        SET v_is_complete   = 1;
        SET v_next_due_date = NULL;
    ELSE
        -- Simple rule: next dose ~4 weeks later (real schedules vary by vaccine)
        SET v_next_due_date = DATE_ADD(p_date_administered, INTERVAL 4 WEEK);
    END IF;

    -- Insert the vaccine record
    INSERT INTO Vaccine_record (patient_id, vaccine_id, appointment_id, administered_by,
                                dose_number, date_administered, lot_number,
                                site_of_injection, next_due_date, adverse_reaction, is_complete)
    VALUES (p_patient_id, p_vaccine_id, p_appointment_id, p_administered_by,
            p_dose_number, p_date_administered, p_lot_number,
            p_site_of_injection, v_next_due_date, p_adverse_reaction, v_is_complete);

    SET p_record_id = LAST_INSERT_ID();

    -- If series complete and next dose notification exists, skip; else notify
    IF v_is_complete = 0 THEN
        INSERT INTO Notification (notification_type_id, recipient_user_id, patient_id, message, priority)
        SELECT 2, p_administered_by, p_patient_id,
               CONCAT('Vaccination reminder: Next dose (Dose ', p_dose_number + 1, ') for vaccine ',
                      (SELECT vaccine_name FROM Vaccine WHERE vaccine_id = p_vaccine_id),
                      ' due on ', v_next_due_date, '.'),
               'Normal';
    END IF;

    COMMIT;

    SET p_result_message = CONCAT('SUCCESS: Vaccine record ID ', p_record_id,
                                   '. Series complete: ', IF(v_is_complete, 'YES', 'NO'),
                                   IF(v_next_due_date IS NOT NULL,
                                      CONCAT('. Next dose due: ', v_next_due_date), '.'));
END$$


-- -----------------------------------------------------------------------------
-- SP 3: Schedule an Appointment with Conflict Check
-- Ensures no double-booking for a nurse at the same date/time.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_schedule_appointment (
    IN  p_patient_id        INT UNSIGNED,
    IN  p_nurse_id          INT UNSIGNED,
    IN  p_appointment_date  DATE,
    IN  p_appointment_time  TIME,
    IN  p_appointment_type  VARCHAR(50),
    IN  p_reason            TEXT,
    IN  p_created_by        INT UNSIGNED,

    OUT p_appointment_id    INT UNSIGNED,
    OUT p_result_message    VARCHAR(255)
)
BEGIN
    DECLARE v_conflict_count    INT DEFAULT 0;
    DECLARE v_error_msg         TEXT DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_appointment_id = 0;
        SET p_result_message = CONCAT('ERROR: ', v_error_msg);
    END;

    START TRANSACTION;

    -- Check for nurse scheduling conflict (within 30-minute buffer)
    SELECT COUNT(*) INTO v_conflict_count
    FROM Appointment
    WHERE nurse_id          = p_nurse_id
      AND appointment_date  = p_appointment_date
      AND status NOT IN    ('Cancelled','No-Show')
      AND ABS(TIMESTAMPDIFF(MINUTE,
              ADDTIME(p_appointment_date, p_appointment_time),
              ADDTIME(appointment_date,   appointment_time))) < 30;

    IF v_conflict_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Scheduling conflict: nurse has an overlapping appointment within 30 minutes.';
    END IF;

    INSERT INTO Appointment (patient_id, nurse_id, appointment_date, appointment_time,
                             appointment_type, reason_for_visit, status, created_by)
    VALUES (p_patient_id, p_nurse_id, p_appointment_date, p_appointment_time,
            p_appointment_type, p_reason, 'Scheduled', p_created_by);

    SET p_appointment_id = LAST_INSERT_ID();

    COMMIT;

    SET p_result_message = CONCAT('SUCCESS: Appointment ID ', p_appointment_id, ' scheduled for ',
                                   p_appointment_date, ' at ', p_appointment_time, '.');
END$$


DELIMITER ;


-- =============================================================================
-- SECTION 4: TRIGGERS
-- =============================================================================

DELIMITER $$

-- -----------------------------------------------------------------------------
-- TRIGGER 1: After Appointment Update → Update Patient Status & Audit Log
-- When an appointment is marked 'Completed', ensure patient is 'Active'.
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_after_appointment_update
AFTER UPDATE ON Appointment
FOR EACH ROW
BEGIN
    -- Update patient to Active when appointment is completed
    IF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
        UPDATE Patient
        SET patient_status = 'Active', updated_at = CURRENT_TIMESTAMP
        WHERE patient_id = NEW.patient_id
          AND patient_status != 'Active';

        -- Dispatch a notification to the nurse who handled the appointment
        IF NEW.nurse_id IS NOT NULL THEN
            INSERT INTO Notification (notification_type_id, recipient_user_id, patient_id,
                                      message, priority)
            VALUES (4,
                    (SELECT user_id FROM Nurse WHERE nurse_id = NEW.nurse_id),
                    NEW.patient_id,
                    CONCAT('Appointment ID ', NEW.appointment_id, ' marked as Completed. ',
                           'Patient record has been set to Active.'),
                    'Normal');
        END IF;
    END IF;

    -- Write audit log
    INSERT INTO Audit_log (table_name, record_id, action, changed_by,
                           old_values_json, new_values_json, notes)
    VALUES ('Appointment', NEW.appointment_id, 'UPDATE', NEW.created_by,
            JSON_OBJECT('status', OLD.status, 'nurse_id', OLD.nurse_id),
            JSON_OBJECT('status', NEW.status, 'nurse_id', NEW.nurse_id),
            'Appointment status changed via system.');
END$$


-- -----------------------------------------------------------------------------
-- TRIGGER 2: After Insert on Vaccine_record → Audit Log + Low-Stock Check
-- Logs every vaccination and checks if it was the last AEFI-free dose.
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_after_vaccine_record_insert
AFTER INSERT ON Vaccine_record
FOR EACH ROW
BEGIN
    -- Audit log entry
    INSERT INTO Audit_log (table_name, record_id, action, changed_by, new_values_json, notes)
    VALUES ('Vaccine_record', NEW.vaccine_record_id, 'INSERT', NEW.administered_by,
            JSON_OBJECT(
                'patient_id',       NEW.patient_id,
                'vaccine_id',       NEW.vaccine_id,
                'dose_number',      NEW.dose_number,
                'date_administered',NEW.date_administered,
                'is_complete',      NEW.is_complete
            ),
            'New vaccination record created.');

    -- If adverse reaction recorded, notify admin immediately
    IF NEW.adverse_reaction IS NOT NULL AND NEW.adverse_reaction != '' THEN
        INSERT INTO Notification (notification_type_id, recipient_user_id, patient_id,
                                  message, priority)
        SELECT 6,          -- System Alert
               u.user_id,
               NEW.patient_id,
               CONCAT('AEFI REPORTED: Patient ID ', NEW.patient_id,
                      ' had an adverse reaction after receiving vaccine ID ',
                      NEW.vaccine_id, ' (Dose ', NEW.dose_number, '). Reaction: ',
                      LEFT(NEW.adverse_reaction, 200)),
               'Urgent'
        FROM Users u WHERE u.role = 'Admin' AND u.is_active = 1;
    END IF;
END$$


-- -----------------------------------------------------------------------------
-- TRIGGER 3: Before Update on Medication → Enforce Non-Negative Stock
-- Prevents stock from going below zero via direct UPDATE statements.
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_before_medication_update
BEFORE UPDATE ON Medication
FOR EACH ROW
BEGIN
    IF NEW.stock_quantity < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock quantity cannot be negative. Update rejected.';
    END IF;

    -- Auto-notify if stock drops to or below reorder level
    IF NEW.stock_quantity <= NEW.reorder_level
       AND OLD.stock_quantity > OLD.reorder_level THEN
        INSERT INTO Notification (notification_type_id, recipient_user_id, patient_id,
                                  message, priority)
        SELECT 3,          -- Low Stock Alert
               u.user_id,
               NULL,
               CONCAT('LOW STOCK ALERT: ', NEW.medication_name,
                      ' stock is at ', NEW.stock_quantity, ' units (reorder level: ',
                      NEW.reorder_level, '). Please replenish.'),
               'High'
        FROM Users u WHERE u.role IN ('Admin','Nurse') AND u.is_active = 1;
    END IF;
END$$


-- -----------------------------------------------------------------------------
-- TRIGGER 4: After Insert on Patient → Audit Log
-- Records every new patient registration in the audit trail.
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_after_patient_insert
AFTER INSERT ON Patient
FOR EACH ROW
BEGIN
    INSERT INTO Audit_log (table_name, record_id, action, changed_by, new_values_json, notes)
    VALUES ('Patient', NEW.patient_id, 'INSERT', NEW.registered_by,
            JSON_OBJECT(
                'first_name',    NEW.first_name,
                'last_name',     NEW.last_name,
                'date_of_birth', NEW.date_of_birth,
                'family_id',     NEW.family_id,
                'sex',           NEW.sex
            ),
            'New patient registered.');
END$$


DELIMITER ;


-- =============================================================================
-- SECTION 5: TRANSACTION MANAGEMENT (ACID Demonstration)
-- Scenario: Record a complete patient visit — appointment completion,
--            physical assessment, prescription, and audit entry — atomically.
-- =============================================================================

START TRANSACTION;

SAVEPOINT sp_before_visit_record;

-- Step 1: Mark appointment as Completed
UPDATE Appointment
SET status     = 'Completed',
    updated_at = CURRENT_TIMESTAMP
WHERE appointment_id = 5
  AND status = 'Scheduled';

-- Verify update affected exactly 1 row (application layer would check ROW_COUNT())

-- Step 2: Insert physical assessment for this visit
INSERT INTO Physical_assessment (patient_id, appointment_id, assessed_by, assessment_date,
    temperature_celsius, pulse_rate_bpm, respiratory_rate_bpm,
    bp_systolic_mmhg, bp_diastolic_mmhg, oxygen_saturation_pct,
    weight_kg, height_cm, bmi, general_appearance, others)
VALUES (7, 5, 3, NOW(),
    36.6, 80, 18, 120, 78, 98.5,
    55.0, 155.0, 22.89,
    'Young adult female, conscious, cooperative, well-nourished',
    'Orientation: oriented x3. Skin turgor: good. Mucous membranes: moist. Peripheral sounds: clear. No NVD. No sputum.');

-- Step 3: Prescribe medication
INSERT INTO Prescription (patient_id, appointment_id, medication_id, prescribed_by,
    prescription_date, dosage_instructions, quantity_dispensed, duration_days, status)
VALUES (7, 5, 1, 5, CURRENT_DATE, 'Paracetamol 500mg every 6 hours as needed for fever', 12, 3, 'Active');

-- Step 4: Deduct medication stock (triggers trg_before_medication_update)
UPDATE Medication
SET stock_quantity = stock_quantity - 12
WHERE medication_id = 1;

-- Step 5: Write a manual audit entry for this transaction block
INSERT INTO Audit_log (table_name, record_id, action, changed_by, new_values_json, notes)
VALUES ('Appointment', 5, 'UPDATE', 3,
        JSON_OBJECT('status','Completed','patient_id', 7),
        'Complete patient visit transaction: assessment, prescription, and stock update applied atomically.');

-- If all steps succeed → COMMIT
COMMIT;

-- On failure anywhere, the application layer executes:
-- ROLLBACK TO SAVEPOINT sp_before_visit_record;
-- ROLLBACK;


-- =============================================================================
-- SECTION 6: SECURITY — ROLES & PRIVILEGES
-- =============================================================================

-- Drop roles if they already exist (for re-runnable scripts)
DROP ROLE IF EXISTS 'bhc_admin'@'%';
DROP ROLE IF EXISTS 'bhc_staff'@'%';
DROP ROLE IF EXISTS 'bhc_readonly'@'%';

-- Create roles
CREATE ROLE 'bhc_admin'@'%';   -- Full administrative access
CREATE ROLE 'bhc_staff'@'%';   -- Operational nursing/encoder access
CREATE ROLE 'bhc_readonly'@'%';-- Read-only access for reporting

-- -----------------------------------------------------------------------
-- Admin Role: full control over all tables, procedures, and DDL
-- -----------------------------------------------------------------------
GRANT ALL PRIVILEGES ON molino_vi_hcms.* TO 'bhc_admin'@'%' WITH GRANT OPTION;

-- -----------------------------------------------------------------------
-- Staff Role: DML on clinical/operational tables; cannot touch audit log
--             or modify user accounts (only read their own profile)
-- -----------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON molino_vi_hcms.Patient             TO 'bhc_staff'@'%';
GRANT SELECT, INSERT, UPDATE ON molino_vi_hcms.Family              TO 'bhc_staff'@'%';
GRANT SELECT, INSERT, UPDATE ON molino_vi_hcms.Appointment         TO 'bhc_staff'@'%';
GRANT SELECT, INSERT, UPDATE ON molino_vi_hcms.History             TO 'bhc_staff'@'%';
GRANT SELECT, INSERT, UPDATE ON molino_vi_hcms.Physical_assessment TO 'bhc_staff'@'%';
GRANT SELECT, INSERT, UPDATE ON molino_vi_hcms.Admission_data      TO 'bhc_staff'@'%';
GRANT SELECT, INSERT, UPDATE ON molino_vi_hcms.Vaccine_record      TO 'bhc_staff'@'%';
GRANT SELECT, INSERT, UPDATE ON molino_vi_hcms.Prescription        TO 'bhc_staff'@'%';
GRANT SELECT, INSERT         ON molino_vi_hcms.Notification        TO 'bhc_staff'@'%';
GRANT SELECT                 ON molino_vi_hcms.Notification_type   TO 'bhc_staff'@'%';
GRANT SELECT                 ON molino_vi_hcms.Vaccine             TO 'bhc_staff'@'%';
GRANT SELECT, UPDATE         ON molino_vi_hcms.Medication          TO 'bhc_staff'@'%';
GRANT SELECT                 ON molino_vi_hcms.Nurse               TO 'bhc_staff'@'%';
GRANT SELECT                 ON molino_vi_hcms.Report              TO 'bhc_staff'@'%';
GRANT SELECT                 ON molino_vi_hcms.Users               TO 'bhc_staff'@'%';

-- Staff can EXECUTE operational stored procedures
GRANT EXECUTE ON PROCEDURE molino_vi_hcms.sp_log_vaccination       TO 'bhc_staff'@'%';
GRANT EXECUTE ON PROCEDURE molino_vi_hcms.sp_schedule_appointment  TO 'bhc_staff'@'%';
GRANT EXECUTE ON PROCEDURE molino_vi_hcms.sp_register_family_unit  TO 'bhc_staff'@'%';

-- Staff explicitly CANNOT access or modify:
-- (No grant was given for Audit_log, so they implicitly have no access. Revoke is unnecessary).
-- REVOKE INSERT, UPDATE, DELETE ON molino_vi_hcms.Audit_log FROM 'bhc_staff'@'%';

-- -----------------------------------------------------------------------
-- Read-Only Role: SELECT only, used by reporting tools / view-only accounts
-- -----------------------------------------------------------------------
GRANT SELECT ON molino_vi_hcms.Patient             TO 'bhc_readonly'@'%';
GRANT SELECT ON molino_vi_hcms.Family              TO 'bhc_readonly'@'%';
GRANT SELECT ON molino_vi_hcms.Appointment         TO 'bhc_readonly'@'%';
GRANT SELECT ON molino_vi_hcms.Vaccine_record      TO 'bhc_readonly'@'%';
GRANT SELECT ON molino_vi_hcms.Vaccine             TO 'bhc_readonly'@'%';
GRANT SELECT ON molino_vi_hcms.Prescription        TO 'bhc_readonly'@'%';
GRANT SELECT ON molino_vi_hcms.Medication          TO 'bhc_readonly'@'%';
GRANT SELECT ON molino_vi_hcms.Report              TO 'bhc_readonly'@'%';
GRANT SELECT ON molino_vi_hcms.History             TO 'bhc_readonly'@'%';
GRANT SELECT ON molino_vi_hcms.Physical_assessment TO 'bhc_readonly'@'%';
GRANT SELECT ON molino_vi_hcms.Admission_data      TO 'bhc_readonly'@'%';
GRANT SELECT ON molino_vi_hcms.Nurse               TO 'bhc_readonly'@'%';

-- Explicitly DENY writes and sensitive tables for readonly
-- (Implicitly denied because no GRANT was issued for Users or Audit_log)
-- REVOKE ALL ON molino_vi_hcms.Users      FROM 'bhc_readonly'@'%';
-- REVOKE ALL ON molino_vi_hcms.Audit_log  FROM 'bhc_readonly'@'%';

-- -----------------------------------------------------------------------
-- Create application-level database users and assign roles
-- -----------------------------------------------------------------------
DROP USER IF EXISTS 'hcms_admin_user'@'localhost';
DROP USER IF EXISTS 'hcms_staff_user'@'localhost';
DROP USER IF EXISTS 'hcms_viewer_user'@'localhost';

CREATE USER 'hcms_admin_user'@'localhost'  IDENTIFIED BY 'AdminSecure@2026!';
CREATE USER 'hcms_staff_user'@'localhost'  IDENTIFIED BY 'StaffSecure@2026!';
CREATE USER 'hcms_viewer_user'@'localhost' IDENTIFIED BY 'ViewerSecure@2026!';

GRANT 'bhc_admin'@'%'    TO 'hcms_admin_user'@'localhost';
GRANT 'bhc_staff'@'%'    TO 'hcms_staff_user'@'localhost';
GRANT 'bhc_readonly'@'%' TO 'hcms_viewer_user'@'localhost';

-- Set default roles (auto-activated on login)
SET DEFAULT ROLE 'bhc_admin'@'%'    TO 'hcms_admin_user'@'localhost';
SET DEFAULT ROLE 'bhc_staff'@'%'    TO 'hcms_staff_user'@'localhost';
SET DEFAULT ROLE 'bhc_readonly'@'%' TO 'hcms_viewer_user'@'localhost';

FLUSH PRIVILEGES;


-- =============================================================================
-- SECTION 7: COMPLEX REPORTING QUERIES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- QUERY 1: Healthcare Utilization by Family
-- Shows how many appointments, vaccinations, and prescriptions each household
-- has had, ranked by total utilization — useful for community prioritization.
-- -----------------------------------------------------------------------------
WITH family_appointments AS (
    SELECT
        p.family_id,
        COUNT(a.appointment_id)     AS total_appointments,
        COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) AS completed_appointments
    FROM Patient p
    LEFT JOIN Appointment a ON a.patient_id = p.patient_id
    GROUP BY p.family_id
),
family_vaccinations AS (
    SELECT
        p.family_id,
        COUNT(vr.vaccine_record_id) AS total_doses,
        COUNT(DISTINCT vr.patient_id) AS vaccinated_members
    FROM Patient p
    LEFT JOIN Vaccine_record vr ON vr.patient_id = p.patient_id
    GROUP BY p.family_id
),
family_prescriptions AS (
    SELECT
        p.family_id,
        COUNT(rx.prescription_id) AS total_prescriptions
    FROM Patient p
    LEFT JOIN Prescription rx ON rx.patient_id = p.patient_id
    GROUP BY p.family_id
),
family_size AS (
    SELECT family_id, COUNT(*) AS member_count
    FROM Patient
    GROUP BY family_id
)
SELECT
    f.family_id,
    f.family_name,
    f.address_line1,
    f.is_4ps_beneficiary,
    fs.member_count,
    COALESCE(fa.total_appointments, 0)      AS total_appointments,
    COALESCE(fa.completed_appointments, 0)  AS completed_appointments,
    COALESCE(fv.total_doses, 0)             AS total_vaccine_doses,
    COALESCE(fv.vaccinated_members, 0)      AS vaccinated_members,
    COALESCE(fp.total_prescriptions, 0)     AS total_prescriptions,
    -- Utilization score: sum of major health events
    (COALESCE(fa.total_appointments, 0)
     + COALESCE(fv.total_doses, 0)
     + COALESCE(fp.total_prescriptions, 0)) AS utilization_score
FROM Family f
LEFT JOIN family_size        fs ON fs.family_id = f.family_id
LEFT JOIN family_appointments fa ON fa.family_id = f.family_id
LEFT JOIN family_vaccinations fv ON fv.family_id = f.family_id
LEFT JOIN family_prescriptions fp ON fp.family_id = f.family_id
ORDER BY utilization_score DESC;


-- -----------------------------------------------------------------------------
-- QUERY 2: Vaccination Coverage Rate by Vaccine
-- Compares how many registered patients have received each vaccine
-- vs. total active patient population.
-- -----------------------------------------------------------------------------
SELECT
    v.vaccine_name,
    v.target_disease,
    v.dose_series                                               AS doses_required,
    COUNT(DISTINCT vr.patient_id)                               AS patients_with_at_least_1_dose,
    COUNT(DISTINCT CASE WHEN vr.is_complete = 1
          THEN vr.patient_id END)                               AS fully_vaccinated_patients,
    (SELECT COUNT(*) FROM Patient WHERE patient_status = 'Active') AS total_active_patients,
    ROUND(
        COUNT(DISTINCT vr.patient_id) * 100.0
        / NULLIF((SELECT COUNT(*) FROM Patient WHERE patient_status = 'Active'), 0),
        2
    )                                                           AS coverage_pct_at_least_1_dose,
    ROUND(
        COUNT(DISTINCT CASE WHEN vr.is_complete = 1
              THEN vr.patient_id END) * 100.0
        / NULLIF((SELECT COUNT(*) FROM Patient WHERE patient_status = 'Active'), 0),
        2
    )                                                           AS full_coverage_pct
FROM Vaccine v
LEFT JOIN Vaccine_record vr ON vr.vaccine_id = v.vaccine_id
WHERE v.is_active = 1
GROUP BY v.vaccine_id, v.vaccine_name, v.target_disease, v.dose_series
ORDER BY full_coverage_pct DESC, patients_with_at_least_1_dose DESC;


-- -----------------------------------------------------------------------------
-- QUERY 3: Non-Communicable Disease (NCD) & Lifestyle Risk Registry
-- Identifies active patients diagnosed with chronic conditions and cross-references
-- their lifestyle risks (smoking, alcohol) and hereditary disease history.
-- This is highly necessary for targeted intervention and monitoring programs.
-- -----------------------------------------------------------------------------
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', IFNULL(CONCAT(p.middle_name, ' '), ''), p.last_name) AS patient_name,
    TIMESTAMPDIFF(YEAR, p.date_of_birth, CURRENT_DATE) AS age,
    p.sex,
    f.address_line1 AS household_address,
    h.chronic_conditions,
    h.smoking_status,
    h.alcohol_use,
    CONCAT_WS(', ',
        NULLIF(IF(h.family_hx_hypertension = 1, 'Hypertension', ''), ''),
        NULLIF(IF(h.family_hx_diabetes = 1, 'Diabetes', ''), ''),
        NULLIF(IF(h.family_hx_asthma = 1, 'Asthma', ''), ''),
        NULLIF(IF(h.family_hx_cancer = 1, 'Cancer', ''), '')
    ) AS hereditary_risks,
    h.record_date AS last_history_update
FROM History h
JOIN Patient p ON p.patient_id = h.patient_id
LEFT JOIN Family f ON f.family_id = p.family_id
WHERE h.chronic_conditions IS NOT NULL
  AND h.chronic_conditions != ''
  AND p.patient_status = 'Active'
  AND h.history_id = (
      -- Ensure we only pull the most recent history record per patient
      SELECT MAX(history_id)
      FROM History h2
      WHERE h2.patient_id = h.patient_id
  )
ORDER BY age DESC, p.last_name;


-- -----------------------------------------------------------------------------
-- QUERY 4: Monthly Appointment and Visit Summary Report
-- Aggregates appointment counts by type and status for the last 6 months.
-- Useful for DOH monthly reporting.
-- -----------------------------------------------------------------------------
SELECT
    DATE_FORMAT(a.appointment_date, '%Y-%m')        AS report_month,
    a.appointment_type,
    COUNT(*)                                         AS total_appointments,
    COUNT(CASE WHEN a.status = 'Completed'   THEN 1 END) AS completed,
    COUNT(CASE WHEN a.status = 'Cancelled'   THEN 1 END) AS cancelled,
    COUNT(CASE WHEN a.status = 'No-Show'     THEN 1 END) AS no_show,
    COUNT(CASE WHEN a.status = 'Scheduled'   THEN 1 END) AS still_scheduled,
    COUNT(DISTINCT a.patient_id)                     AS unique_patients,
    ROUND(
        COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 100.0
        / NULLIF(COUNT(*), 0),
        1
    )                                                AS completion_rate_pct
FROM Appointment a
WHERE a.appointment_date >= DATE_SUB(CURRENT_DATE, INTERVAL 6 MONTH)
GROUP BY report_month, a.appointment_type
ORDER BY report_month DESC, total_appointments DESC;


-- -----------------------------------------------------------------------------
-- QUERY 5: Senior Citizens and PWD with Chronic Conditions
-- Identifies vulnerable patients who need priority health monitoring,
-- along with their latest BP reading from physical assessments.
-- -----------------------------------------------------------------------------
WITH latest_assessment AS (
    SELECT
        pa.patient_id,
        pa.bp_systolic_mmhg,
        pa.bp_diastolic_mmhg,
        pa.assessment_date,
        ROW_NUMBER() OVER (PARTITION BY pa.patient_id
                           ORDER BY pa.assessment_date DESC) AS rn
    FROM Physical_assessment pa
    WHERE pa.bp_systolic_mmhg IS NOT NULL
),
patient_prescription_count AS (
    SELECT patient_id, COUNT(*) AS active_rx_count
    FROM Prescription
    WHERE status = 'Active'
    GROUP BY patient_id
)
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name)          AS patient_name,
    TIMESTAMPDIFF(YEAR, p.date_of_birth, CURRENT_DATE) AS age,
    p.sex,
    p.contact_number,
    f.family_name,
    f.address_line1,
    p.is_senior_citizen,
    p.is_pwd,
    p.is_pregnant,
    p.blood_type,
    h.chronic_conditions,
    h.known_allergies,
    CONCAT(la.bp_systolic_mmhg, '/', la.bp_diastolic_mmhg, ' mmHg')
                                                     AS latest_bp,
    la.assessment_date                               AS last_assessed,
    COALESCE(prc.active_rx_count, 0)                 AS active_prescriptions
FROM Patient p
LEFT JOIN Family f ON f.family_id = p.family_id
-- Changed to JOIN to strictly require a medical history record
JOIN History h ON h.patient_id = p.patient_id
LEFT JOIN latest_assessment la ON la.patient_id = p.patient_id AND la.rn = 1
LEFT JOIN patient_prescription_count prc ON prc.patient_id = p.patient_id
WHERE (p.is_senior_citizen = 1 OR p.is_pwd = 1 OR p.is_pregnant = 1)
  AND p.patient_status = 'Active'
  -- Added filter to completely exclude patients without chronic conditions
  AND h.chronic_conditions IS NOT NULL 
  AND h.chronic_conditions != ''
ORDER BY p.is_senior_citizen DESC, p.is_pregnant DESC, age DESC;


-- -----------------------------------------------------------------------------
-- QUERY 6: Nurse Performance and Workload Summary
-- Shows how many appointments each nurse handled, completion rate,
-- and which appointment types they served most.
-- -----------------------------------------------------------------------------
SELECT
    n.nurse_id,
    CONCAT(u.first_name, ' ', u.last_name)           AS nurse_name,
    n.prc_license_number,
    n.specialization,
    COUNT(a.appointment_id)                           AS total_appointments_handled,
    COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) AS completed,
    COUNT(CASE WHEN a.status = 'No-Show'   THEN 1 END) AS no_shows,
    COUNT(DISTINCT a.appointment_date)                AS days_worked,
    ROUND(
        COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 100.0
        / NULLIF(COUNT(a.appointment_id), 0),
        1
    )                                                 AS completion_rate_pct,
    COUNT(DISTINCT vr.vaccine_record_id)              AS vaccines_administered,
    COUNT(DISTINCT a.patient_id)                      AS unique_patients_served,
    -- Most common appointment type for this nurse
    (SELECT a2.appointment_type
     FROM Appointment a2
     WHERE a2.nurse_id = n.nurse_id
       AND a2.status   = 'Completed'
     GROUP BY a2.appointment_type
     ORDER BY COUNT(*) DESC
     LIMIT 1)                                         AS top_appointment_type
FROM Nurse n
JOIN Users u ON u.user_id = n.user_id
LEFT JOIN Appointment a
       ON a.nurse_id = n.nurse_id
      AND a.appointment_date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)
LEFT JOIN Vaccine_record vr ON vr.administered_by = u.user_id
GROUP BY n.nurse_id, nurse_name, n.prc_license_number, n.specialization
ORDER BY total_appointments_handled DESC;


-- -----------------------------------------------------------------------------
-- QUERY 7 (BONUS): Medication Inventory Alert with Utilization Rate
-- Computes average monthly consumption and forecasts when stock will run out.
-- -----------------------------------------------------------------------------
WITH monthly_usage AS (
    SELECT
        rx.medication_id,
        COUNT(*) AS prescriptions_per_month,
        SUM(rx.quantity_dispensed) AS units_dispensed_per_month
    FROM Prescription rx
    WHERE rx.prescription_date >= DATE_SUB(CURRENT_DATE, INTERVAL 1 MONTH)
    GROUP BY rx.medication_id
)
SELECT
    m.medication_id,
    m.medication_name,
    m.generic_name,
    m.category,
    m.dosage_form,
    m.stock_quantity                                  AS current_stock,
    m.reorder_level,
    COALESCE(mu.units_dispensed_per_month, 0)         AS units_used_last_30_days,
    CASE
        WHEN COALESCE(mu.units_dispensed_per_month, 0) = 0
             THEN 'No recent usage'
        ELSE CONCAT(
            ROUND(m.stock_quantity / NULLIF(mu.units_dispensed_per_month, 0), 1),
            ' months')
    END                                               AS estimated_stock_duration,
    CASE
        WHEN m.stock_quantity <= 0                   THEN 'OUT OF STOCK'
        WHEN m.stock_quantity <= m.reorder_level     THEN 'REORDER NOW'
        WHEN m.stock_quantity <= m.reorder_level * 2 THEN 'LOW — Monitor'
        ELSE 'Adequate'
    END                                               AS stock_status
FROM Medication m
LEFT JOIN monthly_usage mu ON mu.medication_id = m.medication_id
WHERE m.is_active = 1
ORDER BY
    CASE WHEN m.stock_quantity <= 0               THEN 1
         WHEN m.stock_quantity <= m.reorder_level THEN 2
         ELSE 3 END,
    m.medication_name;


-- =============================================================================
-- SECTION 8: TEST / DEMO CALLS
-- Demonstrate stored procedures and verify data integrity.
-- =============================================================================

-- Test SP 1: Register a new family unit
CALL sp_register_family_unit(
    'Villanueva Family', 'Blk 15 Lot 7 Sitio Bagumbayan', NULL,
    'Molino VI', 'Bacoor City', 'Cavite', '4102', 0,
    'Ramon', 'Abad', 'Villanueva', '1989-12-01',
    'Male', 'Married', '09221234567', NULL,
    'B+', 'PH-50005678', 4,
    @out_family_id, @out_patient_id, @out_msg
);
SELECT @out_family_id AS new_family_id, @out_patient_id AS new_patient_id, @out_msg AS result;

-- Test SP 2: Log a vaccination
CALL sp_log_vaccination(
    3, 3, 7, 2,    -- patient_id=3 (Miguel), vaccine_id=3 (Pentavalent), appointment_id=7, nurse
    2,             -- dose_number = 2 (second dose)
    '2026-06-10',  -- date_administered
    'LOT-PV-002', 'Right Thigh', NULL,
    @out_vr_id, @out_vr_msg
);
SELECT @out_vr_id AS vaccine_record_id, @out_vr_msg AS result;

-- Test SP 3: Schedule an appointment
CALL sp_schedule_appointment(
    7, 2,               -- patient_id=7 (Kristine), nurse_id=2
    '2026-07-01', '09:00:00', 'Follow-up', 'Post-consultation follow-up', 4,
    @out_appt_id, @out_appt_msg
);
SELECT @out_appt_id AS appointment_id, @out_appt_msg AS result;

-- =============================================================================
-- SECTION 9: VERIFICATION QUERIES (Quick sanity checks)
-- =============================================================================

-- Table row counts
SELECT 'Family'             AS tbl, COUNT(*) AS row_count FROM Family
UNION ALL SELECT 'Patient',          COUNT(*) FROM Patient
UNION ALL SELECT 'Users',            COUNT(*) FROM Users
UNION ALL SELECT 'Nurse',            COUNT(*) FROM Nurse
UNION ALL SELECT 'Appointment',      COUNT(*) FROM Appointment
UNION ALL SELECT 'Vaccine',          COUNT(*) FROM Vaccine
UNION ALL SELECT 'Vaccine_record',   COUNT(*) FROM Vaccine_record
UNION ALL SELECT 'Medication',       COUNT(*) FROM Medication
UNION ALL SELECT 'Prescription',     COUNT(*) FROM Prescription
UNION ALL SELECT 'History',          COUNT(*) FROM History
UNION ALL SELECT 'Physical_assessment', COUNT(*) FROM Physical_assessment
UNION ALL SELECT 'Admission_data',   COUNT(*) FROM Admission_data
UNION ALL SELECT 'Notification',     COUNT(*) FROM Notification
UNION ALL SELECT 'Audit_log',        COUNT(*) FROM Audit_log;

-- Verify all FK constraints are intact
SELECT TABLE_NAME, COLUMN_NAME, CONSTRAINT_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_SCHEMA = 'molino_vi_hcms'
ORDER BY TABLE_NAME, COLUMN_NAME;

-- =============================================================================
-- END OF SCRIPT
-- Molino VI Health Care Management System
-- =============================================================================