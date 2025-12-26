using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace _47Project.Nexus.Services;

public sealed class RunspaceJobDispatcher : IDisposable
{
    private readonly RunspacePool _pool;

    public RunspaceJobDispatcher()
    {
        var iss = InitialSessionState.CreateDefault();
        // You can lock down the session state here later (restricted mode for GUI).
        _pool = RunspacePoolFactory.CreateRunspacePool(1, Environment.ProcessorCount, iss, host: null);
        _pool.Open();
    }

    public Task<IReadOnlyList<PSObject>> InvokeAsync(string script, Dictionary<string, object?>? parameters, CancellationToken ct)
    {
        return Task.Run(() =>
        {
            using var ps = PowerShell.Create();
            ps.RunspacePool = _pool;

            ps.AddScript(script, useLocalScope: true);
            if (parameters is not null)
            {
                foreach (var kv in parameters)
                    ps.AddParameter(kv.Key, kv.Value);
            }

            // Cancellation: stop the pipeline.
            using var reg = ct.Register(() => { try { ps.Stop(); } catch { } });

            var result = ps.Invoke();

            if (ps.HadErrors)
            {
                var err = ps.Streams.Error.FirstOrDefault()?.ToString() ?? "Unknown PowerShell error.";
                throw new InvalidOperationException(err);
            }

            return (IReadOnlyList<PSObject>)result;
        }, ct);
    }

    public void Dispose()
    {
        try { _pool.Close(); } catch { }
        try { _pool.Dispose(); } catch { }
    }
}
