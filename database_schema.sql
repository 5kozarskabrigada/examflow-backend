-- ExamFlow Database Schema
-- Database tables for the ExamFlow application

-- ============================================
-- Table: Users
-- Stores teacher and student accounts
-- ============================================
CREATE TABLE IF NOT EXISTS Users (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    FullName TEXT NOT NULL,
    Email TEXT NOT NULL UNIQUE,
    PasswordHash TEXT NOT NULL,
    Role TEXT NOT NULL CHECK(Role IN ('teacher', 'student')),
    PrimarySubject TEXT,
    CreatedAtUtc TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_users_email ON Users(Email);

-- ============================================
-- Table: AuthSessions
-- Stores active authentication sessions
-- ============================================
CREATE TABLE IF NOT EXISTS AuthSessions (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Token TEXT NOT NULL UNIQUE,
    UserId INTEGER NOT NULL,
    ExpiresAtUtc TEXT NOT NULL,
    CreatedAtUtc TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_authsessions_token ON AuthSessions(Token);
CREATE INDEX IF NOT EXISTS idx_authsessions_userid ON AuthSessions(UserId);

-- ============================================
-- Table: Students
-- Stores student profiles and exam goals
-- ============================================
CREATE TABLE IF NOT EXISTS Students (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    FullName TEXT NOT NULL,
    Email TEXT NOT NULL UNIQUE,
    ExamGoal TEXT,
    TargetScore TEXT,
    CreatedAtUtc TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_students_email ON Students(Email);

-- ============================================
-- Table: Classrooms
-- Stores classroom/course information
-- ============================================
CREATE TABLE IF NOT EXISTS Classrooms (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Name TEXT NOT NULL,
    Subject TEXT NOT NULL,
    InviteCode TEXT NOT NULL UNIQUE,
    Schedule TEXT,
    StudentCount INTEGER NOT NULL DEFAULT 0,
    CreatedAtUtc TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_classrooms_invitecode ON Classrooms(InviteCode);
CREATE INDEX IF NOT EXISTS idx_classrooms_subject ON Classrooms(Subject);

-- ============================================
-- Table: Assignments
-- Stores assignments and their details
-- ============================================
CREATE TABLE IF NOT EXISTS Assignments (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Title TEXT NOT NULL,
    ClassName TEXT NOT NULL,
    DueAtUtc TEXT NOT NULL,
    QuestionCount INTEGER NOT NULL DEFAULT 0,
    Status TEXT NOT NULL DEFAULT 'Pending' CHECK(Status IN ('Pending', 'In Progress', 'Completed', 'Graded', 'Overdue')),
    CreatedAtUtc TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_assignments_classname ON Assignments(ClassName);
CREATE INDEX IF NOT EXISTS idx_assignments_status ON Assignments(Status);
CREATE INDEX IF NOT EXISTS idx_assignments_dueatutc ON Assignments(DueAtUtc);

-- ============================================
-- Sample Seed Data (Optional)
-- ============================================

-- Sample Students
INSERT OR IGNORE INTO Students (FullName, Email, ExamGoal, TargetScore, CreatedAtUtc) VALUES
('Emma Johnson', 'emma.johnson@example.com', 'SAT', '1500', datetime('now')),
('Liam Smith', 'liam.smith@example.com', 'SAT', '1450', datetime('now')),
('Olivia Brown', 'olivia.brown@example.com', 'ACT', '34', datetime('now')),
('Noah Davis', 'noah.davis@example.com', 'IELTS', '7.5', datetime('now')),
('Ava Wilson', 'ava.wilson@example.com', 'SAT', '1400', datetime('now')),
('Ethan Martinez', 'ethan.martinez@example.com', 'TOEFL', '110', datetime('now')),
('Sophia Anderson', 'sophia.anderson@example.com', 'SAT', '1550', datetime('now')),
('Mason Taylor', 'mason.taylor@example.com', 'ACT', '32', datetime('now'));

-- Sample Classrooms
INSERT OR IGNORE INTO Classrooms (Name, Subject, InviteCode, Schedule, StudentCount, CreatedAtUtc) VALUES
('SAT Core', 'SAT', 'EXF-204', 'Mon/Wed 4:00 PM', 12, datetime('now')),
('SAT Practice', 'SAT', 'EXF-311', 'Tue/Thu 5:30 PM', 15, datetime('now')),
('IELTS Core', 'IELTS', 'EXF-518', 'Mon/Fri 3:15 PM', 10, datetime('now')),
('IELTS Advanced', 'IELTS', 'EXF-622', 'Wed 6:00 PM', 8, datetime('now')),
('ACT Prep', 'ACT', 'EXF-745', 'Sat 10:00 AM', 14, datetime('now')),
('TOEFL Intensive', 'TOEFL', 'EXF-889', 'Sun 2:00 PM', 9, datetime('now'));

-- Sample Assignments
INSERT OR IGNORE INTO Assignments (Title, ClassName, DueAtUtc, QuestionCount, Status, CreatedAtUtc) VALUES
('SAT Math Practice - Algebra', 'SAT Prep Morning', datetime('now', '+2 days'), 20, 'Pending', datetime('now')),
('SAT Reading Comprehension', 'SAT Prep Morning', datetime('now', '+5 days'), 15, 'Pending', datetime('now')),
('ACT Science Reasoning', 'ACT Weekend Intensive', datetime('now', '+3 days'), 25, 'In Progress', datetime('now', '-2 days')),
('IELTS Writing Task 2 - Opinion Essay', 'IELTS Advanced', datetime('now', '+1 day'), 5, 'Pending', datetime('now')),
('SAT Essay Practice', 'SAT Prep Afternoon', datetime('now', '-1 day'), 3, 'Completed', datetime('now', '-7 days')),
('TOEFL Integrated Writing', 'TOEFL Preparation', datetime('now', '+4 days'), 8, 'Pending', datetime('now'));

-- ============================================
-- Notes:
-- ============================================
-- 1. This schema uses SQLite for local development
-- 2. For PostgreSQL production, change:
--    - AUTOINCREMENT → SERIAL
--    - TEXT → VARCHAR(n) with appropriate lengths
--    - datetime('now') → CURRENT_TIMESTAMP
-- 3. Subjects (SAT, IELTS, etc.) are managed in frontend localStorage, not database
-- 4. User passwords are hashed using Argon2id algorithm
-- 5. Invite codes are auto-generated in format EXF-XXX
