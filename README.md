# CSockets

CSockets is a Wolfram Language paclet for working with TCP and UDP sockets through a small LibraryLink-backed API.
The public context is <code>WLJS\`CSockets\`</code>.

## Load the package

```wl
Get["WLJS`CSockets`"]
```

## Quick start

### Open a TCP server

```wl
server = CSocketOpen["127.0.0.1", 8080]
```

This creates a listening socket and stores it in the internal socket registry.

### Connect a TCP client

```wl
client = CSocketConnect["127.0.0.1", 8080]
```

### Send and receive data

```wl
listener = SocketListen[server, CSocketHandler[
  "Received" -> (#["DataByteArray"] &)
]];
WriteString[client, "hello"]
message = SocketReadMessage[client]
```

For binary data, use `BinaryWrite`:

```wl
BinaryWrite[client, ByteArray[{104, 101, 108, 108, 111}]]
```

### Close the socket

```wl
RemoveAsynchronousTask[listener];
Close[client]
Close[server]
```

## Reference

### `CSocketOpen`

```wl
CSocketOpen[host, port, protocol]
```

Creates a server socket bound to `host` and `port`.
The default host is `"127.0.0.1"`, the default port is `0`, and the default protocol is `"TCP"`.

#### Examples

```wl
CSocketOpen[8080]
CSocketOpen["127.0.0.1", 8080]
CSocketOpen["127.0.0.1", 8080, "UDP"]
```

### `CSocketConnect`

```wl
CSocketConnect[host, port, protocol, opts]
```

Creates a client socket connected to the remote endpoint.
Pass a numeric IP address; resolve hostnames beforehand with `HostLookup`.
The protocol can be `"TCP"` or `"UDP"`.

#### Options

| Option | Default | Meaning |
| --- | --- | --- |
| `"Wait"` | `False` | If `True`, keep the call in waiting mode instead of temporarily switching the socket to nonblocking mode. |
| `"Blocking"` | `True` | Controls whether the socket is set to blocking mode before the connection attempt. |

#### Examples

```wl
CSocketConnect["127.0.0.1", 8080]
CSocketConnect["127.0.0.1", 8080, "TCP", "Wait" -> True]
CSocketConnect["127.0.0.1", 8080, "TCP", "Blocking" -> False]
CSocketConnect["127.0.0.1", 8080, "UDP"]
```

### `CSocketObject`

`CSocketObject[socketId]` wraps a numeric native descriptor. The `$CSockets` association maps each ID to an association with `"Object"`, `"Protocol"`, `"BlockingMode"`, `"LocalAddress"`, `"RemoteAddress"`, `"State"` and `"Role"`. Closing a socket removes its entry from `$CSockets`. Native functions receive only the descriptor. `socketsCheck[ids]` filters a list of descriptors; `socketsPoll[ids, timeout, eventsMask]` returns pairs `{socketId, eventMask}`.

Native asynchronous polling performs accept/read/close and delivers `"Accepted"`, `"Received"`, `"ReceivedFrom"`, `"Closed"` and `"Error"` events to WL handlers. `socketPollLoopCreate[socketIds, roles, timeout, eventsMask]` copies the initial descriptors and roles into a dynamic list owned entirely by the C task. The list is freed when the loop exits, including cancellation and error paths. Cancel a listener with `RemoveAsynchronousTask[task]`; this releases the list without closing sockets that remain open.

Common properties:

| Property | Result |
| --- | --- |
| `"DirectionType"` | `"Server"` or `"Client"`. |
| `"Protocol"` | `"TCP"` or `"UDP"`. |
| `"Scheme"` | `"tcp"` or `"udp"`. |
| `"UUID"` | Socket identifier. |
| `"Role"` | `"Undefined"`, `"Binded"`, `"Connected"` or `"Accepted"`. |
| `"State"` | `"Alive"` or `"Closed"`. |
| `"BlockingMode"` | `"Blocking"` or `"NonBlocking"`. |
| `"LocalAddress"`, `"RemoteAddress"` | Stored local and remote endpoints. |
| `"Addresses"` | `{localEndpoint, remoteEndpoint}`; missing endpoints are `""`. |
| `"InprocQ"` | Always `False` in this implementation. |

#### Example

```wl
socket = CSocketOpen["127.0.0.1", 8080];
{
  socket["Addresses"],
  socket["DirectionType"],
  socket["Protocol"],
  socket["Scheme"],
  socket["UUID"]
}
```

### Sending and reading

```wl
BinaryWrite[socket, bytes]
BinaryWrite[socket, address, bytes]
WriteString[socket, text]
WriteString[socket, address, text]
```

The address argument is a string such as `"127.0.0.1:8080"` or `"[::1]:8080"`. It selects
the destination of a UDP datagram. Strings are converted to UTF-8 bytes before
sending. The wrappers send any remaining bytes in a loop and return the total
number sent. A send error or zero progress returns a `Failure` with the native
function name, socket ID, and byte counts.

`SocketReadMessage[socket]` returns a `ByteArray` for TCP. For both UDP clients
and UDP servers it returns `{data, address}` directly from the native result,
where `data` is a `NumericArray` and `address` is a string. Empty UDP data is returned as `{}`.

```wl
{data, address} = SocketReadMessage[udpSocket];
BinaryWrite[udpSocket, address, ByteArray[data]];
```

The private native functions are `socketRecv[socketRow, buffer]` and
`socketRecvFrom[socketRow, buffer]`; both infer the capacity of the byte buffer.
`socketRecvFrom` returns a ``Developer`DataStore`` containing data followed by
the sender address. `SocketReadMessage` converts that container to a list.

### `SocketReadyQ`

`SocketReadyQ[socket, timeout]` checks whether a socket has pending activity.
It returns `True` or `False` when the poll succeeds and a `Failure` if polling fails.

#### Example

```wl
SocketReadyQ[client]
SocketReadyQ[client, 0.25]
```

### `Close`

`Close` is overloaded for `CSocketObject`.
It removes the socket from the internal registry and closes the underlying native socket.

#### Example

```wl
Close[client]
Close[server]
```

### `SocketListen`

`SocketListen[socket, handler]` starts an asynchronous listener for one socket.
`SocketListen[{socket1 -> handler1, socket2 -> handler2, ...}]` starts one polling
loop and forwards each socket's events to its assigned handler. The returned
`AsynchronousTaskObject` controls the listener.

Bindings can also be passed as an association of `socket -> handler` rules or
a list of `{socket, handler}` pairs.

```wl
handler = CSocketHandler[
  "Received" -> (Print[#["Data"]] &)
];

listener = SocketListen[server, handler];
```

Use `"EventConverter" -> converter` with either form of `SocketListen` to
customize the association passed to the handler. The converter takes one
argument, `{task, name, data}`. Without this option, `SocketListen` produces
the standard event association.

The callback receives event associations such as:

```wl
<|
  "Event" -> "Received",
  "SourceSocket" -> socket,
  "Data" -> "hello",
  "DataBytes" -> {104, 101, 108, 108, 111},
  "DataByteArray" -> ByteArray[{104, 101, 108, 108, 111}]
|>
```

### `CSocketHandle`

`CSocketHandle[{socket1 -> handler1, socket2 -> handler2, ...}]` runs a
synchronous polling loop in the current kernel. Each socket has its own handler.
Use it in a server script without a separate
`While[True, Pause[1]]`:

```wl
tcpServer = CSocketOpen["127.0.0.1", 8080];
udpServer = CSocketOpen["127.0.0.1", 8080, "UDP"];
tcpHandler = CSocketHandler[
  "Deserializer" -> ByteArrayToString,
  "Received" -> (ToUpperCase[#Data] &)
];
udpHandler = CSocketHandler[
  "ReceivedFrom" -> (#DataByteArray &)
];

CSocketHandle[{
  tcpServer -> tcpHandler,
  udpServer -> udpHandler
}];
```

The bindings may contain multiple TCP and UDP servers, connected sockets, and
accepted TCP sockets. `CSocketHandle` accepts the same binding forms and
`"EventConverter"` option as `SocketListen`. A ready TCP server accepts a
connection and adds it to the loop. Connected and accepted TCP sockets produce
`"Received"` events. UDP sockets produce `"ReceivedFrom"` events with the
sender's `"Address"`.
Accepted sockets inherit their server's handler and retain their `"ListenSocket"`,
including after the listening socket is closed. Each socket's data, accept,
close, and error events go to its assigned handler. If a socket appears more
than once, its last rule supplies the handler.

`CSocketHandle` and `SocketListen` use the same event associations,
`CSocketHandler` callbacks, buffering, and serialization. An ordinary function
can handle the same association and return a string or `ByteArray` to reply to
received data. In synchronous mode `"Task"` is `Null`. In asynchronous mode it
contains the `AsynchronousTaskObject`.
In synchronous mode, an `"Error"` event reports the error flags for an
individual socket.

The loop requests one second of polling in slices of up to 5 ms and removes
sockets with terminal events. OS timer rounding can extend the elapsed wait.
It returns `Null` when no sockets remain and a `Failure` if a poll,
accept, read, or close operation fails. Sockets that are still open after
failure or abort remain available through `$CSockets` and can be closed with
`Close`.

## `CSocketHandler`

`CSocketHandler[]` creates a mutable handler object.
The handler stores callbacks and helper functions under named keys.

Calling `handler[packet]` returns the packet association with an added `"Result"`
field for completed messages. Each packet carries its `"Handler"`. For
`"Received"` and `"ReceivedFrom"`, the handler first calculates `"DataLength"`,
`"ExpectedLength"`, `"StoredLength"`, and `"Completed"`. Incomplete packets are
buffered and logged without invoking the deserializer, callback, or sender.
TCP buffers are separated by socket; UDP buffers are also separated by sender
address. Multiple complete messages in one read are processed separately, and
any trailing fragment stays buffered.

Once complete, `"DataByteArray"` and `"DataBytes"` hold the assembled message and
`"Data"` is the result of `"Deserializer"` applied to those bytes. Its default
is the identity function, so use `"Deserializer" -> ByteArrayToString` for text.
The callback result is passed through
`"Serializer"`, stored in `"Result"`, and sent to `"SourceSocket"`. If the packet
has `"Address"`, that address is passed to `BinaryWrite` or `WriteString`.
A callback may return a string, `ByteArray`, or `Null`; `Null` means no reply.

`"Logger"` receives the complete packet after sending. All incoming fields,
including raw request data and any length metadata, are retained. Its return
value does not replace the packet. Callbacks for other events also have their
return value stored in `"Result"` and are logged, but do not send a reply.

Internally, `sendResponse[packet]` takes only the packet. A missing `"Result"`
or a `Null` result causes no send.

Handler keys are flat. For example, `handler["Logger"] = Function[p, Print[p]]`
sets the logger, and `handler["Logger", packet]` invokes it.

### Options

| Option | Default | Meaning |
| ---               | --- | --- |
| `"Logger"`      | `Function[#]` | Receives the final packet after sending. |
| `"Buffer"`       | `CreateDataStructure["HashTable"]` | Stores incomplete message fragments. |
| `"Serializer"`    | `Function[#]` | Postprocesses handler results before they are sent. |
| `"Deserializer"` | `Function[#]` | Converts the complete message bytes into `"Data"`. |
| `"Accumulator"` | `Function[Length[#DataByteArray]]` | Computes expected message length from the first fragment. |
| `"Received"` | Process and log received messages. | Callback for received data. |
| `"ReceivedFrom"` | Process and log received datagrams. | Callback for UDP data, including the sender's `"Address"`. |
| `"Accepted"` | Register the accepted socket. | Callback for accepted connections. |
| `"Closed"` | Remove the socket and its buffered data. | Callback for socket close events. |
| `"Error"` | Remove the socket and its buffered data if the socket is invalid. | Callback for error events. |

Lifecycle actions run before custom callbacks. Data callbacks run on complete
messages after deserialization. The returned response is serialized and sent
when non-null.

### Example

```wl
handler = CSocketHandler[
  "Logger" -> (Print["log: ", #] &),
  "Deserializer" -> ByteArrayToString,
  "Received" -> (Print["received: ", #Data] &),
  "Accepted" -> (Print["accepted: ", #AcceptedSocket] &),
  "Closed" -> (Print["closed: ", #ClosedSocket] &),
  "Error" -> (Print["error: ", #ErrorCode] &)
];
```

## Building

```shell
wolframscript -f Build.wls
```

## Tests

Run the Wolfram tests with:

```shell
wolframscript -file Tests/AddressTest.wlt
```

The `Tests/` directory covers socket I/O, UDP addresses and replies, asynchronous
events, shared ownership, partial sends, and final packet logging. Run Wolfram
test processes sequentially.

## Demo scripts

```shell
wolframscript -f Example.wls -p 8080
```

The `Scripts/` folder also contains sample programs such as `Echo.wls`, `HTTPEcho.wls`, `TCPStreamingServer.wls`, and `SpeedTestServer.wls`.

### Synchronous server latency benchmark

```powershell
python Scripts/LatencyBenchmark.py
```

This starts one Wolfram kernel running `CSocketHandle` with separate
`CSocketHandler` byte echo handlers for TCP and UDP. A Python client measures
round-trip time on `127.0.0.1`: immediately before sending a request until its
entire echo is received. Every response is validated outside the timed interval.
There is one outstanding request at a time, no pipelining, and one persistent
TCP connection with `TCP_NODELAY` enabled on both ends. TCP echoes each read;
the client assembles exactly the original request length, including split reads.

By default it measures 1, 64, 1024, 8192, and 65500 bytes in each direction,
using three rounds of 1000 samples per case and 100 untimed warmup exchanges
before each batch. The case order is shuffled in each round with a fixed seed.
Server startup and connection setup are excluded. The server polls its TCP,
UDP, and shutdown sockets together; the data handler uses its default serializer,
deserializer, accumulator, and logger, with no printing per request.

The script prints a table in milliseconds with minimum, median, mean, p95, p99,
and maximum RTT. It saves the individual nanosecond samples, per-round summaries,
environment, and method to `benchmarks/SynchronousLatency.json`. Results describe
local application RTT, including the Python client, OS scheduling, and the WL
handler pipeline, rather than network latency between two machines.
Completed batches are also checkpointed to `*.attemptN.partial.json` outside
the timed intervals. If the server crashes, these files preserve the completed
batches; the script exits unsuccessfully rather than publishing a complete run.

```powershell
python Scripts/LatencyBenchmark.py --samples 2000 --rounds 3 --warmup 200
python Scripts/LatencyBenchmark.py --sizes 1 64 1024 --output benchmarks/SmallMessages.json
```

To bypass user initialization or select a specific Wolfram installation, pass
its console executable. This launches it directly with `-noinit -script`:

```powershell
python Scripts/LatencyBenchmark.py --kernel "C:/Program Files/Wolfram Research/Wolfram/15.0/WolframKernel.exe"
```

The measured summary in `benchmarks/SynchronousLatencySummary.json` reports the
completed first round (1000 RTTs per case) of an interrupted three-round run.
It records the subsequent native process failure and the availability of raw
samples explicitly. `benchmarks/SynchronousLatencySmoke.json` contains the raw
samples from a separate successful short validation run.

## Address strings

UDP `ReceivedFrom` events include `"Address" -> "127.0.0.1:8080"` or an IPv6
endpoint such as `"[::1]:8080"`. Scoped IPv6 addresses retain their numeric scope,
for example `"[fe80::1%3]:8080"`.

```wl
address = event["Address"];
BinaryWrite[event["SourceSocket"], address, ByteArray[{1, 2, 3}]];
```

The native `socketBind`, `socketConnect`, and `socketSendTo` functions take
separate numeric host and port strings. Address structures remain internal to C.


### Build script

Run from the repository root:

```powershell
wolframscript -f Build.wls
wolframscript -f Build.wls "build/custom.dll" "Kernel/Custom.wl"
wolframscript -f Tests/BuildTest.wls
```

Both positional arguments are optional. The defaults are
`LibraryResources/<SystemID>-v<LibraryLinkVersion>/csockets.<extension>` and
`Kernel/CSockets.wl`. Explicit paths are relative to the current directory.
Use the platform extension (`.dll`, `.so`, or `.dylib`). The bindings target
must be an existing `.wl` file containing `End[];`. The generator replaces
the section between `(* :LibraryLoad: *)` and the following `End[];`, or
inserts that section before the first `End[];` when the marker is absent.
An explicit library argument also writes its resolved path into the generated
section so the bindings load that library.

C extraction uses tokens and balanced delimiters rather than physical lines.
Comments, quoted literals, nested blocks, and multiline declarations/calls are
supported. Getter indices must be literal contiguous `Args[0]`, `Args[1]`, etc.
Argument names come from the variable initialized by the getter; casts are
allowed. Unknown LibraryLink types and ambiguous tensor ranks stop the build
before modifying the bindings. This is a source parser, not a C preprocessor:
macro-generated exports and conditional compilation require explicit source
conventions. Tensor results currently require an integer tensor with a literal
rank. Result expressions without a single variable name use the return type
in the usage text.


Native array conversions are declared in `Source/common.h`:

- `MNumericArrayFromByte(libData, bytes, length)` copies bytes into a new UBit8 vector.
- `ByteFromMNumericArray(libData, array, &length)` borrows the byte buffer; do not free it or retain it after the array is released.
- `MTensorFromSocket(libData, sockets, length)` copies native descriptors into an integer vector.
- `SocketFromMTensor(libData, tensor, &length)` allocates a native descriptor buffer; release it with `free`.

Constructors return `NULL` on invalid input or allocation failure. Empty input is supported.
The reverse byte conversion requires a rank-one UBit8 array, and the reverse socket
conversion requires a rank-one integer tensor. These helpers do not disown LibraryLink
arguments: callers use standard `MArgument_get/setMNumericArray`, `MArgument_get/setMTensor`
and the corresponding LibraryLink release functions.
