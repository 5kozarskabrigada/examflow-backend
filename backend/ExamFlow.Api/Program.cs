using ExamFlow.Api.Data;
using ExamFlow.Api.Contracts;
using ExamFlow.Api.Models;
using ExamFlow.Api.Security;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();

var connectionString =
    builder.Configuration.GetConnectionString("NeonDatabase")
    ?? Environment.GetEnvironmentVariable("ConnectionStrings__NeonDatabase");
var sqliteConnectionString = builder.Configuration.GetConnectionString("SqliteLocal") ?? "Data Source=examflow-local.db";
var useSqliteLocal = builder.Environment.IsDevelopment() &&
    (builder.Configuration.GetValue<bool>("UseSqliteLocal") || string.IsNullOrWhiteSpace(connectionString));

// Accept URI-style Postgres connection strings by normalizing them through Npgsql.
static string NormalizeConnectionString(string cs)
{
    if (string.IsNullOrWhiteSpace(cs) ||
        (!cs.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase) &&
         !cs.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase)))
        return cs;
    var uri = new Uri(cs);
    var userInfo = uri.UserInfo.Split(':');
    var user = Uri.UnescapeDataString(userInfo[0]);
    var pass = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : "";
    var db = uri.AbsolutePath.TrimStart('/');
    var sslMode = "Require";
    if (!string.IsNullOrEmpty(uri.Query))
    {
        foreach (var part in uri.Query.TrimStart('?').Split('&'))
        {
            var kv = part.Split('=', 2);
            if (kv.Length == 2 && kv[0].Equals("sslmode", StringComparison.OrdinalIgnoreCase))
                sslMode = kv[1];
        }
    }
    var port = uri.Port > 0 ? uri.Port : 5432;

    var builder = new Npgsql.NpgsqlConnectionStringBuilder
    {
        Host = uri.Host,
        Port = port,
        Database = db,
        Username = user,
        Password = pass,
        SslMode = Enum.TryParse<Npgsql.SslMode>(sslMode, true, out var parsedSslMode)
            ? parsedSslMode
            : Npgsql.SslMode.Require,
    };

    return builder.ConnectionString;
}

connectionString = NormalizeConnectionString(connectionString!);

builder.Services.AddDbContext<AppDbContext>(options =>
{
    if (useSqliteLocal)
    {
        options.UseSqlite(sqliteConnectionString);
        return;
    }

    if (string.IsNullOrWhiteSpace(connectionString))
    {
        throw new InvalidOperationException("Neon database connection string is missing. Configure ConnectionStrings:NeonDatabase.");
    }

    options.UseNpgsql(connectionString);
});

var allowedOrigins =
    builder.Configuration.GetSection("Frontend:AllowedOrigins").Get<string[]>()
    ?? ["http://localhost:5173"];

