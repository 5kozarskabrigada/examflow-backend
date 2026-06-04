namespace ExamFlow.Api.Models;

public class Classroom
{
    public int Id { get; set; }
    public required string Name { get; set; }
    public required string Subject { get; set; }
    public required string InviteCode { get; set; }
    public string? Schedule { get; set; }
    public int StudentCount { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
