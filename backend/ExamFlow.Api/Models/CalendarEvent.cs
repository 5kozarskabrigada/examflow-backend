namespace ExamFlow.Api.Models;

public class CalendarEvent
{
    public int Id { get; set; }
    public required string Title { get; set; }
    public required string EventType { get; set; }
    public DateTime StartsAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
