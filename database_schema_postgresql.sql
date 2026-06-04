-- ExamFlow Database Schema (PostgreSQL)
-- Production database schema for PostgreSQL

-- ============================================
-- Table: Users (AppUser in C# code)
-- Stores teacher and student accounts
-- ============================================
CREATE TABLE IF NOT EXISTS "Users" (
    "Id" SERIAL PRIMARY KEY,
    "FullName" VARCHAR(200) NOT NULL,
    "Email" VARCHAR(255) NOT NULL UNIQUE,
    "PasswordHash" VARCHAR(255) NOT NULL,
    "Role" VARCHAR(20) NOT NULL CHECK("Role" IN ('teacher', 'student')),
    "PrimarySubject" VARCHAR(100),
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_users_email" ON "Users"("Email");
CREATE INDEX IF NOT EXISTS "idx_users_role" ON "Users"("Role");

-- ============================================
-- Table: AuthSessions
-- Stores active authentication sessions
-- ============================================
CREATE TABLE IF NOT EXISTS "AuthSessions" (
    "Id" SERIAL PRIMARY KEY,
    "Token" VARCHAR(255) NOT NULL UNIQUE,
    "UserId" INTEGER NOT NULL,
    "ExpiresAtUtc" TIMESTAMP NOT NULL,
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("UserId") REFERENCES "Users"("Id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "idx_authsessions_token" ON "AuthSessions"("Token");
CREATE INDEX IF NOT EXISTS "idx_authsessions_userid" ON "AuthSessions"("UserId");

-- ============================================
-- Table: Students
-- Stores student profiles and exam goals
-- ============================================
CREATE TABLE IF NOT EXISTS "Students" (
    "Id" SERIAL PRIMARY KEY,
    "FullName" VARCHAR(200) NOT NULL,
    "Email" VARCHAR(255) NOT NULL UNIQUE,
    "ExamGoal" VARCHAR(100),
    "TargetScore" VARCHAR(50),
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_students_email" ON "Students"("Email");
CREATE INDEX IF NOT EXISTS "idx_students_examgoal" ON "Students"("ExamGoal");

-- ============================================
-- Table: Classrooms
-- Stores classroom/course information
-- ============================================
CREATE TABLE IF NOT EXISTS "Classrooms" (
    "Id" SERIAL PRIMARY KEY,
    "Name" VARCHAR(150) NOT NULL,
    "Subject" VARCHAR(64) NOT NULL,
    "InviteCode" VARCHAR(32) NOT NULL UNIQUE,
    "Schedule" VARCHAR(100),
    "StudentCount" INTEGER NOT NULL DEFAULT 0,
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS "idx_classrooms_invitecode" ON "Classrooms"("InviteCode");
CREATE INDEX IF NOT EXISTS "idx_classrooms_subject" ON "Classrooms"("Subject");

-- ============================================
-- Table: Assignments
-- Stores assignments and their details
-- ============================================
CREATE TABLE IF NOT EXISTS "Assignments" (
    "Id" SERIAL PRIMARY KEY,
    "Title" VARCHAR(200) NOT NULL,
    "ClassName" VARCHAR(150) NOT NULL,
    "DueAtUtc" TIMESTAMP NOT NULL,
    "QuestionCount" INTEGER NOT NULL DEFAULT 0,
    "Status" VARCHAR(50) NOT NULL DEFAULT 'Pending' CHECK("Status" IN ('Pending', 'In Progress', 'Completed', 'Graded', 'Overdue')),
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_assignments_classname" ON "Assignments"("ClassName");
CREATE INDEX IF NOT EXISTS "idx_assignments_status" ON "Assignments"("Status");
CREATE INDEX IF NOT EXISTS "idx_assignments_dueatutc" ON "Assignments"("DueAtUtc");

-- ============================================
-- Sample Seed Data (Optional - for testing)
-- ============================================

-- Sample Students
INSERT INTO "Students" ("FullName", "Email", "ExamGoal", "TargetScore") VALUES
('Emma Johnson', 'emma.johnson@example.com', 'SAT', '1500'),
('Liam Smith', 'liam.smith@example.com', 'SAT', '1450'),
('Olivia Brown', 'olivia.brown@example.com', 'ACT', '34'),
('Noah Davis', 'noah.davis@example.com', 'IELTS', '7.5'),
('Ava Wilson', 'ava.wilson@example.com', 'SAT', '1400'),
('Ethan Martinez', 'ethan.martinez@example.com', 'TOEFL', '110'),
('Sophia Anderson', 'sophia.anderson@example.com', 'SAT', '1550'),
('Mason Taylor', 'mason.taylor@example.com', 'ACT', '32')
ON CONFLICT DO NOTHING;

-- Sample Classrooms
INSERT INTO "Classrooms" ("Name", "Subject", "InviteCode", "Schedule", "StudentCount") VALUES
('SAT Core', 'SAT', 'EXF-204', 'Mon/Wed 4:00 PM', 12),
('SAT Practice', 'SAT', 'EXF-311', 'Tue/Thu 5:30 PM', 15),
('IELTS Core', 'IELTS', 'EXF-518', 'Mon/Fri 3:15 PM', 10),
('IELTS Advanced', 'IELTS', 'EXF-622', 'Wed 6:00 PM', 8),
('ACT Prep', 'ACT', 'EXF-745', 'Sat 10:00 AM', 14),
('TOEFL Intensive', 'TOEFL', 'EXF-889', 'Sun 2:00 PM', 9)
ON CONFLICT DO NOTHING;

-- Sample Assignments
INSERT INTO "Assignments" ("Title", "ClassName", "DueAtUtc", "QuestionCount", "Status") VALUES
('SAT Math Practice - Algebra', 'SAT Prep Morning', CURRENT_TIMESTAMP + INTERVAL '2 days', 20, 'Pending'),
('SAT Reading Comprehension', 'SAT Prep Morning', CURRENT_TIMESTAMP + INTERVAL '5 days', 15, 'Pending'),
('ACT Science Reasoning', 'ACT Weekend Intensive', CURRENT_TIMESTAMP + INTERVAL '3 days', 25, 'In Progress'),
('IELTS Writing Task 2 - Opinion Essay', 'IELTS Advanced', CURRENT_TIMESTAMP + INTERVAL '1 day', 5, 'Pending'),
('SAT Essay Practice', 'SAT Prep Afternoon', CURRENT_TIMESTAMP - INTERVAL '1 day', 3, 'Completed'),
('TOEFL Integrated Writing', 'TOEFL Preparation', CURRENT_TIMESTAMP + INTERVAL '4 days', 8, 'Pending')
ON CONFLICT DO NOTHING;

-- ============================================
-- Notes:
-- ============================================
-- 1. This is the PostgreSQL production schema
-- 2. Table and column names use double quotes for case sensitivity
-- 3. Uses SERIAL instead of AUTOINCREMENT
-- 4. Uses VARCHAR with appropriate lengths
-- 5. Uses TIMESTAMP instead of TEXT for dates
-- 6. Uses CURRENT_TIMESTAMP instead of datetime('now')
-- 7. Uses INTERVAL for date arithmetic
-- 8. Uses ON CONFLICT DO NOTHING to prevent duplicate seed data
-- 9. Subjects (SAT, IELTS, etc.) are managed in frontend localStorage, not database
-- 10. User passwords are hashed using Argon2id algorithm
-- 11. Invite codes are auto-generated in format EXF-XXX

-- ============================================
-- Migration Commands:
-- ============================================
-- To run this on your PostgreSQL database:
-- psql -U your_username -d examflow -f database_schema_postgresql.sql
--
-- Or connect with connection string and execute:
-- Host=your_host;Port=5432;Database=examflow;Username=your_user;Password=your_pass
