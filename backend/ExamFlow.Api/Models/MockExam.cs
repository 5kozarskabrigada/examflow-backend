namespace ExamFlow.Api.Models;

public class MockExam
{
    public int Id { get; set; }
    public required string Subject { get; set; }
    public required string Title { get; set; }
    public required string ClassName { get; set; }
    public string? StructureText { get; set; }
    public DateTime? ScheduledForUtc { get; set; }
    public string Status { get; set; } = "Draft";
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
