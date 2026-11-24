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

`CSocketObject[socketId]` wraps a numeric native descriptor. The `$CSockets` association maps each ID to an association with `"Object"`, `"Protocol"`, `"BlockingMode"`, `"LocalAddress"`, `"RemoteAddress"`, `"State"` and `"Role"`. Closed sockets retain their last addresses and `"State" -> "Closed"` until the descriptor is reused. Native functions receive only the descriptor. `socketsCheck[ids]` filters a list of descriptors; `socketsPoll[ids, timeout, eventsMask]` returns pairs `{socketId, eventMask}`.

Native asynchronous polling reports `"Polled"` with the same pairs. The WL wrappers perform accept/read/close and deliver `"Accepted"`, `"Received"`, `"ReceivedFrom"`, `"Closed"` and `"Error"` events to handlers. Listening switches the monitored sockets to nonblocking mode. Close a `CSocketList` to stop its task and release the list without closing its sockets. Closing a socket passed directly to `SocketListen` also releases its internally created list.

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

### `CSocketList`

```wl
CSocketList[{socket1, socket2, ...}]
```

Creates a socket list object for polling multiple sockets at once.

### Sending and reading

```wl
BinaryWrite[socket, bytes]
BinaryWrite[socket, address, bytes]
WriteString[socket, text]
WriteString[socket, address, text]
```

The address argument is a string such as `"127.0.0.1:8080"` or `"[::1]:8080"`. It selects
the destination of a UDP datagram. Strings are converted to UTF-8 bytes before
sending. The wrappers recursively send any remaining bytes and return the total
number sent; an error stops sending, and zero progress returns `$Failed`.

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
For a connected socket it returns `True` or `False`; if the socket is invalid or no longer connected, it returns `$Failed`.

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

`SocketListen` is overloaded for both `CSocketObject` and `CSocketList`.
It starts an asynchronous polling loop and forwards events to the handler.

```wl
handler = CSocketHandler[
  "Received" -> (Print[#["Data"]] &)
];

listener = SocketListen[server, handler];
```

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
| `"Received"` | `Function[Null]` | Callback for received data. |
| `"ReceivedFrom"` | `Function[Null]` | Callback for UDP data, including the sender's `"Address"`. |
| `"Accepted"` | `Function[Null]` | Callback for accepted connections. |
| `"Closed"` | `Function[Null]` | Callback for socket close events. |
| `"Error"` | `Function[Null]` | Callback for error events. |

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
