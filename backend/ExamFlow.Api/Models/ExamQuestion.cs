namespace ExamFlow.Api.Models;

public class ExamQuestion
{
    public int Id { get; set; }
    public int ExamId { get; set; }
    public int QuestionId { get; set; }
    public string? Section { get; set; }
    public string? Module { get; set; }
    public int OrderIndex { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    
    // Navigation properties
    public MockExam? Exam { get; set; }
    public Question? Question { get; set; }
}
