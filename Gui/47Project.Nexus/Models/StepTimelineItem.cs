using System;
using _47Project.Nexus.Common;

namespace _47Project.Nexus.Models;

/// <summary>
/// Aggregated view of a plan step built from journal events.
/// </summary>
public sealed class StepTimelineItem : ObservableObject
{
    private string _stepId = "";
    public string StepId { get => _stepId; set => SetProperty(ref _stepId, value); }

    private string? _stepType;
    public string? StepType { get => _stepType; set => SetProperty(ref _stepType, value); }

    private string _status = "created";
    public string Status { get => _status; set => SetProperty(ref _status, value); }

    private string? _message;
    public string? Message { get => _message; set => SetProperty(ref _message, value); }

    private DateTime? _startedUtc;
    public DateTime? StartedUtc { get => _startedUtc; set { if (SetProperty(ref _startedUtc, value)) RaisePropertyChanged(nameof(Duration)); } }

    private DateTime? _endedUtc;
    public DateTime? EndedUtc { get => _endedUtc; set { if (SetProperty(ref _endedUtc, value)) RaisePropertyChanged(nameof(Duration)); } }

    public TimeSpan? Duration
    {
        get
        {
            if (_startedUtc is null) return null;
            var end = _endedUtc ?? DateTime.UtcNow;
            return end - _startedUtc.Value;
        }
    }


    public void RefreshDuration() => Raise(nameof(Duration));
}
