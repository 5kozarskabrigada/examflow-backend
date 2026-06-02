namespace ExamFlow.Api.Contracts;

public record RegisterRequest(
    string FullName,
    string Email,
    string Password,
    string Role,
    string? PrimarySubject
);

public record LoginRequest(string Email, string Password);

public record AuthUserResponse(
    int Id,
    string FullName,
    string Email,
    string Role,
    string? PrimarySubject
);

public record AuthResponse(string Token, AuthUserResponse User);
