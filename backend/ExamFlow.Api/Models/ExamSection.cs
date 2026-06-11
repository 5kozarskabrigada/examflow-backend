namespace ExamFlow.Api.Models;

public class ExamSection
{
    public int Id { get; set; }
    public int ExamId { get; set; }
    public string ModuleType { get; set; } = "reading"; // reading, listening, writing, speaking
    public int SectionOrder { get; set; }
    public string Title { get; set; } = "";
    public string? Content { get; set; } // Passage or prompt text
    public string? AudioUrl { get; set; } // For listening sections
    public int DurationMinutes { get; set; } = 0;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
