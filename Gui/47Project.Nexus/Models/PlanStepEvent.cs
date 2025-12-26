namespace _47Project.Nexus.Models;

public sealed record PlanStepEvent(
    string Kind,
    string? StepId,
    string? StepType,
    string Status,
    string? Message,
    string TsUtc
);
