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

app.Run();

static AuthUserResponse ToAuthUser(AppUser user) =>
    new(user.Id, user.FullName, user.Email, user.Role, user.PrimarySubject);
