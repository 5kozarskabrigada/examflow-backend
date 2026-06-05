namespace ExamFlow.Api.Models;

public class Question
{
    public int Id { get; set; }
    public required string Subject { get; set; }
    public required string Category { get; set; }
    public required string Difficulty { get; set; }
    public required string QuestionType { get; set; }
    public required string QuestionText { get; set; }
    public string? OptionsJson { get; set; }
    public string? CorrectAnswer { get; set; }
    public string? ExplanationText { get; set; }
    public string? QuestionData { get; set; }
    public decimal Points { get; set; } = 1m;
    public bool Bookmarked { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}