builder.Services.AddCors(options =>
{
    options.AddPolicy("Frontend", policy =>
    {
        policy
            .WithOrigins(allowedOrigins)
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

builder.Services.AddHealthChecks();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors("Frontend");

app.Use(async (context, next) =>
{
    try
    {
        await next();
    }
    catch (Exception ex)
    {
        var full = ex.ToString();
        if (ex.InnerException != null)
        {
            full += $"\n\n-- Inner Exception --\n{ex.InnerException}";
        }
        Console.Error.WriteLine($"Unhandled exception: {full}");
        context.Response.StatusCode = 500;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsync(System.Text.Json.JsonSerializer.Serialize(new { error = ex.Message, inner = ex.InnerException?.Message, detail = full }));
    }
});
// HTTPS redirect disabled: handled by reverse proxy (Caddy/nginx) or not needed in no-domain mode

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.EnsureCreatedAsync();

    if (db.Database.ProviderName?.Contains("Npgsql", StringComparison.OrdinalIgnoreCase) == true)
    {
        await db.Database.ExecuteSqlRawAsync(@"
            CREATE TABLE IF NOT EXISTS ""Users"" (
                ""Id"" SERIAL PRIMARY KEY,
                ""FullName"" VARCHAR(200) NOT NULL,
                ""Email"" VARCHAR(320) NOT NULL UNIQUE,
                ""PasswordHash"" VARCHAR(1024) NOT NULL,
                ""Role"" VARCHAR(32) NOT NULL,
                ""PrimarySubject"" VARCHAR(64),
                ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL
            );
        ");

        await db.Database.ExecuteSqlRawAsync(@"
            CREATE TABLE IF NOT EXISTS ""AuthSessions"" (
                ""Id"" SERIAL PRIMARY KEY,
                ""UserId"" INT NOT NULL REFERENCES ""Users""(""Id"") ON DELETE CASCADE,
                ""Token"" VARCHAR(128) NOT NULL UNIQUE,
                ""ExpiresAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL,
                ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ""IX_AuthSessions_UserId"" ON ""AuthSessions"" (""UserId"");
        ");

        await db.Database.ExecuteSqlRawAsync(@"
            CREATE TABLE IF NOT EXISTS ""Questions"" (
                ""Id"" SERIAL PRIMARY KEY,
                ""Subject"" VARCHAR(64) NOT NULL,
                ""Category"" VARCHAR(100) NOT NULL,
                ""Difficulty"" VARCHAR(20) NOT NULL,
                ""QuestionType"" VARCHAR(50) NOT NULL,
                ""QuestionText"" VARCHAR(4000) NOT NULL,
                ""Title"" VARCHAR(250),
                ""ImageUrl"" VARCHAR(1000),
                ""AudioUrl"" VARCHAR(1000),
                ""OptionsJson"" VARCHAR(4000),
                ""CorrectAnswer"" VARCHAR(1000),
                ""ExplanationText"" VARCHAR(4000),
                ""QuestionData"" VARCHAR(8000),
                ""Module"" VARCHAR(32),
                ""Topic"" VARCHAR(64),
                ""BandTarget"" VARCHAR(20),
                ""SkillTested"" VARCHAR(64),
                ""TimeRequirement"" VARCHAR(32),
                ""Source"" VARCHAR(50),
                ""Status"" VARCHAR(20),
                ""Tags"" VARCHAR(500),
                ""Domain"" VARCHAR(64),
                ""Skill"" VARCHAR(64),
                ""CalculatorAllowed"" BOOLEAN NOT NULL DEFAULT FALSE,
                ""PassageRequired"" BOOLEAN NOT NULL DEFAULT FALSE,
                ""ImageRequired"" BOOLEAN NOT NULL DEFAULT FALSE,
                ""TableRequired"" BOOLEAN NOT NULL DEFAULT FALSE,
                ""GraphRequired"" BOOLEAN NOT NULL DEFAULT FALSE,
                ""EquationRequired"" BOOLEAN NOT NULL DEFAULT FALSE,
                ""Hint"" VARCHAR(1000),
                ""Points"" REAL NOT NULL DEFAULT 1.0,
                ""CreatedByUserId"" INTEGER NOT NULL DEFAULT 0,
                ""Bookmarked"" BOOLEAN NOT NULL DEFAULT FALSE,
                ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL
            );

            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Bookmarked"" BOOLEAN NOT NULL DEFAULT FALSE;
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Passage"" VARCHAR(4000);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""QuestionData"" VARCHAR(8000);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Module"" VARCHAR(32);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Topic"" VARCHAR(64);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""BandTarget"" VARCHAR(20);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""SkillTested"" VARCHAR(64);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""TimeRequirement"" VARCHAR(32);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Source"" VARCHAR(50);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Status"" VARCHAR(20);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Tags"" VARCHAR(500);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Title"" VARCHAR(250);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""ImageUrl"" VARCHAR(1000);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""AudioUrl"" VARCHAR(1000);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Domain"" VARCHAR(64);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Skill"" VARCHAR(64);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""CalculatorAllowed"" BOOLEAN NOT NULL DEFAULT FALSE;
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""PassageRequired"" BOOLEAN NOT NULL DEFAULT FALSE;
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""ImageRequired"" BOOLEAN NOT NULL DEFAULT FALSE;
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""TableRequired"" BOOLEAN NOT NULL DEFAULT FALSE;
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""GraphRequired"" BOOLEAN NOT NULL DEFAULT FALSE;
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""EquationRequired"" BOOLEAN NOT NULL DEFAULT FALSE;
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Hint"" VARCHAR(1000);
            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""CreatedByUserId"" INTEGER NOT NULL DEFAULT 0;
            ALTER TABLE ""Questions"" DROP CONSTRAINT IF EXISTS ""Questions_CreatedByUserId_fkey"";
            ALTER TABLE ""Questions"" DROP CONSTRAINT IF EXISTS ""Questions_QuestionType_check"";

            CREATE INDEX IF NOT EXISTS ""IX_Questions_Subject"" ON ""Questions"" (""Subject"");
            CREATE INDEX IF NOT EXISTS ""IX_Questions_Category"" ON ""Questions"" (""Category"");
            CREATE INDEX IF NOT EXISTS ""IX_Questions_Difficulty"" ON ""Questions"" (""Difficulty"");
            CREATE INDEX IF NOT EXISTS ""IX_Questions_Module"" ON ""Questions"" (""Module"");
            CREATE INDEX IF NOT EXISTS ""IX_Questions_Topic"" ON ""Questions"" (""Topic"");
            CREATE INDEX IF NOT EXISTS ""IX_Questions_Status"" ON ""Questions"" (""Status"");
        ");

        await db.Database.ExecuteSqlRawAsync(@"
            CREATE TABLE IF NOT EXISTS ""MockExams"" (
                ""Id"" SERIAL PRIMARY KEY,
                ""Subject"" VARCHAR(64) NOT NULL,
                ""Title"" VARCHAR(250) NOT NULL,
                ""ClassName"" VARCHAR(150) NOT NULL,
                ""StructureText"" VARCHAR(1000),
                ""ScheduledForUtc"" TIMESTAMP WITH TIME ZONE NULL,
                ""Status"" VARCHAR(32) NOT NULL DEFAULT 'Draft',
                ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL
            );

            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""Subject"" VARCHAR(64) NOT NULL DEFAULT '';
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""Title"" VARCHAR(250) NOT NULL DEFAULT '';
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""ClassName"" VARCHAR(150) NOT NULL DEFAULT '';
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""StructureText"" VARCHAR(1000);
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""ScheduledForUtc"" TIMESTAMP WITH TIME ZONE NULL;
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""Status"" VARCHAR(32) NOT NULL DEFAULT 'Draft';
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""Description"" VARCHAR(2000);
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""Code"" VARCHAR(32);
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""DurationMinutes"" INTEGER;
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""SecurityLevel"" VARCHAR(32);
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""DeletedAt"" TIMESTAMP WITH TIME ZONE NULL;
            ALTER TABLE ""MockExams"" ADD COLUMN IF NOT EXISTS ""ExamType"" VARCHAR(32) NULL;
            ALTER TABLE ""MockExams"" ALTER COLUMN ""ExamType"" DROP NOT NULL;

            CREATE INDEX IF NOT EXISTS ""IX_MockExams_Subject"" ON ""MockExams"" (""Subject"");
            CREATE INDEX IF NOT EXISTS ""IX_MockExams_Status"" ON ""MockExams"" (""Status"");
            CREATE INDEX IF NOT EXISTS ""IX_MockExams_Code"" ON ""MockExams"" (""Code"");
        ");

        await db.Database.ExecuteSqlRawAsync(@"
            CREATE TABLE IF NOT EXISTS ""Announcements"" (
                ""Id"" SERIAL PRIMARY KEY,
                ""Title"" VARCHAR(250) NOT NULL,
                ""Audience"" VARCHAR(150) NOT NULL,
                ""State"" VARCHAR(32) NOT NULL DEFAULT 'Sent',
                ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL
            );

            ALTER TABLE ""Announcements"" ADD COLUMN IF NOT EXISTS ""Title"" VARCHAR(250) NOT NULL DEFAULT '';
            ALTER TABLE ""Announcements"" ADD COLUMN IF NOT EXISTS ""Audience"" VARCHAR(150) NOT NULL DEFAULT '';
            ALTER TABLE ""Announcements"" ADD COLUMN IF NOT EXISTS ""State"" VARCHAR(32) NOT NULL DEFAULT 'Sent';
            ALTER TABLE ""Announcements"" ADD COLUMN IF NOT EXISTS ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();

            CREATE INDEX IF NOT EXISTS ""IX_Announcements_CreatedAtUtc"" ON ""Announcements"" (""CreatedAtUtc"");
        ");

        await db.Database.ExecuteSqlRawAsync(@"
            CREATE TABLE IF NOT EXISTS ""CalendarEvents"" (
                ""Id"" SERIAL PRIMARY KEY,
                ""Title"" VARCHAR(250) NOT NULL,
                ""EventType"" VARCHAR(100) NOT NULL,
                ""StartsAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL,
                ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL
            );

            ALTER TABLE ""CalendarEvents"" ADD COLUMN IF NOT EXISTS ""Title"" VARCHAR(250) NOT NULL DEFAULT '';
            ALTER TABLE ""CalendarEvents"" ADD COLUMN IF NOT EXISTS ""EventType"" VARCHAR(100) NOT NULL DEFAULT '';
            ALTER TABLE ""CalendarEvents"" ADD COLUMN IF NOT EXISTS ""StartsAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();
            ALTER TABLE ""CalendarEvents"" ADD COLUMN IF NOT EXISTS ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();

            CREATE INDEX IF NOT EXISTS ""IX_CalendarEvents_StartsAtUtc"" ON ""CalendarEvents"" (""StartsAtUtc"");
            CREATE INDEX IF NOT EXISTS ""IX_CalendarEvents_EventType"" ON ""CalendarEvents"" (""EventType"");
        ");

        await db.Database.ExecuteSqlRawAsync(@"
            CREATE TABLE IF NOT EXISTS ""Students"" (
                ""Id"" SERIAL PRIMARY KEY,
                ""FullName"" VARCHAR(200) NOT NULL,
                ""Email"" VARCHAR(320) NOT NULL UNIQUE,
                ""ExamGoal"" VARCHAR(100),
                ""TargetScore"" VARCHAR(50),
                ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ""IX_Students_Email"" ON ""Students"" (""Email"");
        ");

        await db.Database.ExecuteSqlRawAsync(@"
            CREATE TABLE IF NOT EXISTS ""Classrooms"" (
                ""Id"" SERIAL PRIMARY KEY,
                ""Name"" VARCHAR(150) NOT NULL,
                ""Subject"" VARCHAR(64) NOT NULL,
                ""InviteCode"" VARCHAR(32) NOT NULL UNIQUE,
                ""Schedule"" VARCHAR(100),
                ""StudentCount"" INTEGER NOT NULL DEFAULT 0,
                ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ""IX_Classrooms_InviteCode"" ON ""Classrooms"" (""InviteCode"");
            CREATE INDEX IF NOT EXISTS ""IX_Classrooms_Subject"" ON ""Classrooms"" (""Subject"");
        ");

        await db.Database.ExecuteSqlRawAsync(@"
            CREATE TABLE IF NOT EXISTS ""Assignments"" (
                ""Id"" SERIAL PRIMARY KEY,
                ""Title"" VARCHAR(250) NOT NULL,
                ""ClassName"" VARCHAR(150) NOT NULL,
                ""DueAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL,
                ""QuestionCount"" INTEGER NOT NULL DEFAULT 0,
                ""Status"" VARCHAR(32) NOT NULL DEFAULT 'Pending',
                ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL
            );

            CREATE INDEX IF NOT EXISTS ""IX_Assignments_ClassName"" ON ""Assignments"" (""ClassName"");
            CREATE INDEX IF NOT EXISTS ""IX_Assignments_Status"" ON ""Assignments"" (""Status"");
            CREATE INDEX IF NOT EXISTS ""IX_Assignments_DueAtUtc"" ON ""Assignments"" (""DueAtUtc"");
        ");
    }
}

var api = app.MapGroup("/api");

api.MapGet("/health", () => Results.Ok(new { status = "ok", timestampUtc = DateTime.UtcNow }));
api.MapHealthChecks("/healthz");

api.MapPost("/auth/register", async (AppDbContext db, RegisterRequest request) =>
{
    var fullName = request.FullName.Trim();
    var normalizedEmail = request.Email.Trim().ToLowerInvariant();
    var password = request.Password;

    if (string.IsNullOrWhiteSpace(fullName) || string.IsNullOrWhiteSpace(normalizedEmail) || string.IsNullOrWhiteSpace(password))
    {
        return Results.BadRequest(new { error = "Full name, email, and password are required." });
    }

    var normalizedRole = request.Role.Trim().ToLowerInvariant();
    if (normalizedRole is not ("teacher" or "student"))
    {
        return Results.BadRequest(new { error = "Role must be either teacher or student." });
    }

    var existingUser = await db.Users.FirstOrDefaultAsync(x => x.Email == normalizedEmail);
    if (existingUser is not null)
    {
        return Results.Conflict(new { error = "An account with this email already exists." });
    }

    var user = new AppUser
    {
        FullName = fullName,
        Email = normalizedEmail,
        PasswordHash = PasswordSecurity.HashPassword(password),
        Role = normalizedRole,
        PrimarySubject = request.PrimarySubject?.Trim(),
        CreatedAtUtc = DateTime.UtcNow,
    };

    db.Users.Add(user);
    await db.SaveChangesAsync();

    var token = Convert.ToHexString(Guid.NewGuid().ToByteArray()) + Convert.ToHexString(Guid.NewGuid().ToByteArray());
    var session = new AuthSession
    {
        UserId = user.Id,
        Token = token,
        ExpiresAtUtc = DateTime.UtcNow.AddDays(30),
        CreatedAtUtc = DateTime.UtcNow,
    };

    db.AuthSessions.Add(session);
    await db.SaveChangesAsync();

    return Results.Ok(new AuthResponse(token, ToAuthUser(user)));
});

api.MapPost("/auth/login", async (AppDbContext db, LoginRequest request) =>
{
    var normalizedEmail = request.Email.Trim().ToLowerInvariant();
    if (string.IsNullOrWhiteSpace(normalizedEmail) || string.IsNullOrWhiteSpace(request.Password))
    {
        return Results.BadRequest(new { error = "Email and password are required." });
    }

    var user = await db.Users.FirstOrDefaultAsync(x => x.Email == normalizedEmail);
    if (user is null || !PasswordSecurity.VerifyPassword(request.Password, user.PasswordHash))
    {
        return Results.Unauthorized();
    }

    var token = Convert.ToHexString(Guid.NewGuid().ToByteArray()) + Convert.ToHexString(Guid.NewGuid().ToByteArray());
    var session = new AuthSession
    {
        UserId = user.Id,
        Token = token,
        ExpiresAtUtc = DateTime.UtcNow.AddDays(30),
        CreatedAtUtc = DateTime.UtcNow,
    };

    db.AuthSessions.Add(session);
    await db.SaveChangesAsync();

    return Results.Ok(new AuthResponse(token, ToAuthUser(user)));
});

api.MapGet("/auth/me", async (HttpContext httpContext, AppDbContext db) =>
{
    var authHeader = httpContext.Request.Headers.Authorization.ToString();
    if (!authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
    {
        return Results.Unauthorized();
    }

    var token = authHeader["Bearer ".Length..].Trim();
    if (string.IsNullOrWhiteSpace(token))
    {
        return Results.Unauthorized();
    }

    var now = DateTime.UtcNow;
    var session = await db.AuthSessions
        .Include(x => x.User)
        .FirstOrDefaultAsync(x => x.Token == token && x.ExpiresAtUtc > now);

    if (session?.User is null)
    {
        return Results.Unauthorized();
    }

    return Results.Ok(ToAuthUser(session.User));
});

api.MapGet("/students", async (AppDbContext db) =>
{
    var students = await db.Students
        .OrderByDescending(x => x.CreatedAtUtc)
        .Take(200)
        .ToListAsync();

    return Results.Ok(students);
});

api.MapPost("/students", async (AppDbContext db, Student input) =>
{
    input.CreatedAtUtc = DateTime.UtcNow;
    db.Students.Add(input);
    await db.SaveChangesAsync();
    return Results.Created($"/api/students/{input.Id}", input);
});

api.MapGet("/assignments", async (AppDbContext db) =>
{
    var assignments = await db.Assignments
        .OrderBy(x => x.DueAtUtc)
        .Take(200)
        .ToListAsync();

    return Results.Ok(assignments);
});

api.MapPost("/assignments", async (AppDbContext db, Assignment input) =>
{
    input.DueAtUtc = input.DueAtUtc.Kind == DateTimeKind.Unspecified
        ? DateTime.SpecifyKind(input.DueAtUtc, DateTimeKind.Utc)
        : input.DueAtUtc.ToUniversalTime();
    input.CreatedAtUtc = DateTime.UtcNow;
    db.Assignments.Add(input);
    await db.SaveChangesAsync();
    return Results.Created($"/api/assignments/{input.Id}", input);
});

api.MapPut("/assignments/{id:int}", async (int id, AppDbContext db, Assignment input) =>
{
    var existing = await db.Assignments.FirstOrDefaultAsync(x => x.Id == id);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Assignment not found." });
    }

    existing.Title = input.Title.Trim();
    existing.ClassName = input.ClassName.Trim();
    existing.DueAtUtc = input.DueAtUtc.Kind == DateTimeKind.Unspecified
        ? DateTime.SpecifyKind(input.DueAtUtc, DateTimeKind.Utc)
        : input.DueAtUtc.ToUniversalTime();
    existing.QuestionCount = input.QuestionCount;
    existing.Status = input.Status.Trim();

    await db.SaveChangesAsync();
    return Results.Ok(existing);
});

api.MapDelete("/assignments/{id:int}", async (int id, AppDbContext db) =>
{
    var existing = await db.Assignments.FirstOrDefaultAsync(x => x.Id == id);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Assignment not found." });
    }

    db.Assignments.Remove(existing);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

api.MapGet("/questions", async (HttpRequest request, AppDbContext db) =>
{
    try
    {
        var query = db.Questions.AsQueryable();

        var subject = request.Query["subject"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(subject))
    {
        query = query.Where(x => x.Subject.ToLower() == subject.ToLower());
    }

    var category = request.Query["category"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(category))
    {
        query = query.Where(x => x.Category.ToLower().Contains(category.ToLower()));
    }

    var difficulty = request.Query["difficulty"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(difficulty))
    {
        query = query.Where(x => x.Difficulty.ToLower() == difficulty.ToLower());
    }

    var search = request.Query["search"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(search))
    {
        query = query.Where(x =>
            x.QuestionText.ToLower().Contains(search.ToLower()) ||
            x.Category.ToLower().Contains(search.ToLower()) ||
            x.QuestionType.ToLower().Contains(search.ToLower()));
    }

    var bookmarked = request.Query["bookmarked"].ToString().Trim();
    if (bool.TryParse(bookmarked, out var bookmarkedValue))
    {
        query = query.Where(x => x.Bookmarked == bookmarkedValue);
    }

    var module = request.Query["module"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(module))
    {
        query = query.Where(x => x.Module != null && x.Module.ToLower() == module.ToLower());
    }

    var topic = request.Query["topic"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(topic))
    {
        query = query.Where(x => x.Topic != null && x.Topic.ToLower() == topic.ToLower());
    }

    var bandTarget = request.Query["bandTarget"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(bandTarget))
    {
        query = query.Where(x => x.BandTarget != null && x.BandTarget.ToLower() == bandTarget.ToLower());
    }

    var skillTested = request.Query["skillTested"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(skillTested))
    {
        query = query.Where(x => x.SkillTested != null && x.SkillTested.ToLower() == skillTested.ToLower());
    }

    var status = request.Query["status"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(status))
    {
        query = query.Where(x => x.Status != null && x.Status.ToLower() == status.ToLower());
    }

    var domain = request.Query["domain"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(domain))
    {
        query = query.Where(x => x.Domain != null && x.Domain.ToLower() == domain.ToLower());
    }

    var skill = request.Query["skill"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(skill))
    {
        query = query.Where(x => x.Skill != null && x.Skill.ToLower() == skill.ToLower());
    }

    var calculator = request.Query["calculatorAllowed"].ToString().Trim();
    if (bool.TryParse(calculator, out var calcValue))
    {
        query = query.Where(x => x.CalculatorAllowed == calcValue);
    }

    var questions = await query
        .OrderBy(x => x.Subject)
        .ThenBy(x => x.Category)
        .ThenByDescending(x => x.CreatedAtUtc)
        .Take(250)
        .ToListAsync();

    return Results.Ok(questions);
    }
    catch (Exception ex)
    {
        var full = ex.ToString();
        if (ex.InnerException != null) full += $"\n\n-- Inner --\n{ex.InnerException}";
        Console.Error.WriteLine($"GET /questions error: {full}");
        return Results.Problem($"Query failed: {ex.Message}\n\n{full}");
    }
});

api.MapPost("/questions", async (AppDbContext db, Question input) =>
{
    try
    {
        input.CreatedAtUtc = DateTime.UtcNow;
        if (input.CreatedByUserId == 0) input.CreatedByUserId = 1;
        db.Questions.Add(input);
        await db.SaveChangesAsync();
        return Results.Created($"/api/questions/{input.Id}", input);
    }
    catch (Exception ex)
    {
        var full = ex.ToString();
        if (ex.InnerException != null)
        {
            full += $"\n\n-- Inner Exception --\n{ex.InnerException}";
        }
        Console.Error.WriteLine($"POST /questions error: {full}");
        var message = ex.Message;
        if (ex.InnerException != null)
        {
            message += $" | Inner: {ex.InnerException.Message}";
        }
        return Results.Problem($"Save failed: {message}\n\n{full}");
    }
});

api.MapPut("/questions/{id:int}", async (int id, AppDbContext db, Question input) =>
{
    var existing = await db.Questions.FirstOrDefaultAsync(x => x.Id == id);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Question not found." });
    }

    existing.Subject = input.Subject.Trim();
    existing.Category = input.Category.Trim();
    existing.Difficulty = input.Difficulty.Trim();
    existing.QuestionType = input.QuestionType.Trim();
    existing.QuestionText = input.QuestionText.Trim();
    existing.Passage = input.Passage;
    existing.OptionsJson = input.OptionsJson;
    existing.CorrectAnswer = input.CorrectAnswer;
    existing.ExplanationText = input.ExplanationText;
    existing.QuestionData = input.QuestionData;
    existing.Title = input.Title;
    existing.ImageUrl = input.ImageUrl;
    existing.AudioUrl = input.AudioUrl;
    existing.Module = input.Module;
    existing.Topic = input.Topic;
    existing.BandTarget = input.BandTarget;
    existing.SkillTested = input.SkillTested;
    existing.TimeRequirement = input.TimeRequirement;
    existing.Source = input.Source;
    existing.Status = input.Status;
    existing.Tags = input.Tags;
    existing.Domain = input.Domain;
    existing.Skill = input.Skill;
    existing.CalculatorAllowed = input.CalculatorAllowed;
    existing.PassageRequired = input.PassageRequired;
    existing.ImageRequired = input.ImageRequired;
    existing.TableRequired = input.TableRequired;
    existing.GraphRequired = input.GraphRequired;
    existing.EquationRequired = input.EquationRequired;
    existing.Hint = input.Hint;
    existing.Points = input.Points;
    existing.CreatedByUserId = input.CreatedByUserId;
    existing.Bookmarked = input.Bookmarked;

    await db.SaveChangesAsync();
    return Results.Ok(existing);
});

api.MapPatch("/questions/{id:int}/bookmark", async (int id, AppDbContext db, BookmarkRequest request) =>
{
    var existing = await db.Questions.FirstOrDefaultAsync(x => x.Id == id);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Question not found." });
    }

    existing.Bookmarked = request.Bookmarked;
    await db.SaveChangesAsync();
    return Results.Ok(existing);
});

api.MapDelete("/questions/{id:int}", async (int id, AppDbContext db) =>
{
    var existing = await db.Questions.FirstOrDefaultAsync(x => x.Id == id);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Question not found." });
    }

    db.Questions.Remove(existing);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

// Classroom endpoints
api.MapGet("/classrooms", async (AppDbContext db) =>
{
    var classrooms = await db.Classrooms
        .OrderByDescending(c => c.CreatedAtUtc)
        .ToListAsync();

    return Results.Ok(classrooms);
});

api.MapPost("/classrooms", async (AppDbContext db, Classroom input) =>
{
    input.CreatedAtUtc = DateTime.UtcNow;
    // Generate invite code if not provided
    if (string.IsNullOrEmpty(input.InviteCode))
    {
        input.InviteCode = $"EXF-{new Random().Next(100, 999)}";
    }
    db.Classrooms.Add(input);
    await db.SaveChangesAsync();
    return Results.Created($"/api/classrooms/{input.Id}", input);
});

api.MapGet("/mock-exams", async (HttpRequest request, AppDbContext db) =>
{
    var query = db.MockExams.AsQueryable().Where(x => x.DeletedAt == null);
    var subject = request.Query["subject"].ToString().Trim();
    if (!string.IsNullOrWhiteSpace(subject))
    {
        query = query.Where(x => x.Subject.ToLower() == subject.ToLower());
    }

    var mockExams = await query
        .OrderByDescending(x => x.CreatedAtUtc)
        .Take(250)
        .ToListAsync();

    return Results.Ok(mockExams);
});

static string GenerateExamCode()
{
    const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    var random = new Random();
    return new string(Enumerable.Repeat(chars, 6).Select(s => s[random.Next(s.Length)]).ToArray());
}

api.MapPost("/mock-exams", async (AppDbContext db, MockExam input) =>
{
    if (input.ScheduledForUtc.HasValue)
    {
        input.ScheduledForUtc = input.ScheduledForUtc.Value.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(input.ScheduledForUtc.Value, DateTimeKind.Utc)
            : input.ScheduledForUtc.Value.ToUniversalTime();
    }
    input.CreatedAtUtc = DateTime.UtcNow;
    if (string.IsNullOrWhiteSpace(input.Code))
    {
        input.Code = GenerateExamCode();
    }
    if (string.IsNullOrWhiteSpace(input.SecurityLevel))
    {
        input.SecurityLevel = "standard";
    }
    db.MockExams.Add(input);
    await db.SaveChangesAsync();
    return Results.Created($"/api/mock-exams/{input.Id}", input);
});

api.MapPut("/mock-exams/{id:int}", async (int id, AppDbContext db, MockExam input) =>
{
    var existing = await db.MockExams.FirstOrDefaultAsync(x => x.Id == id && x.DeletedAt == null);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Mock exam not found." });
    }

    existing.Subject = input.Subject.Trim();
    existing.Title = input.Title.Trim();
    existing.ClassName = input.ClassName.Trim();
    existing.StructureText = input.StructureText;
    existing.Description = input.Description;
    existing.DurationMinutes = input.DurationMinutes;
    existing.SecurityLevel = input.SecurityLevel;
    existing.ScheduledForUtc = input.ScheduledForUtc.HasValue
        ? (input.ScheduledForUtc.Value.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(input.ScheduledForUtc.Value, DateTimeKind.Utc)
            : input.ScheduledForUtc.Value.ToUniversalTime())
        : input.ScheduledForUtc;
    existing.Status = input.Status.Trim();

    await db.SaveChangesAsync();
    return Results.Ok(existing);
});

api.MapDelete("/mock-exams/{id:int}", async (int id, AppDbContext db) =>
{
    var existing = await db.MockExams.FirstOrDefaultAsync(x => x.Id == id && x.DeletedAt == null);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Mock exam not found." });
    }

    existing.DeletedAt = DateTime.UtcNow;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

api.MapPatch("/mock-exams/{id:int}/status", async (int id, AppDbContext db, UpdateStatusRequest request) =>
{
    var existing = await db.MockExams.FirstOrDefaultAsync(x => x.Id == id && x.DeletedAt == null);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Mock exam not found." });
    }

    existing.Status = request.Status.Trim();
    await db.SaveChangesAsync();
    return Results.Ok(existing);
});

api.MapPost("/mock-exams/{id:int}/regenerate-code", async (int id, AppDbContext db) =>
{
    var existing = await db.MockExams.FirstOrDefaultAsync(x => x.Id == id && x.DeletedAt == null);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Mock exam not found." });
    }

    existing.Code = GenerateExamCode();
    await db.SaveChangesAsync();
    return Results.Ok(new { exam = existing });
});

api.MapGet("/announcements", async (AppDbContext db) =>
{
    var announcements = await db.Announcements
        .OrderByDescending(x => x.CreatedAtUtc)
        .Take(250)
        .ToListAsync();
    return Results.Ok(announcements);
});

api.MapPost("/announcements", async (AppDbContext db, Announcement input) =>
{
    input.CreatedAtUtc = DateTime.UtcNow;
    db.Announcements.Add(input);
    await db.SaveChangesAsync();
    return Results.Created($"/api/announcements/{input.Id}", input);
});

api.MapPut("/announcements/{id:int}", async (int id, AppDbContext db, Announcement input) =>
{
    var existing = await db.Announcements.FirstOrDefaultAsync(x => x.Id == id);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Announcement not found." });
    }

    existing.Title = input.Title.Trim();
    existing.Audience = input.Audience.Trim();
    existing.State = input.State.Trim();

    await db.SaveChangesAsync();
    return Results.Ok(existing);
});

api.MapDelete("/announcements/{id:int}", async (int id, AppDbContext db) =>
{
    var existing = await db.Announcements.FirstOrDefaultAsync(x => x.Id == id);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Announcement not found." });
    }

    db.Announcements.Remove(existing);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

api.MapGet("/calendar-events", async (AppDbContext db) =>
{
    var events = await db.CalendarEvents
        .OrderBy(x => x.StartsAtUtc)
        .Take(250)
        .ToListAsync();
    return Results.Ok(events);
});

api.MapPost("/calendar-events", async (AppDbContext db, CalendarEvent input) =>
{
    input.StartsAtUtc = input.StartsAtUtc.Kind == DateTimeKind.Unspecified
        ? DateTime.SpecifyKind(input.StartsAtUtc, DateTimeKind.Utc)
        : input.StartsAtUtc.ToUniversalTime();
    input.CreatedAtUtc = DateTime.UtcNow;
    db.CalendarEvents.Add(input);
    await db.SaveChangesAsync();
    return Results.Created($"/api/calendar-events/{input.Id}", input);
});

api.MapPut("/calendar-events/{id:int}", async (int id, AppDbContext db, CalendarEvent input) =>
{
    var existing = await db.CalendarEvents.FirstOrDefaultAsync(x => x.Id == id);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Calendar event not found." });
    }

    existing.Title = input.Title.Trim();
    existing.EventType = input.EventType.Trim();
    existing.StartsAtUtc = input.StartsAtUtc.Kind == DateTimeKind.Unspecified
        ? DateTime.SpecifyKind(input.StartsAtUtc, DateTimeKind.Utc)
        : input.StartsAtUtc.ToUniversalTime();

    await db.SaveChangesAsync();
    return Results.Ok(existing);
});

api.MapDelete("/calendar-events/{id:int}", async (int id, AppDbContext db) =>
{
    var existing = await db.CalendarEvents.FirstOrDefaultAsync(x => x.Id == id);
    if (existing is null)
    {
        return Results.NotFound(new { error = "Calendar event not found." });
    }

    db.CalendarEvents.Remove(existing);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

api.MapGet("/dashboard/stats", async (AppDbContext db) =>
{
    var totalStudents = await db.Students.CountAsync();
    var totalClassrooms = await db.Classrooms.CountAsync();
    var pendingAssignments = await db.Assignments.CountAsync(a => a.Status == "Pending");
    var completedAssignments = await db.Assignments.CountAsync(a => a.Status == "Completed");
    var upcomingDueCount = await db.Assignments.CountAsync(a => a.DueAtUtc > DateTime.UtcNow && a.DueAtUtc < DateTime.UtcNow.AddDays(7));

    return Results.Ok(new
    {
        totalStudents,
        totalClassrooms,
        pendingAssignments,
        completedAssignments,
        upcomingDueCount
    });
});

app.Run();

static AuthUserResponse ToAuthUser(AppUser user) =>
    new(user.Id, user.FullName, user.Email, user.Role, user.PrimarySubject);

public record BookmarkRequest(bool Bookmarked);
public record UpdateStatusRequest(string Status);
