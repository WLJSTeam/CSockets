#:property TargetFramework=net10.0
#:property PublishAot=false

using System.Net;
using System.Net.Sockets;
using System.Text.Json;

const int BufferSize = 64 * 1024;
int port = 8080;
int connectionLimit = int.MaxValue;

if (args.Length > 2 ||
    (args.Length > 0 && (!int.TryParse(args[0], out port) || port is < 0 or > 65535)) ||
    (args.Length > 1 && (!int.TryParse(args[1], out connectionLimit) || connectionLimit <= 0)))
{
    Console.Error.WriteLine("Usage: dotnet run Scripts/DotNetEcho.cs -- [port] [connection-count]");
    return 1;
}

var buffer = new byte[BufferSize];
using var listener = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
Configure(listener);
listener.Bind(new IPEndPoint(IPAddress.Loopback, port));
listener.Listen(128);

Publish(new
{
    Kind = "Ready",
    Address = $"tcp://{listener.LocalEndPoint}",
    PID = Environment.ProcessId,
    Options = GetOptions(listener),
    Runtime = Environment.Version.ToString()
});

for (int index = 0; index < connectionLimit; index++)
{
    using Socket connection = listener.Accept();
    Configure(connection);
    Publish(new { Kind = "Accepted", Index = index + 1, Options = GetOptions(connection) });

    long total = 0;
    while (true)
    {
        int received = connection.Receive(buffer.AsSpan(), SocketFlags.None);
        if (received == 0)
        {
            break;
        }

        int sent = 0;
        while (sent < received)
        {
            int count = connection.Send(buffer.AsSpan(sent, received - sent), SocketFlags.None);
            if (count == 0)
            {
                throw new IOException("TCP echo send made no progress.");
            }

            sent += count;
        }

        total += received;
    }

    Publish(new { Kind = "Closed", Index = index + 1, Bytes = total });
}

return 0;

static void Configure(Socket socket)
{
    socket.ReceiveBufferSize = BufferSize;
    socket.SendBufferSize = BufferSize;
    socket.NoDelay = true;
}

static int[] GetOptions(Socket socket) =>
    [socket.ReceiveBufferSize, socket.SendBufferSize, socket.NoDelay ? 1 : 0];

static void Publish<T>(T value) => Console.WriteLine(JsonSerializer.Serialize(value));
