using ExamFlow.Api.Data;
using ExamFlow.Api.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();

var connectionString =
    builder.Configuration.GetConnectionString("NeonDatabase")
    ?? Environment.GetEnvironmentVariable("ConnectionStrings__NeonDatabase");

if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException("Neon database connection string is missing. Configure ConnectionStrings:NeonDatabase.");
}

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(connectionString));

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
app.UseHttpsRedirection();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.EnsureCreatedAsync();
}

var api = app.MapGroup("/api");

api.MapGet("/health", () => Results.Ok(new { status = "ok", timestampUtc = DateTime.UtcNow }));
api.MapHealthChecks("/healthz");

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
