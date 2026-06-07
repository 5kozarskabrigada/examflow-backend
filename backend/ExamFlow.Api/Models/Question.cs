namespace ExamFlow.Api.Models;

public class Question
{
    public int Id { get; set; }
    public required string Subject { get; set; }
    public required string Category { get; set; }
    public required string Difficulty { get; set; }
    public required string QuestionType { get; set; }
    public required string QuestionText { get; set; }
    public string? Title { get; set; }
    public string? ImageUrl { get; set; }
    public string? AudioUrl { get; set; }
    public string? OptionsJson { get; set; }
    public string? CorrectAnswer { get; set; }
    public string? ExplanationText { get; set; }
    public string? Passage { get; set; }
    public string? QuestionData { get; set; }
    public string? Module { get; set; }
    public string? Topic { get; set; }
    public string? BandTarget { get; set; }
    public string? SkillTested { get; set; }
    public string? TimeRequirement { get; set; }
    public string? Source { get; set; }
    public string? Status { get; set; }
    public string? Tags { get; set; }
    public string? Domain { get; set; }
    public string? Skill { get; set; }
    public bool CalculatorAllowed { get; set; }
    public bool PassageRequired { get; set; }
    public bool ImageRequired { get; set; }
    public bool TableRequired { get; set; }
    public bool GraphRequired { get; set; }
    public bool EquationRequired { get; set; }
    public string? Hint { get; set; }
    public decimal Points { get; set; } = 1m;
    public int CreatedByUserId { get; set; }
    public bool Bookmarked { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}