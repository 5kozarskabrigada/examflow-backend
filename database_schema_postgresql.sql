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
    "Title" VARCHAR(200) NOT NULL,
    "Subject" VARCHAR(64) NOT NULL,
    "ExamType" VARCHAR(64) NOT NULL,
    "DurationMinutes" INTEGER NOT NULL,
    "TotalQuestions" INTEGER NOT NULL,
    "TotalPoints" REAL NOT NULL,
    "Instructions" TEXT,
    "IsPublished" BOOLEAN NOT NULL DEFAULT FALSE,
    "CreatedByUserId" INTEGER NOT NULL,
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("CreatedByUserId") REFERENCES "Users"("Id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "idx_mockexams_subject" ON "MockExams"("Subject");
CREATE INDEX IF NOT EXISTS "idx_mockexams_creator" ON "MockExams"("CreatedByUserId");

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
    "CreatedByUserId" INTEGER NOT NULL,
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("CreatedByUserId") REFERENCES "Users"("Id") ON DELETE CASCADE
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
    "ClassroomId" INTEGER NOT NULL,
    "Title" VARCHAR(200) NOT NULL,
    "Content" TEXT NOT NULL,
    "Priority" VARCHAR(20) NOT NULL DEFAULT 'Normal' CHECK("Priority" IN ('Low', 'Normal', 'High', 'Urgent')),
    "PublishedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "CreatedByUserId" INTEGER NOT NULL,
    FOREIGN KEY ("ClassroomId") REFERENCES "Classrooms"("Id") ON DELETE CASCADE,
    FOREIGN KEY ("CreatedByUserId") REFERENCES "Users"("Id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "idx_announcements_classroom" ON "Announcements"("ClassroomId");
CREATE INDEX IF NOT EXISTS "idx_announcements_priority" ON "Announcements"("Priority");

-- ============================================
-- Table: CalendarEvents
-- Calendar events for classes, exams, deadlines
-- ============================================
CREATE TABLE IF NOT EXISTS "CalendarEvents" (
    "Id" SERIAL PRIMARY KEY,
    "Title" VARCHAR(200) NOT NULL,
    "Description" TEXT,
    "EventType" VARCHAR(20) NOT NULL CHECK("EventType" IN ('Class', 'Exam', 'Assignment', 'Holiday', 'Other')),
    "StartDateTimeUtc" TIMESTAMP NOT NULL,
    "EndDateTimeUtc" TIMESTAMP NOT NULL,
    "ClassroomId" INTEGER,
    "CreatedByUserId" INTEGER NOT NULL,
    "CreatedAtUtc" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("ClassroomId") REFERENCES "Classrooms"("Id") ON DELETE CASCADE,
    FOREIGN KEY ("CreatedByUserId") REFERENCES "Users"("Id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "idx_events_classroom" ON "CalendarEvents"("ClassroomId");
CREATE INDEX IF NOT EXISTS "idx_events_date" ON "CalendarEvents"("StartDateTimeUtc");
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

-- Sample Classroom Enrollments
INSERT INTO "ClassroomEnrollments" ("ClassroomId", "StudentId", "Status") VALUES
(1, 1, 'Active'), (1, 2, 'Active'), (1, 5, 'Active'), (1, 7, 'Active'),
(2, 1, 'Active'), (2, 2, 'Active'), (2, 5, 'Active'),
(3, 4, 'Active'),
(4, 4, 'Active'),
(5, 3, 'Active'), (5, 8, 'Active'),
(6, 6, 'Active')
ON CONFLICT DO NOTHING;

-- Sample Questions
INSERT INTO "Questions" ("Subject", "Category", "Difficulty", "QuestionType", "QuestionText", "CorrectAnswer", "Points", "CreatedByUserId") VALUES
('SAT', 'Math - Algebra', 'Medium', 'Multiple Choice', 'If 2x + 5 = 15, what is the value of x?', '5', 1.0, 1),
('SAT', 'Reading', 'Hard', 'Multiple Choice', 'What is the main theme of the passage?', 'Personal growth through adversity', 1.5, 1),
('IELTS', 'Writing', 'Medium', 'Essay', 'Some people believe technology has made our lives easier. Discuss both views.', NULL, 5.0, 1),
('ACT', 'Science', 'Easy', 'Multiple Choice', 'What is the pH of pure water?', '7', 1.0, 1)
ON CONFLICT DO NOTHING;

-- Sample Announcements
INSERT INTO "Announcements" ("ClassroomId", "Title", "Content", "Priority", "CreatedByUserId") VALUES
(1, 'Upcoming Mock Exam', 'Full-length SAT practice exam scheduled for next Saturday at 9 AM. Please arrive 15 minutes early.', 'High', 1),
(1, 'Study Materials Available', 'New practice materials have been uploaded to the resources section.', 'Normal', 1),
(3, 'Class Rescheduled', 'Monday class moved to Tuesday this week due to holiday.', 'Urgent', 1)
ON CONFLICT DO NOTHING;

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
-- 9. Uses ON CONFLICT DO NOTHING to prevent duplicate seed data
-- 10. Subjects (SAT, IELTS, etc.) are managed in frontend localStorage, not database
-- 11. User passwords are hashed using Argon2id algorithm
-- 12. Invite codes are auto-generated in format EXF-XXX
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
