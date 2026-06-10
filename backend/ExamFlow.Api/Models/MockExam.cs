namespace ExamFlow.Api.Models;

public class MockExam
{
    public int Id { get; set; }
    public required string Subject { get; set; }
    public required string Title { get; set; }
    public required string ClassName { get; set; }
    public string? StructureText { get; set; }
    public string? Description { get; set; }
    public string? Code { get; set; }
    public string? ExamType { get; set; }
    public int? TotalQuestions { get; set; }
    public int? TotalPoints { get; set; }
    public int? DurationMinutes { get; set; }
    public string? SecurityLevel { get; set; }
    public DateTime? ScheduledForUtc { get; set; }
    public int? CreatedByUserId { get; set; }
    public string Status { get; set; } = "Draft";
    public DateTime? DeletedAt { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
