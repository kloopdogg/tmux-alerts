using System.Collections.Concurrent;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;

var sessions = new ConcurrentDictionary<string, Session>();
var notifications = new ConcurrentDictionary<string, Notification>();
var wsConnections = new List<WebSocket>();
var wsLock = new object();
var broadcastGate = new SemaphoreSlim(1, 1);
var jsonOptions = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

var builder = WebApplication.CreateBuilder(args);
builder.Logging.SetMinimumLevel(LogLevel.Warning);
var app = builder.Build();

app.UseWebSockets();
app.UseDefaultFiles();
app.UseStaticFiles();

// Hook: register or update a session
app.MapPost("/register", async (RegisterRequest req) =>
{
    sessions[req.SessionId] = new Session(req.SessionId, req.TmuxTarget, req.Project, DateTime.UtcNow);
    await Broadcast();
    return Results.Ok();
});

// Hook: notification event — also upserts the session so register.sh is optional
app.MapPost("/notify", async (NotifyRequest req) =>
{
    sessions.AddOrUpdate(
        req.SessionId,
        new Session(req.SessionId, req.TmuxTarget, req.Project, DateTime.UtcNow),
        (_, existing) => existing with { TmuxTarget = req.TmuxTarget, Project = req.Project }
    );

    var id = Guid.NewGuid().ToString("N");
    notifications[id] = new Notification(id, req.SessionId, req.Message, req.HookType, req.Project, DateTime.UtcNow, false);
    await Broadcast();
    return Results.Ok();
});

// Dashboard: dismiss notification
app.MapPost("/dismiss/{id}", async (string id) =>
{
    if (!notifications.TryGetValue(id, out var n)) return Results.NotFound();
    notifications[id] = n with { Dismissed = true };
    await Broadcast();
    return Results.Ok();
});

// Dashboard: dismiss all notifications
app.MapPost("/dismiss-all", async () =>
{
    foreach (var id in notifications.Keys)
        if (notifications.TryGetValue(id, out var n) && !n.Dismissed)
            notifications[id] = n with { Dismissed = true };
    await Broadcast();
    return Results.Ok();
});

// Dashboard: initial state on load
app.MapGet("/state", () => Results.Json(CurrentState(), jsonOptions));

// Dashboard: WebSocket for real-time push
app.Map("/ws", async (HttpContext ctx) =>
{
    if (!ctx.WebSockets.IsWebSocketRequest) { ctx.Response.StatusCode = 400; return; }

    var ws = await ctx.WebSockets.AcceptWebSocketAsync();
    lock (wsLock) { wsConnections.Add(ws); }

    await Broadcast();

    var buf = new byte[256];
    while (ws.State == WebSocketState.Open)
    {
        try
        {
            var result = await ws.ReceiveAsync(buf, CancellationToken.None);
            if (result.MessageType == WebSocketMessageType.Close) break;
        }
        catch { break; }
    }

    lock (wsLock) { wsConnections.Remove(ws); }
    try { await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, null, CancellationToken.None); } catch { }
});

Console.WriteLine("tmux-alerts  >  http://localhost:7777");
app.Run("http://0.0.0.0:7777");

// ── helpers ──────────────────────────────────────────────────────────────────

object CurrentState() => new
{
    sessions = sessions.Values.OrderBy(s => s.Project).ToList(),
    notifications = notifications.Values
        .Where(n => !n.Dismissed)
        .OrderByDescending(n => n.ReceivedAt)
        .ToList()
};

async Task Broadcast()
{
    await broadcastGate.WaitAsync();
    try
    {
        var bytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(CurrentState(), jsonOptions));

        List<WebSocket> snapshot;
        lock (wsLock) { snapshot = [.. wsConnections]; }

        var dead = new List<WebSocket>();
        foreach (var ws in snapshot)
        {
            if (ws.State != WebSocketState.Open) { dead.Add(ws); continue; }
            try { await ws.SendAsync(bytes, WebSocketMessageType.Text, true, CancellationToken.None); }
            catch { dead.Add(ws); }
        }

        if (dead.Count > 0)
            lock (wsLock) { foreach (var d in dead) wsConnections.Remove(d); }
    }
    finally { broadcastGate.Release(); }
}

// ── models ───────────────────────────────────────────────────────────────────

record Session(string SessionId, string TmuxTarget, string Project, DateTime RegisteredAt);
record Notification(string Id, string SessionId, string Message, string HookType, string Project, DateTime ReceivedAt, bool Dismissed);
record RegisterRequest(string SessionId, string TmuxTarget, string Project);
record NotifyRequest(string SessionId, string Message, string HookType, string Project, string TmuxTarget);
