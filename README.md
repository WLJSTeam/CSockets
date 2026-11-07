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
WriteString[client, "hello"]
message = SocketReadMessage[server]
```

For binary data, use `BinaryWrite`:

```wl
BinaryWrite[client, ByteArray[{104, 101, 108, 108, 111}]]
```

### Close the socket

```wl
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

`CSocketObject[id]` is the internal representation of a socket.

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

### Options

| Option | Default | Meaning |
| ---               | --- | --- |
| `"Logger"`      | `Function[#]` | Called for logging or tracing. |
| `"Buffer"`       | `CreateDataStructure["HashTable"]` | Per-socket accumulation buffer. |
| `"Serializer"`    | `Function[#]` | Postprocesses handler results before they are sent. |
| `"Deserializer"` | `Function[#]` | Converts incoming bytes into higher-level data. |
| `"Accumulator"` | `Function[Length[#DataByteArray]]` | Computes the expected message length from an incoming packet. |
| `"Received"` | `Function[Null]` | Callback for received data. |
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

The test file checks the public object accessors, event conversion helpers, handler defaults, and packet length calculation logic.

## Demo scripts

```shell
wolframscript -f Example.wls -p 8080
```

The `Scripts/` folder also contains sample programs such as `Echo.wls`, `HTTPEcho.wls`, `TCPStreamingServer.wls`, and `SpeedTestServer.wls`.
