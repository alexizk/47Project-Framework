using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using _47Project.Nexus.Models;

namespace _47Project.Nexus.Services;

public sealed class JournalTailService
{
    public event Action<PlanStepEvent>? OnEvent;

    public Task StartAsync(string journalPath, CancellationToken ct)
    {
        return Task.Run(async () =>
        {
            Directory.CreateDirectory(Path.GetDirectoryName(journalPath)!);

            using var fs = new FileStream(journalPath, FileMode.OpenOrCreate, FileAccess.Read, FileShare.ReadWrite);
            using var sr = new StreamReader(fs);

            while (!ct.IsCancellationRequested)
            {
                var line = await sr.ReadLineAsync().ConfigureAwait(false);
                if (line is null)
                {
                    await Task.Delay(200, ct).ConfigureAwait(false);
                    continue;
                }

                try
                {
                    var doc = JsonDocument.Parse(line);
                    var root = doc.RootElement;

                    var kind = root.TryGetProperty("kind", out var k) ? k.GetString() ?? "" : "";
                    var stepId = root.TryGetProperty("stepId", out var sid) ? sid.GetString() : null;
                    var stepType = root.TryGetProperty("stepType", out var st) ? st.GetString() : null;
                    var status = root.TryGetProperty("status", out var s) ? s.GetString() ?? "" : "";
                    var message = root.TryGetProperty("message", out var m) ? m.GetString() : null;
                    var tsUtc = root.TryGetProperty("tsUtc", out var t) ? t.GetString() ?? "" : "";

                    OnEvent?.Invoke(new PlanStepEvent(kind, stepId, stepType, status, message, tsUtc));
                }
                catch
                {
                    // ignore malformed lines
                }
            }
        }, ct);
    }
}
