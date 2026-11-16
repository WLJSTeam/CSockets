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
server = CSocketOpen["localhost", 8080]
```

This creates a listening socket and stores it in the internal socket registry.

### Connect a TCP client

```wl
client = CSocketConnect["localhost", 8080]
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
The default host is `"localhost"`, the default port is `0`, and the default protocol is `"TCP"`.

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
The protocol can be `"TCP"` or `"UDP"`.

#### Options

| Option | Default | Meaning |
| --- | --- | --- |
| `"Wait"` | `False` | If `True`, keep the call in waiting mode instead of temporarily switching the socket to nonblocking mode. |
| `"Blocking"` | `True` | Controls whether the socket is set to blocking mode before the connection attempt. |

#### Examples

```wl
CSocketConnect["localhost", 8080]
CSocketConnect["localhost", 8080, "TCP", "Wait" -> True]
CSocketConnect["localhost", 8080, "TCP", "Blocking" -> False]
CSocketConnect["127.0.0.1", 8080, "UDP"]
```

### `CSocketObject`

`CSocketObject[{socket, protocol, type, role, state, mode}]` wraps the six-integer native socket structure. Bulk native functions accept an N x 6 integer matrix; `socketsCheck` and `socketsSelect` return rows in the same format. `socketsPoll` returns N x 7 rows: six socket fields followed by the event mask. Asynchronous events carry a six-field socket row (and a second row for accepted connections).

Common properties:

| Property | Result |
| --- | --- |
| `"DestinationPort"` | Bound port number. |
| `"DirectionType"` | `"Server"` or `"Client"`. |
| `"Protocol"` | `"TCP"` or `"UDP"`. |
| `"Scheme"` | `"tcp"` or `"udp"`. |
| `"UUID"` | Socket identifier. |
| `"InprocQ"` | Always `False` in this implementation. |

#### Example

```wl
socket = CSocketOpen["localhost", 8080];
{
  socket["DestinationPort"],
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
BinaryWrite[socket, addressStorage, bytes]
WriteString[socket, text]
WriteString[socket, addressStorage, text]
```

The address argument is an `AddressStorage[ByteArray[...]]` object. It selects
the destination of a UDP datagram. Strings are converted to UTF-8 bytes before
sending. The wrappers recursively send any remaining bytes and return the total
number sent; an error stops sending, and zero progress returns `$Failed`.

`SocketReadMessage[socket]` returns a `ByteArray` for TCP. For both UDP clients
and UDP servers it returns `{data, address}` directly from the native result,
with `NumericArray` values. Empty UDP data is returned as `{}`.

```wl
{data, address} = SocketReadMessage[udpSocket];
BinaryWrite[udpSocket, AddressStorage[ByteArray[address]], ByteArray[data]];
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
has `"AddressStorage"`, that address is passed to `BinaryWrite` or `WriteString`.
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
| `"ReceivedFrom"` | `Function[Null]` | Callback for UDP data, including the sender's `"AddressStorage"`. |
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

## Address storage

UDP `ReceivedFrom` events include `"AddressStorage" -> AddressStorage[storage]`.
The wrapper reads native address bytes through LibraryLink:

```wl
address = event["AddressStorage"];
address["Host"]
address["Port"]
address["Family"]
```

`"Host"` is a numeric IPv4/IPv6 address without reverse DNS or an IPv6 zone suffix.
`"Family"` is `"IPv4"` or `"IPv6"`.
Raw `sockaddr_storage` bytes use the current platform's ABI and should not be
exchanged between platforms as a portable address format.
