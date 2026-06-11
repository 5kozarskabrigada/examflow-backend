namespace ExamFlow.Api.Models;

public class Student
{
    public int Id { get; set; }
    public required string FullName { get; set; }
    public required string Email { get; set; }
    public string? ExamGoal { get; set; }
    public string? TargetScore { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
