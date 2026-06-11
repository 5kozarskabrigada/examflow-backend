namespace ExamFlow.Api.Models;

public class Assignment
{
    public int Id { get; set; }
    public required string Title { get; set; }
    public required string ClassName { get; set; }
    public DateTime DueAtUtc { get; set; }
    public int QuestionCount { get; set; }
    public string Status { get; set; } = "Pending";
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
