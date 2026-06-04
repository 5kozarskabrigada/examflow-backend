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
-- Table: ClassroomEnrollments
-- Links students to classrooms (many-to-many)
-- ============================================
CREATE TABLE IF NOT EXISTS ClassroomEnrollments (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    ClassroomId INTEGER NOT NULL,
    StudentId INTEGER NOT NULL,
    EnrolledAtUtc TEXT NOT NULL DEFAULT (datetime('now')),
    Status TEXT NOT NULL DEFAULT 'Active' CHECK(Status IN ('Active', 'Completed', 'Dropped')),
    FOREIGN KEY (ClassroomId) REFERENCES Classrooms(Id) ON DELETE CASCADE,
    FOREIGN KEY (StudentId) REFERENCES Students(Id) ON DELETE CASCADE,
    UNIQUE(ClassroomId, StudentId)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_classroom ON ClassroomEnrollments(ClassroomId);
CREATE INDEX IF NOT EXISTS idx_enrollments_student ON ClassroomEnrollments(StudentId);

-- ============================================
-- Table: AssignmentSubmissions
-- Student submissions for assignments
-- ============================================
CREATE TABLE IF NOT EXISTS AssignmentSubmissions (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    AssignmentId INTEGER NOT NULL,
    StudentId INTEGER NOT NULL,
    SubmittedAtUtc TEXT,
    Score REAL,
    MaxScore REAL,
    Status TEXT NOT NULL DEFAULT 'Not Started' CHECK(Status IN ('Not Started', 'In Progress', 'Submitted', 'Graded', 'Late')),
    TimeSpentMinutes INTEGER DEFAULT 0,
    AnswersJson TEXT,
    FeedbackText TEXT,
    CreatedAtUtc TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (AssignmentId) REFERENCES Assignments(Id) ON DELETE CASCADE,
    FOREIGN KEY (StudentId) REFERENCES Students(Id) ON DELETE CASCADE,
    UNIQUE(AssignmentId, StudentId)
);

CREATE INDEX IF NOT EXISTS idx_submissions_assignment ON AssignmentSubmissions(AssignmentId);
CREATE INDEX IF NOT EXISTS idx_submissions_student ON AssignmentSubmissions(StudentId);
CREATE INDEX IF NOT EXISTS idx_submissions_status ON AssignmentSubmissions(Status);

-- ============================================
-- Table: MockExams
-- Mock exam definitions created by teachers
-- ============================================
CREATE TABLE IF NOT EXISTS MockExams (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Title TEXT NOT NULL,
    Subject TEXT NOT NULL,
    ExamType TEXT NOT NULL,
    DurationMinutes INTEGER NOT NULL,
    TotalQuestions INTEGER NOT NULL,
    TotalPoints REAL NOT NULL,
    Instructions TEXT,
    IsPublished INTEGER NOT NULL DEFAULT 0,
    CreatedByUserId INTEGER NOT NULL,
    CreatedAtUtc TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (CreatedByUserId) REFERENCES Users(Id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_mockexams_subject ON MockExams(Subject);
CREATE INDEX IF NOT EXISTS idx_mockexams_creator ON MockExams(CreatedByUserId);

-- ============================================
-- Table: MockExamAttempts
-- Student attempts at mock exams
-- ============================================
CREATE TABLE IF NOT EXISTS MockExamAttempts (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    MockExamId INTEGER NOT NULL,
    StudentId INTEGER NOT NULL,
    StartedAtUtc TEXT NOT NULL DEFAULT (datetime('now')),
    CompletedAtUtc TEXT,
    Score REAL,
    MaxScore REAL,
    TimeSpentMinutes INTEGER,
    AnswersJson TEXT,
    Status TEXT NOT NULL DEFAULT 'In Progress' CHECK(Status IN ('In Progress', 'Completed', 'Abandoned')),
    FOREIGN KEY (MockExamId) REFERENCES MockExams(Id) ON DELETE CASCADE,
    FOREIGN KEY (StudentId) REFERENCES Students(Id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_attempts_mockexam ON MockExamAttempts(MockExamId);
CREATE INDEX IF NOT EXISTS idx_attempts_student ON MockExamAttempts(StudentId);

-- ============================================
-- Table: Questions
-- Question bank for assignments and exams
-- ============================================
CREATE TABLE IF NOT EXISTS Questions (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Subject TEXT NOT NULL,
    Category TEXT NOT NULL,
    Difficulty TEXT NOT NULL CHECK(Difficulty IN ('Easy', 'Medium', 'Hard')),
    QuestionType TEXT NOT NULL CHECK(QuestionType IN ('Multiple Choice', 'True/False', 'Short Answer', 'Essay')),
    QuestionText TEXT NOT NULL,
    OptionsJson TEXT,
    CorrectAnswer TEXT,
    ExplanationText TEXT,
    Points REAL NOT NULL DEFAULT 1.0,
    Bookmarked INTEGER NOT NULL DEFAULT 0,
    CreatedAtUtc TEXT NOT NULL DEFAULT (datetime('now')),
    CHECK (Bookmarked IN (0, 1))
);

CREATE INDEX IF NOT EXISTS idx_questions_subject ON Questions(Subject);
CREATE INDEX IF NOT EXISTS idx_questions_category ON Questions(Category);
CREATE INDEX IF NOT EXISTS idx_questions_difficulty ON Questions(Difficulty);

-- ============================================
-- Table: Announcements
-- Teacher announcements to classrooms
-- ============================================
CREATE TABLE IF NOT EXISTS Announcements (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    ClassroomId INTEGER NOT NULL,
    Title TEXT NOT NULL,
    Content TEXT NOT NULL,
    Priority TEXT NOT NULL DEFAULT 'Normal' CHECK(Priority IN ('Low', 'Normal', 'High', 'Urgent')),
    PublishedAtUtc TEXT NOT NULL DEFAULT (datetime('now')),
    CreatedByUserId INTEGER NOT NULL,
    FOREIGN KEY (ClassroomId) REFERENCES Classrooms(Id) ON DELETE CASCADE,
    FOREIGN KEY (CreatedByUserId) REFERENCES Users(Id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_announcements_classroom ON Announcements(ClassroomId);
CREATE INDEX IF NOT EXISTS idx_announcements_priority ON Announcements(Priority);

-- ============================================
-- Table: CalendarEvents
-- Calendar events for classes, exams, deadlines
-- ============================================
CREATE TABLE IF NOT EXISTS CalendarEvents (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Title TEXT NOT NULL,
    Description TEXT,
    EventType TEXT NOT NULL CHECK(EventType IN ('Class', 'Exam', 'Assignment', 'Holiday', 'Other')),
    StartDateTimeUtc TEXT NOT NULL,
    EndDateTimeUtc TEXT NOT NULL,
    ClassroomId INTEGER,
    CreatedByUserId INTEGER NOT NULL,
    CreatedAtUtc TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (ClassroomId) REFERENCES Classrooms(Id) ON DELETE CASCADE,
    FOREIGN KEY (CreatedByUserId) REFERENCES Users(Id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_events_classroom ON CalendarEvents(ClassroomId);
CREATE INDEX IF NOT EXISTS idx_events_date ON CalendarEvents(StartDateTimeUtc);
CREATE INDEX IF NOT EXISTS idx_events_type ON CalendarEvents(EventType);

-- ============================================
-- Table: StudentProgress
-- Track student progress and performance
-- ============================================
CREATE TABLE IF NOT EXISTS StudentProgress (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    StudentId INTEGER NOT NULL,
    Subject TEXT NOT NULL,
    Category TEXT NOT NULL,
    TotalAttempts INTEGER NOT NULL DEFAULT 0,
    CorrectAnswers INTEGER NOT NULL DEFAULT 0,
    AverageScore REAL NOT NULL DEFAULT 0.0,
    LastAttemptAtUtc TEXT,
    UpdatedAtUtc TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (StudentId) REFERENCES Students(Id) ON DELETE CASCADE,
    UNIQUE(StudentId, Subject, Category)
);

CREATE INDEX IF NOT EXISTS idx_progress_student ON StudentProgress(StudentId);
CREATE INDEX IF NOT EXISTS idx_progress_subject ON StudentProgress(Subject);

-- ============================================
-- No Seed Data
-- ============================================
-- This schema intentionally does not insert sample records.

-- ============================================
-- Notes:
-- ============================================
-- 1. This schema uses SQLite for local development
-- 2. For PostgreSQL production, use database_schema_postgresql.sql
-- 3. Subjects (SAT, IELTS, etc.) are managed in frontend localStorage, not database
-- 4. User passwords are hashed using Argon2id algorithm
-- 5. Invite codes are auto-generated in format EXF-XXX
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
