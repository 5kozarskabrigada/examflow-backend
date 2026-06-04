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
-- Table: ClassroomEnrollments
-- Links students to classrooms (many-to-many)
-- ============================================
CREATE TABLE IF NOT EXISTS "ClassroomEnrollments" (
    "Id" SERIAL PRIMARY KEY,
    "ClassroomId" INTEGER NOT NULL,
    "StudentId" INTEGER NOT NULL,
    "EnrolledAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Status" VARCHAR(20) NOT NULL DEFAULT 'Active' CHECK("Status" IN ('Active', 'Completed', 'Dropped')),
    FOREIGN KEY ("ClassroomId") REFERENCES "Classrooms"("Id") ON DELETE CASCADE,
    FOREIGN KEY ("StudentId") REFERENCES "Students"("Id") ON DELETE CASCADE,
    UNIQUE("ClassroomId", "StudentId")
);

CREATE INDEX IF NOT EXISTS "idx_enrollments_classroom" ON "ClassroomEnrollments"("ClassroomId");
CREATE INDEX IF NOT EXISTS "idx_enrollments_student" ON "ClassroomEnrollments"("StudentId");

-- ============================================
-- Table: AssignmentSubmissions
-- Student submissions for assignments
-- ============================================
CREATE TABLE IF NOT EXISTS "AssignmentSubmissions" (
    "Id" SERIAL PRIMARY KEY,
    "AssignmentId" INTEGER NOT NULL,
    "StudentId" INTEGER NOT NULL,
    "SubmittedAtUtc" TIMESTAMP,
    "Score" REAL,
    "MaxScore" REAL,
    "Status" VARCHAR(20) NOT NULL DEFAULT 'Not Started' CHECK("Status" IN ('Not Started', 'In Progress', 'Submitted', 'Graded', 'Late')),
    "TimeSpentMinutes" INTEGER DEFAULT 0,
    "AnswersJson" TEXT,
    "FeedbackText" TEXT,
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("AssignmentId") REFERENCES "Assignments"("Id") ON DELETE CASCADE,
    FOREIGN KEY ("StudentId") REFERENCES "Students"("Id") ON DELETE CASCADE,
    UNIQUE("AssignmentId", "StudentId")
);

CREATE INDEX IF NOT EXISTS "idx_submissions_assignment" ON "AssignmentSubmissions"("AssignmentId");
CREATE INDEX IF NOT EXISTS "idx_submissions_student" ON "AssignmentSubmissions"("StudentId");
CREATE INDEX IF NOT EXISTS "idx_submissions_status" ON "AssignmentSubmissions"("Status");

