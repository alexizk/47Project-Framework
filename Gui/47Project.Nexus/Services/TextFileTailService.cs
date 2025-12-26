using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace _47Project.Nexus.Services;

/// <summary>
/// Tails a UTF-8 text file and emits appended text chunks.
/// Works with files that are created later and with writers that keep the file open.
/// </summary>
public sealed class TextFileTailService
{
    public Task TailAsync(
        string filePath,
        Action<string> onAppend,
        CancellationToken ct,
        int pollMs = 150,
        long? initialPosition = null)
    {
        return Task.Run(async () =>
        {
            long position = initialPosition ?? 0;

            while (!ct.IsCancellationRequested)
            {
                try
                {
                    if (!File.Exists(filePath))
                    {
                        await Task.Delay(pollMs, ct).ConfigureAwait(false);
                        continue;
                    }

                    using var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);

                    // If file was (re)created, start from 0 unless an explicit initial position was requested.
                    if (initialPosition is null && position == 0 && fs.Length == 0)
                    {
                        // nothing yet
                    }

                    // Handle truncation/rotation
                    if (position > fs.Length)
                        position = 0;

                    fs.Seek(position, SeekOrigin.Begin);

                    if (fs.Length > position)
                    {
                        var toRead = (int)Math.Min(64 * 1024, fs.Length - position);
                        var buf = new byte[toRead];
                        var read = await fs.ReadAsync(buf.AsMemory(0, toRead), ct).ConfigureAwait(false);
                        if (read > 0)
                        {
                            position += read;
                            var chunk = Encoding.UTF8.GetString(buf, 0, read);
                            if (!string.IsNullOrEmpty(chunk))
                                onAppend(chunk);
                        }
                    }
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch
                {
                    // ignore transient read errors (file locked, etc.)
                }

                await Task.Delay(pollMs, ct).ConfigureAwait(false);
            }
        }, ct);
    }
}
