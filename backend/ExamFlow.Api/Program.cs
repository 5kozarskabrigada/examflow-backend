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
                ""OptionsJson"" VARCHAR(4000),
                ""CorrectAnswer"" VARCHAR(1000),
                ""ExplanationText"" VARCHAR(4000),
                ""Points"" NUMERIC(10,2) NOT NULL DEFAULT 1.0,
                ""Bookmarked"" BOOLEAN NOT NULL DEFAULT FALSE,
                ""CreatedAtUtc"" TIMESTAMP WITH TIME ZONE NOT NULL
            );

            ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""Bookmarked"" BOOLEAN NOT NULL DEFAULT FALSE;

            CREATE INDEX IF NOT EXISTS ""IX_Questions_Subject"" ON ""Questions"" (""Subject"");
            CREATE INDEX IF NOT EXISTS ""IX_Questions_Category"" ON ""Questions"" (""Category"");
            CREATE INDEX IF NOT EXISTS ""IX_Questions_Difficulty"" ON ""Questions"" (""Difficulty"");
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
    input.CreatedAtUtc = DateTime.UtcNow;
    db.Assignments.Add(input);
    await db.SaveChangesAsync();
    return Results.Created($"/api/assignments/{input.Id}", input);
});

api.MapGet("/questions", async (HttpRequest request, AppDbContext db) =>
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

    var questions = await query
        .OrderBy(x => x.Subject)
        .ThenBy(x => x.Category)
        .ThenByDescending(x => x.CreatedAtUtc)
        .Take(250)
        .ToListAsync();

    return Results.Ok(questions);
});

api.MapPost("/questions", async (AppDbContext db, Question input) =>
{
    input.CreatedAtUtc = DateTime.UtcNow;
    db.Questions.Add(input);
    await db.SaveChangesAsync();
    return Results.Created($"/api/questions/{input.Id}", input);
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
    existing.OptionsJson = input.OptionsJson;
    existing.CorrectAnswer = input.CorrectAnswer;
    existing.ExplanationText = input.ExplanationText;
    existing.Points = input.Points;
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
