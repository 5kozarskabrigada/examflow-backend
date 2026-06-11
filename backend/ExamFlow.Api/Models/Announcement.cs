namespace ExamFlow.Api.Models;

public class Announcement
{
    public int Id { get; set; }
    public required string Title { get; set; }
    public required string Audience { get; set; }
    public string State { get; set; } = "Sent";
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
