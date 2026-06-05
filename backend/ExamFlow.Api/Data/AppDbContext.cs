using ExamFlow.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace ExamFlow.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Student> Students => Set<Student>();
    public DbSet<Assignment> Assignments => Set<Assignment>();
    public DbSet<Classroom> Classrooms => Set<Classroom>();
    public DbSet<Question> Questions => Set<Question>();
    public DbSet<MockExam> MockExams => Set<MockExam>();
    public DbSet<Announcement> Announcements => Set<Announcement>();
    public DbSet<CalendarEvent> CalendarEvents => Set<CalendarEvent>();
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<AuthSession> AuthSessions => Set<AuthSession>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Student>(entity =>
        {
            entity.Property(x => x.FullName).HasMaxLength(200);
            entity.Property(x => x.Email).HasMaxLength(320);
            entity.HasIndex(x => x.Email).IsUnique();
        });

        modelBuilder.Entity<Assignment>(entity =>
        {
            entity.Property(x => x.Title).HasMaxLength(250);
            entity.Property(x => x.ClassName).HasMaxLength(150);
            entity.Property(x => x.Status).HasMaxLength(32);
        });

        modelBuilder.Entity<Classroom>(entity =>
        {
            entity.Property(x => x.Name).HasMaxLength(150);
            entity.Property(x => x.Subject).HasMaxLength(64);
            entity.Property(x => x.InviteCode).HasMaxLength(32);
            entity.Property(x => x.Schedule).HasMaxLength(100);
            entity.HasIndex(x => x.InviteCode).IsUnique();
        });

        modelBuilder.Entity<Question>(entity =>
        {
            entity.Property(x => x.Subject).HasMaxLength(64).IsRequired();
            entity.Property(x => x.Category).HasMaxLength(100).IsRequired();
            entity.Property(x => x.Difficulty).HasMaxLength(20).IsRequired();
            entity.Property(x => x.QuestionType).HasMaxLength(50).IsRequired();
            entity.Property(x => x.QuestionText).HasMaxLength(4000).IsRequired();
            entity.Property(x => x.OptionsJson).HasMaxLength(4000);
            entity.Property(x => x.CorrectAnswer).HasMaxLength(1000);
            entity.Property(x => x.ExplanationText).HasMaxLength(4000);
            entity.Property(x => x.QuestionData).HasMaxLength(8000);
            entity.Property(x => x.Points).HasPrecision(10, 2);
            entity.Property(x => x.Bookmarked).HasDefaultValue(false);
            entity.HasIndex(x => x.Subject);
            entity.HasIndex(x => x.Category);
            entity.HasIndex(x => x.Difficulty);
        });

        modelBuilder.Entity<MockExam>(entity =>
        {
            entity.Property(x => x.Subject).HasMaxLength(64).IsRequired();
            entity.Property(x => x.Title).HasMaxLength(250).IsRequired();
            entity.Property(x => x.ClassName).HasMaxLength(150).IsRequired();
            entity.Property(x => x.StructureText).HasMaxLength(1000);
            entity.Property(x => x.Status).HasMaxLength(32).IsRequired();
            entity.HasIndex(x => x.Subject);
            entity.HasIndex(x => x.Status);
        });

        modelBuilder.Entity<Announcement>(entity =>
        {
            entity.Property(x => x.Title).HasMaxLength(250).IsRequired();
            entity.Property(x => x.Audience).HasMaxLength(150).IsRequired();
            entity.Property(x => x.State).HasMaxLength(32).IsRequired();
            entity.HasIndex(x => x.CreatedAtUtc);
        });

        modelBuilder.Entity<CalendarEvent>(entity =>
        {
            entity.Property(x => x.Title).HasMaxLength(250).IsRequired();
            entity.Property(x => x.EventType).HasMaxLength(100).IsRequired();
            entity.HasIndex(x => x.StartsAtUtc);
        });

        modelBuilder.Entity<AppUser>(entity =>
        {
            entity.Property(x => x.FullName).HasMaxLength(200).IsRequired();
            entity.Property(x => x.Email).HasMaxLength(320).IsRequired();
            entity.Property(x => x.PasswordHash).HasMaxLength(1024).IsRequired();
            entity.Property(x => x.Role).HasMaxLength(32).IsRequired();
            entity.Property(x => x.PrimarySubject).HasMaxLength(64);
            entity.HasIndex(x => x.Email).IsUnique();
        });

        modelBuilder.Entity<AuthSession>(entity =>
        {
            entity.Property(x => x.Token).HasMaxLength(128).IsRequired();
            entity.HasIndex(x => x.Token).IsUnique();
            entity.HasIndex(x => x.UserId);

            entity.HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