-- ============================================
-- Table: MockExams
-- Mock exam definitions created by teachers
-- ============================================
CREATE TABLE IF NOT EXISTS "MockExams" (
    "Id" SERIAL PRIMARY KEY,
    "Subject" VARCHAR(64) NOT NULL,
    "Title" VARCHAR(250) NOT NULL,
    "ClassName" VARCHAR(150) NOT NULL,
    "StructureText" VARCHAR(1000),
    "ScheduledForUtc" TIMESTAMP,
    "Status" VARCHAR(32) NOT NULL DEFAULT 'Draft',
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_mockexams_subject" ON "MockExams"("Subject");
CREATE INDEX IF NOT EXISTS "idx_mockexams_status" ON "MockExams"("Status");

-- ============================================
-- Table: MockExamAttempts
-- Student attempts at mock exams
-- ============================================
CREATE TABLE IF NOT EXISTS "MockExamAttempts" (
    "Id" SERIAL PRIMARY KEY,
    "MockExamId" INTEGER NOT NULL,
    "StudentId" INTEGER NOT NULL,
    "StartedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "CompletedAtUtc" TIMESTAMP,
    "Score" REAL,
    "MaxScore" REAL,
    "TimeSpentMinutes" INTEGER,
    "AnswersJson" TEXT,
    "Status" VARCHAR(20) NOT NULL DEFAULT 'In Progress' CHECK("Status" IN ('In Progress', 'Completed', 'Abandoned')),
    FOREIGN KEY ("MockExamId") REFERENCES "MockExams"("Id") ON DELETE CASCADE,
    FOREIGN KEY ("StudentId") REFERENCES "Students"("Id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "idx_attempts_mockexam" ON "MockExamAttempts"("MockExamId");
CREATE INDEX IF NOT EXISTS "idx_attempts_student" ON "MockExamAttempts"("StudentId");

-- ============================================
-- Table: Questions
-- Question bank for assignments and exams
-- ============================================
CREATE TABLE IF NOT EXISTS "Questions" (
    "Id" SERIAL PRIMARY KEY,
    "Subject" VARCHAR(64) NOT NULL,
    "Category" VARCHAR(100) NOT NULL,
    "Difficulty" VARCHAR(20) NOT NULL CHECK("Difficulty" IN ('Easy', 'Medium', 'Hard')),
    "QuestionType" VARCHAR(50) NOT NULL CHECK("QuestionType" IN ('Multiple Choice', 'True/False', 'Short Answer', 'Essay')),
    "QuestionText" TEXT NOT NULL,
    "OptionsJson" TEXT,
    "CorrectAnswer" TEXT,
    "ExplanationText" TEXT,
    "Points" REAL NOT NULL DEFAULT 1.0,
    "Bookmarked" BOOLEAN NOT NULL DEFAULT FALSE,
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK ("Bookmarked" IN (TRUE, FALSE))
);

CREATE INDEX IF NOT EXISTS "idx_questions_subject" ON "Questions"("Subject");
CREATE INDEX IF NOT EXISTS "idx_questions_category" ON "Questions"("Category");
CREATE INDEX IF NOT EXISTS "idx_questions_difficulty" ON "Questions"("Difficulty");

-- ============================================
-- Table: Announcements
-- Teacher announcements to classrooms
-- ============================================
CREATE TABLE IF NOT EXISTS "Announcements" (
    "Id" SERIAL PRIMARY KEY,
    "Title" VARCHAR(250) NOT NULL,
    "Audience" VARCHAR(150) NOT NULL,
    "State" VARCHAR(32) NOT NULL DEFAULT 'Sent',
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_announcements_created" ON "Announcements"("CreatedAtUtc");

-- ============================================
-- Table: CalendarEvents
-- Calendar events for classes, exams, deadlines
-- ============================================
CREATE TABLE IF NOT EXISTS "CalendarEvents" (
    "Id" SERIAL PRIMARY KEY,
    "Title" VARCHAR(250) NOT NULL,
    "EventType" VARCHAR(100) NOT NULL,
    "StartsAtUtc" TIMESTAMP NOT NULL,
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_events_date" ON "CalendarEvents"("StartsAtUtc");
CREATE INDEX IF NOT EXISTS "idx_events_type" ON "CalendarEvents"("EventType");

-- ============================================
-- Table: StudentProgress
-- Track student progress and performance
-- ============================================
CREATE TABLE IF NOT EXISTS "StudentProgress" (
    "Id" SERIAL PRIMARY KEY,
    "StudentId" INTEGER NOT NULL,
    "Subject" VARCHAR(64) NOT NULL,
    "Category" VARCHAR(100) NOT NULL,
    "TotalAttempts" INTEGER NOT NULL DEFAULT 0,
    "CorrectAnswers" INTEGER NOT NULL DEFAULT 0,
    "AverageScore" REAL NOT NULL DEFAULT 0.0,
    "LastAttemptAtUtc" TIMESTAMP,
    "UpdatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("StudentId") REFERENCES "Students"("Id") ON DELETE CASCADE,
    UNIQUE("StudentId", "Subject", "Category")
);

CREATE INDEX IF NOT EXISTS "idx_progress_student" ON "StudentProgress"("StudentId");
CREATE INDEX IF NOT EXISTS "idx_progress_subject" ON "StudentProgress"("Subject");

-- ============================================
-- No Seed Data
-- ============================================
-- This schema intentionally does not insert sample records.

-- ============================================
-- Notes:
-- ============================================
-- 1. This is the PostgreSQL production schema
-- 2. For SQLite local development, use database_schema.sql
-- 3. Table and column names use double quotes for case sensitivity
-- 4. Uses SERIAL instead of AUTOINCREMENT
-- 5. Uses VARCHAR with appropriate lengths
-- 6. Uses TIMESTAMP for dates, BOOLEAN for flags
-- 7. Uses CURRENT_TIMESTAMP instead of datetime('now')
-- 8. Uses INTERVAL for date arithmetic
-- 9. Subjects (SAT, IELTS, etc.) are managed in frontend localStorage, not database
-- 10. User passwords are hashed using Argon2id algorithm
-- 11. Invite codes are auto-generated in format EXF-XXX
--
-- TABLE SUMMARY:
-- Core Tables:
--   - Users: Teacher and student accounts
--   - AuthSessions: Login session tokens
--   - Students: Student profiles with goals
--   - Classrooms: Course/classroom management
--   - Assignments: Homework and practice assignments
--
-- Relationship Tables:
--   - ClassroomEnrollments: Student-classroom enrollments (many-to-many)
--   - AssignmentSubmissions: Student assignment submissions and grades
--
-- Assessment Tables:
--   - MockExams: Mock exam definitions created by teachers
--   - MockExamAttempts: Student attempts at mock exams
--   - Questions: Question bank for assignments and exams
--   - StudentProgress: Aggregated student performance tracking
--
-- Communication Tables:
--   - Announcements: Teacher announcements to classrooms
--   - CalendarEvents: Class schedules, exam dates, deadlines
--
-- TEACHER FUNCTIONALITIES COVERED:
--   ✓ Create and manage classrooms
--   ✓ Enroll students in classrooms
--   ✓ Create assignments with questions
--   ✓ Grade student submissions
--   ✓ Create mock exams
--   ✓ Post announcements
--   ✓ Schedule calendar events
--   ✓ Build question banks
--   ✓ Track student progress
--
-- STUDENT FUNCTIONALITIES COVERED:
--   ✓ Join classrooms via invite code
--   ✓ View and submit assignments
--   ✓ Take mock exams
--   ✓ View grades and feedback
--   ✓ See announcements
--   ✓ View calendar events
--   ✓ Track personal progress
--   ✓ Set exam goals and target scores

-- ============================================
-- Migration Commands:
-- ============================================
-- To run this on your PostgreSQL database:
-- psql -U your_username -d examflow -f database_schema_postgresql.sql
--
-- Or connect with connection string and execute:
-- Host=your_host;Port=5432;Database=examflow;Username=your_user;Password=your_pass
