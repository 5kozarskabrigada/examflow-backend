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
    CreatedByUserId INTEGER NOT NULL,
    CreatedAtUtc TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (CreatedByUserId) REFERENCES Users(Id) ON DELETE CASCADE
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

-- Sample Classroom Enrollments
INSERT OR IGNORE INTO ClassroomEnrollments (ClassroomId, StudentId, Status) VALUES
(1, 1, 'Active'), (1, 2, 'Active'), (1, 5, 'Active'), (1, 7, 'Active'),
(2, 1, 'Active'), (2, 2, 'Active'), (2, 5, 'Active'),
(3, 4, 'Active'),
(4, 4, 'Active'),
(5, 3, 'Active'), (5, 8, 'Active'),
(6, 6, 'Active');

-- Sample Questions
INSERT OR IGNORE INTO Questions (Subject, Category, Difficulty, QuestionType, QuestionText, CorrectAnswer, Points, CreatedByUserId) VALUES
('SAT', 'Math - Algebra', 'Medium', 'Multiple Choice', 'If 2x + 5 = 15, what is the value of x?', '5', 1.0, 1),
('SAT', 'Reading', 'Hard', 'Multiple Choice', 'What is the main theme of the passage?', 'Personal growth through adversity', 1.5, 1),
('IELTS', 'Writing', 'Medium', 'Essay', 'Some people believe technology has made our lives easier. Discuss both views.', NULL, 5.0, 1),
('ACT', 'Science', 'Easy', 'Multiple Choice', 'What is the pH of pure water?', '7', 1.0, 1);

-- Sample Announcements
INSERT OR IGNORE INTO Announcements (ClassroomId, Title, Content, Priority, CreatedByUserId) VALUES
(1, 'Upcoming Mock Exam', 'Full-length SAT practice exam scheduled for next Saturday at 9 AM. Please arrive 15 minutes early.', 'High', 1),
(1, 'Study Materials Available', 'New practice materials have been uploaded to the resources section.', 'Normal', 1),
(3, 'Class Rescheduled', 'Monday class moved to Tuesday this week due to holiday.', 'Urgent', 1);

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
