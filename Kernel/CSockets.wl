(* ::Package:: *)

BeginPackage["WLJS`CSockets`",
    {
        "LibraryLink`"
    }
];


$CSockets::usage =
"$CSockets - association of socket IDs to objects and metadata.";


CSocketOpen::usage =
"CSocketOpen[host, port, protocol]";


CSocketConnect::usage =
"CSocketConnect[host, port, protocol]";


CSocketObject::usage =
"CSocketObject[socketId] wraps a socket descriptor; metadata is stored in Wolfram Language.";


CSocketHandler::usage =
"CSocketHandler[] mutable handler object.";


CSocketHandle::usage =
"CSocketHandle[{socket1 -> handler1, socket2 -> handler2, ...}] synchronously polls sockets and dispatches events to each socket's handler until all sockets are closed or evaluation is aborted.";


Begin["`Private`"];


(* :REGISTRY: *)


$CSockets = If[AssociationQ[$CSockets],
     $CSockets,
     <||>
];


(* :OPEN: *)


CSocketOpen[address__] /; addressQ[address] :=
Catch @ With[{
    addressAssoc = splitAddress[address]}, {
    host = addressAssoc["Host"],
    port = addressAssoc["Port"],
    family = addressAssoc["Family"],
    protocol = addressAssoc["Protocol"]}, {
    socketId = createSocket[family, protocol]
},
    bind[socketId, host, port];

    If[protocol === "TCP", listen[socketId]];

    (*Return*)
    CSocketObject[socketId]
];


(* :CONNECT: *)


Options[CSocketConnect] = {
    "Wait" -> True
};


CSocketConnect[address__, opts: OptionsPattern[]] /; addressQ[address] :=
Catch @ Module[{wait = OptionValue["Wait"], addressAssoc, socketId},
    optionValidQ["Wait", wait, BooleanQ];
    addressAssoc = splitAddress[address];
    socketId = createSocket[addressAssoc["Family"], addressAssoc["Protocol"]];

    If[!wait, toNonBlocking[socketId]];
    connect[socketId, addressAssoc["Host"], addressAssoc["Port"]];
    If[!wait, toBlocking[socketId]];

    CSocketObject[socketId]
];


(* :POLL: *)


CSocketObject /: SocketReadyQ[CSocketObject[socketId_Integer], timeout: (_Integer | _Real): 0] :=
Catch @ AnyTrue[
    poll[{socketId}, timeout, "Readiness"],
    BitAnd[Last[#], $POLLIN] != 0&
];


Unprotect[SocketWaitNext, SocketWaitAll];


SocketWaitNext[sockets: {__CSocketObject}] :=
SocketWaitNext[sockets, "Timeout" -> 5];


SocketWaitNext[sockets: {__CSocketObject}, opts: OptionsPattern[{"Timeout" -> 5}]] :=
Catch @ With[{socketIds = sockets[[All, 1]], timeout = OptionValue["Timeout"]},
    CSocketObject[First[waitForSockets[socketIds, timeout, False]]]
];


SocketWaitAll[sockets: {__CSocketObject}] :=
SocketWaitAll[sockets, "Timeout" -> 5];


SocketWaitAll[sockets: {__CSocketObject}, opts: OptionsPattern[{"Timeout" -> 5}]] :=
Catch @ With[{socketIds = sockets[[All, 1]], timeout = OptionValue["Timeout"]},
    Map[CSocketObject] @ waitForSockets[socketIds, timeout, True]
];


Protect[SocketWaitNext, SocketWaitAll];


(* :CLOSE: *)


CSocketObject /: Close[CSocketObject[socketId_Integer]] :=
Catch @ close[socketId];


(* :READ: *)


CSocketObject /: ReadByteArray[CSocketObject[socketId_Integer]] :=
Catch @ read[socketId];


CSocketObject /: ReadString[CSocketObject[socketId_Integer]] :=
Catch @ ReplaceAll[read[socketId], {bytes_ByteArray :> ByteArrayToString[bytes]}];


CSocketObject /: SocketReadMessage[CSocketObject[socketId_Integer]] :=
Catch @ read[socketId];


(* :WRITE: *)


CSocketObject /: BinaryWrite[CSocketObject[socketId_Integer], bytes_ByteArray] :=
Catch @ write[socketId, bytes];


CSocketObject /: BinaryWrite[CSocketObject[socketId_Integer], address__, bytes_ByteArray] /; addressQ[address] :=
Catch @ With[{
    addressAssoc = splitAddress[address]}, {
    host = addressAssoc["Host"],
    port = addressAssoc["Port"]
},
    write[socketId, bytes, host, port]
];


CSocketObject /: WriteString[object_CSocketObject, text_String] :=
BinaryWrite[object, StringToByteArray[text]];


CSocketObject /: WriteString[object_CSocketObject, address__, text_String] /; addressQ[address] :=
BinaryWrite[object, address, StringToByteArray[text]];


(* :GET/SET: *)


CSocketObject[socketId_Integer][key_String] :=
$CSockets[socketId, key];


CSocketObject /: Set[CSocketObject[socketId_Integer][key_String], value_] :=
$CSockets[socketId, key] = value;


(* :LISTEN OVERRIDES: *)


CSocketObject /: SocketListen[object: CSocketObject[_Integer], handler_] :=
SocketListen[object, handler, 65536];


CSocketObject /: SocketListen[object: CSocketObject[socketId_Integer], handler_, bufferSize_Integer] :=
With[{listener = Lookup[Lookup[$CSockets, socketId, <||>], "Listener", Null]},
    If[listener =!= Null,
        $CSockets[socketId, "Handler"] = handler;
        Return[listener]
    ];

    SocketListen[{object -> handler}, bufferSize]
];


Unprotect[SocketListen];


SocketListen[bindings: {(Rule | List)[CSocketObject[_Integer], _] ..}] :=
SocketListen[socketBindings[bindings], 65536];


SocketListen[bindings: {(Rule | List)[CSocketObject[_Integer], _] ..}, bufferSize_Integer] :=
SocketListen[socketBindings[bindings], bufferSize];


SocketListen[bindings_Association?(MatchQ[Normal[#], {Rule[CSocketObject[_Integer], _] ..}]&)] :=
SocketListen[bindings, 65536];


SocketListen[
    bindings_Association?(MatchQ[Normal[#], {Rule[CSocketObject[_Integer], _] ..}]&),
    bufferSize_Integer
] :=
Catch @ With[{socketIds = Keys[bindings][[All, 1]]}, {roles = socketRoleCode /@ socketIds},
    KeyValueMap[(#1["Handler"] = #2)&, bindings];

    With[{task = createSocketListener[socketIds, roles, bufferSize]},
        Scan[($CSockets[#, "Listener"] = task)&, socketIds];
        task
    ]
];


Protect[SocketListen];


createSocketListener[socketIds: {__Integer}, roles: {__Integer}, bufferSize_Integer] :=
With[{task = Check[
    Internal`CreateAsynchronousTask[
        socketPollLoopCreate,
        {socketIds, roles, 10 ^ 6, $POLLIN, bufferSize},
        Function[{task, name, data},
            Catch @ With[{source = socketEventSource[task, data]},
                If[!MissingQ[source], deliverSocketEvent[source, getEvent[task, name, data]]]
            ]
        ],
        "PostStopAsynchronousTask" -> (removeSocketListener[#[[2]]]&),
        "PostRemoveAsynchronousTask" -> (removeSocketListener[#[[2]]]&)
    ],
    $Failed
]},
    If[!MatchQ[task, _AsynchronousTaskObject],
        Throw[Failure["socketPollLoopCreate", <|"SocketIDs" -> socketIds, "Roles" -> roles, "BufferSize" -> bufferSize|>]]
    ];

    task
];


(* :FORMAT: *)


CSocketObject /: MakeBoxes[object: CSocketObject[socketId_Integer], form: (StandardForm | TraditionalForm)] :=
Module[{metadata = Lookup[$CSockets, socketId, <||>], above, below},
    above = {
        {BoxForm`SummaryItem[{"UUID: ", socketId}], SpanFromLeft},
        {BoxForm`SummaryItem[{"Local: ", Lookup[metadata, "LocalAddress", "-"]}], SpanFromLeft},
        {BoxForm`SummaryItem[{"Remote: ", Lookup[metadata, "RemoteAddress", "-"]}], SpanFromLeft}
    };

    below = Map[
        {BoxForm`SummaryItem[{# <> ": ", Lookup[metadata, #, Missing["NotAvailable"]]}], SpanFromLeft}&,
        Keys @ KeyDrop[metadata, {"UUID", "LocalAddress", "RemoteAddress", "Addresses", "Object"}]
    ];

    BoxForm`ArrangeSummaryBox[CSocketObject, object, $socketObjectIcon, above, below, form, "Interpretable" -> Automatic]
];


(* :CSocketHandle: *)


CSocketHandle::socket =
"Socket `1` must be registered with role Connected, Accepted, or Bound.";


socketBindings[bindings_List] :=
Association[Map[Replace[#, {socket_CSocketObject, handler_} :> (socket -> handler)]&, bindings]];


CSocketHandle[socket: CSocketObject[_Integer], handler_] :=
CSocketHandle[<|socket -> handler|>];


CSocketHandle[bindings: {(Rule | List)[CSocketObject[_Integer], _] ...}] :=
CSocketHandle[socketBindings[bindings]];


CSocketHandle[bindings_Association?(MatchQ[Normal[#], {Rule[CSocketObject[_Integer], _] ...}]&)] :=
Catch @ handleSockets[bindings];


handleSockets[bindings_Association] :=
Module[{socketIds = First /@ Keys[bindings], events, role},
    Scan[Function[socketId,
        role = {$CSockets[socketId, "Protocol"], $CSockets[socketId, "Role"]};

        If[!MatchQ[role, {"TCP", "Bound" | "Connected" | "Accepted"} | {"UDP", "Bound" | "Connected"}],
            Message[CSocketHandle::socket, CSocketObject[socketId]];
            Throw[Failure["CSocketHandle", <|"SocketID" -> socketId, "Role" -> role|>]]
        ];
    ], socketIds];

    KeyValueMap[(#1["Handler"] = #2)&, bindings];

    While[socketIds =!= {},
        events = waitEvents[socketIds, 1];

        socketIds = Select[
            DeleteDuplicates @ Join[socketIds,
                Cases[events, KeyValuePattern["AcceptedSocket" -> CSocketObject[acceptedSocketId_Integer]] :> acceptedSocketId]
            ],
            KeyExistsQ[$CSockets, #]&
        ];
    ];
];


waitEvents[socketIds: {___Integer}, timeout: (_Integer | _Real)?NonNegative] :=
Module[{registered, ready, socketId, event, events = {}},
    registered = Select[socketIds, KeyExistsQ[$CSockets, #]&];
    If[registered === {}, Return[{}]];

    ready = poll[registered, timeout];

    Do[
        socketId = First[row];
        If[!KeyExistsQ[$CSockets, socketId], Continue[]];

        event = getEvent[row];
        If[event === None, Continue[]];

        If[MemberQ[{"Closed", "Error"}, event["Event"]], close[socketId, False]];
        AppendTo[events, deliverSocketEvent[socketId, event]],
        {row, ready}
    ];

    events
];


removeSocketListener[taskId_Integer] :=
KeyValueMap[Function[{socketId, metadata},
    With[{listener = Lookup[metadata, "Listener", Null]},
        If[MatchQ[listener, _AsynchronousTaskObject] && listener[[2]] === taskId,
            $CSockets[socketId, "Listener"] = Null
        ]
    ]
], $CSockets];


CSocketHandler::length =
"Accumulator returned invalid expected length `1`.";


$Accepted = Function[event,
    With[{listenSocket = Lookup[event, "ListenSocket"], acceptedSocket = Lookup[event, "AcceptedSocket"]},
        If[MatchQ[{listenSocket, acceptedSocket}, {_CSocketObject, _CSocketObject}],
            registerAcceptedSocket[First[listenSocket], First[acceptedSocket], Lookup[event, "Task", Null]]
        ]
    ]
];


$Closed = Function[event,
    With[{socket = Lookup[event, "ClosedSocket"]},
        If[MatchQ[socket, _CSocketObject], unregisterSocket[First[socket]]]
    ]
];


$Error = Function[event,
    With[{socket = Lookup[event, "ErrorSocket"]},
        If[MatchQ[socket, _CSocketObject], errorEvent[First[socket]]]
    ]
];


$Received = Function[event, handleReceivedEvent[event, Function[Null]]];


$ReceivedFrom = $Received;


$lifecycleActions = <|
    "Accepted" :> $Accepted,
    "Closed" :> $Closed,
    "Error" :> $Error
|>;


Options[CSocketHandler] = {
    "Logger" :> Function[#],
    "Buffer" :> CreateDataStructure["HashTable"],
    "Serializer" :> Function[#],
    "Deserializer" :> Function[#],
    "Accumulator" :> Function[Length[#DataByteArray]],
    "Received" :> $Received,
    "Accepted" :> $Accepted,
    "Closed" :> $Closed,
    "Error" :> $Error,
    "ReceivedFrom" :> $ReceivedFrom,
    "NativeReceived" -> Automatic
};


With[{store = Language`NewExpressionStore["CSocketHandler"]},

    CSocketHandler[OptionsPattern[]] :=
    With[{handler = CSocketHandler[CreateUUID[]]},
        Scan[Function[key, handler[key] = OptionValue[key]], Keys[Options[CSocketHandler]]];

        handler
    ];


    (handler_CSocketHandler)[key_] :=
    store["get"[handler, key]];


    handlerOption[handler_CSocketHandler, key_String] :=
    store["get"[handler, {"Option", key}]];


    (handler_CSocketHandler)[key_, rest__] :=
    Catch @ store["get"[handler, key]][rest];


    CSocketHandler /: Set[(handler_CSocketHandler)[key_], value_] :=
    (
        store["put"[handler, key, handlerEventFunction[handler, key, value]]];
        store["put"[handler, {"Option", key}, value]];
        value
    );
];


Unprotect[Set];


(*TODO: replace to MutationHandler*)


Set[(handler_ ? (Head[#] === CSocketHandler&))[keys__], value_] :=
With[{$handler$ = handler},
    $handler$[keys] = value
];


Protect[Set];


Format[handler_CSocketHandler, InputForm] :=
SequenceForm[CSocketHandler] @ Map[Function[# -> handlerOption[handler, #]]] @ Keys @ Options[CSocketHandler];


CSocketHandler /: MakeBoxes[handler: CSocketHandler[_String], form: (StandardForm | TraditionalForm)] :=
Module[{above, below},
    {above, below} = TakeDrop[Map[# -> handlerOption[handler, #]&] @ Keys @ Options[CSocketHandler], 2];

    BoxForm`ArrangeSummaryBox[CSocketHandler, handler, Null, above, below, form, "Interpretable" -> Automatic]
];


(handler_CSocketHandler)[event_Association] :=
Catch @ applySocketHandler[handler, event];


applySocketHandler[handler_CSocketHandler, event_Association] :=
handler[Lookup[event, "Event", "NativeReceived"]][event];


handlerEventFunction[handler_CSocketHandler, key: "Accepted" | "Closed" | "Error", callback_] :=
With[{action = $lifecycleActions[key]},
    Function[event,
        Module[{packet = Append[KeyDrop[event, "Result"], "Handler" -> handler]},
            action[packet];
            If[KeyExistsQ[event, "Event"],
                packet["Result"] = If[callback === action, Null, callback[packet]];
                handler["Logger"][packet];
                packet,
                If[callback === action, Null, callback[event]]
            ]
        ]
    ]
];


handlerEventFunction[handler_CSocketHandler, key: "Received" | "ReceivedFrom", callback_] :=
With[{default = If[key === "Received", $Received, $ReceivedFrom]},
    Function[event,
        If[!KeyExistsQ[event, "Event"],
            If[callback === default, Null, callback[event]],
            With[{packet = Append[KeyDrop[event, "Result"], "Handler" -> handler]},
                If[callback === default, default[packet], handleReceivedEvent[packet, callback]]
            ]
        ]
    ]
];


handlerEventFunction[handler_CSocketHandler, "NativeReceived", Automatic] :=
Function[event, handler["Received"][nativeReceivedEvent[event]]];


handlerEventFunction[handler_CSocketHandler, "NativeReceived", callback_] :=
Function[event,
    handleReceivedEvent[Append[nativeReceivedEvent[event], "Handler" -> handler], callback]
];


handlerEventFunction[handler_CSocketHandler, key_, value_] :=
value;


nativeReceivedEvent[event_Association] :=
Module[{source = Lookup[event, "SourceSocket"], bytes = Lookup[event, "DataByteArray"], data},
    If[!MatchQ[source, _SocketObject] || source["Protocol"] =!= "TCP",
        Message[CSocketHandler::packet, "SourceSocket"];
        Throw[Failure["CSocketHandler", <|"Field" -> "SourceSocket", "Value" -> source|>]]
    ];

    If[!ByteArrayQ[bytes],
        data = Lookup[event, "DataBytes", Lookup[event, "Data"]];
        bytes = Switch[data,
            {___Integer}, ByteArray[data],
            _String, StringToByteArray[data],
            _,
                Message[CSocketHandler::packet, "DataByteArray"];
                Throw[Failure["CSocketHandler", <|"Field" -> "DataByteArray", "Value" -> data|>]]
        ]
    ];

    With[{byteArray = bytes},
        Join[
            <|
                "Socket" -> source,
                "Task" -> Null,
                "Timestamp" :> Lookup[event, "TimeStamp", Now],
                "MultipartComplete" -> True,
                "Data" :> ByteArrayToString[byteArray],
                "DataBytes" :> Normal[byteArray]
            |>,
            KeyDrop[event, "Result"],
            <|"Event" -> "Received", "DataByteArray" -> byteArray|>
        ]
    ]
];


handleReceivedEvent[packet_Association, callback_] :=
Module[{processedPacket = packet, handler = packet["Handler"], bytes, remaining},
    While[True,
        processedPacket = getExtendedPacket[processedPacket];
        If[!TrueQ[processedPacket["Completed"]],
            savePacketToBuffer[processedPacket];
            handler["Logger"][processedPacket];
            Return[processedPacket]
        ];

        bytes = getMessage[processedPacket];
        remaining = bytes[[processedPacket["ExpectedLength"] + 1 ;;]];
        processedPacket["DataByteArray"] = ByteArray[bytes[[1 ;; processedPacket["ExpectedLength"]]]];
        processedPacket["DataBytes"] = Normal[processedPacket["DataByteArray"]];
        clearBuffer[processedPacket];
        processedPacket["Data"] = handler["Deserializer"][processedPacket["DataByteArray"]];
        processedPacket = invokeHandler[processedPacket, callback];
        sendResponse[processedPacket];
        handler["Logger"][processedPacket];

        If[Length[remaining] === 0, Return[processedPacket]];
        processedPacket = Join[KeyDrop[packet, "Result"], <|
            "DataByteArray" -> remaining,
            "DataBytes" -> Normal[remaining],
            "Data" -> ByteArrayToString[remaining]
        |>]
    ]
];


$directory =
DirectoryName[$InputFileName, 2];


$socketObjectIcon := $socketObjectIcon =
Import[FileNameJoin[{$directory, "Images", "SocketIcon.png"}]];


socketRoleCode::role =
"Unsupported protocol and role for socket `1`: `2`.";


socketRoleCode[socketId_Integer] :=
With[{role = {$CSockets[socketId, "Protocol"], $CSockets[socketId, "Role"]}},
    Switch[role,
        {"TCP", "Unspecified"}, $SOCKETROLETCPUNSPEC,
        {"TCP", "Bound"}, $SOCKETROLETCPBOUND,
        {"TCP", "Connected"}, $SOCKETROLETCPCONNECTED,
        {"TCP", "Accepted"}, $SOCKETROLETCPACCEPTED,
        {"UDP", "Unspecified"}, $SOCKETROLEUDPUNSPEC,
        {"UDP", "Bound"}, $SOCKETROLEUDPBOUND,
        {"UDP", "Connected"}, $SOCKETROLEUDPCONNECTED,
        _,
            Message[socketRoleCode::role, socketId, role];
            Throw[Failure["socketRoleCode", <|"SocketID" -> socketId, "Role" -> role|>]]
    ]
];


CSocketOpen::open =
"Could not create a `2` socket for `1`.";


createSocket[addressFamily: "IPv4" | "IPv6", protocol: "TCP" | "UDP": "TCP"] :=
With[{
    af = addressFamily /. {"IPv4" -> $AFINET, "IPv6" -> $AFINET6},
    proto = protocol /. {"TCP" -> $IPPROTOTCP, "UDP" -> $IPPROTOUDP}
}, {
    socketId = Check[socketCreate[af, proto], $Failed]
},
    If[!IntegerQ[socketId],
        Message[CSocketOpen::open, addressFamily, protocol];
        Throw[Failure["socketCreate", <|"AddressFamily" -> addressFamily, "Protocol" -> protocol|>]]
    ];

    registerSocket[socketId, protocol, "Unspecified", "Blocking"];
    socketId
];


bind::fail =
"Bind failed on socket `1` at `2`:`3`.";


bind[socketId_Integer, host_String, port_Integer] :=
Module[{addresses, role},
    Check[socketBind[socketId, host, ToString[port]],
        Message[bind::fail, socketId, host, port];
        close[socketId];
        Throw[Failure["socketBind", <|"SocketID" -> socketId, "Host" -> host, "Port" -> port|>]]
    ];

    role = If[$CSockets[socketId, "Protocol"] === "UDP", $SOCKETROLEUDPBOUND, $SOCKETROLETCPBOUND];
    addresses = Check[List @@ socketGetAddresses[socketId, role], $Failed];

    If[!MatchQ[addresses, {_String, ___String}],
        Message[bind::fail, socketId, host, port];
        close[socketId];
        Throw[Failure["socketGetAddresses", <|"SocketID" -> socketId, "Role" -> role|>]]
    ];

    $CSockets[socketId, "Role"] = "Bound";
    $CSockets[socketId, "DirectionType"] = "Server";
    $CSockets[socketId, "LocalAddress"] = First[addresses];
    $CSockets[socketId, "Addresses"] = {First[addresses], $CSockets[socketId, "RemoteAddress"]};
];


listen::fail =
"Listen failed on socket `1` at `2`.";


listen[socketId_Integer] :=
(
    Check[socketListen[socketId, $SOMAXCONN],
        Message[listen::fail, socketId, $CSockets[socketId, "LocalAddress"]];
        close[socketId];
        Throw[Failure["socketListen", <|"SocketID" -> socketId, "Backlog" -> $SOMAXCONN|>]]
    ];

    $CSockets[socketId, "Role"] = "Bound";
    $CSockets[socketId, "DirectionType"] = "Server";
);


connect::fail =
"Connect failed on socket `1` to `2`:`3`.";


connect[socketId_Integer, host_String, port_Integer] :=
Module[{addresses, role},
    Check[socketConnect[socketId, host, ToString[port]],
        Message[connect::fail, socketId, host, port];
        close[socketId];
        Throw[Failure["socketConnect", <|"SocketID" -> socketId, "Host" -> host, "Port" -> port|>]]
    ];

    role = If[$CSockets[socketId, "Protocol"] === "UDP", $SOCKETROLEUDPCONNECTED, $SOCKETROLETCPCONNECTED];
    addresses = Check[List @@ socketGetAddresses[socketId, role], $Failed];

    If[!MatchQ[addresses, {_String, _String}],
        Message[connect::fail, socketId, host, port];
        close[socketId];
        Throw[Failure["socketGetAddresses", <|"SocketID" -> socketId, "Role" -> role|>]]
    ];

    $CSockets[socketId, "Role"] = "Connected";
    $CSockets[socketId, "DirectionType"] = "Client";
    $CSockets[socketId, "LocalAddress"] = First[addresses];
    $CSockets[socketId, "RemoteAddress"] = Last[addresses];
    $CSockets[socketId, "Addresses"] = addresses;
];


poll::fail =
"Poll failed on sockets `1`.";


poll[socketIds: {___Integer}, timeout: (_Integer | _Real): 0, mode: "Events" | "Readiness": "Events"] :=
With[{events = Check[socketsPoll[socketIds, Round[timeout * 10 ^ 6], $POLLIN], $Failed]},
    If[!MatchQ[events, {{_Integer, _Integer}...}],
        Message[poll::fail, socketIds];
        Throw[Failure["socketsPoll", <|"SocketIDs" -> socketIds, "Timeout" -> timeout|>]]
    ];

    If[mode === "Readiness" && AnyTrue[events, BitAnd[Last[#], BitOr[$POLLERR, $POLLNVAL]] != 0&],
        Message[poll::fail, socketIds];
        Throw[Failure["socketsPoll", <|"SocketIDs" -> socketIds, "Events" -> events|>]]
    ];

    events
];


waitForSockets::timeout =
"Timed out waiting for sockets `1`.";


waitForSockets::opts =
"Timeout must be between 0 and 60 seconds. Received `1`.";


waitForSockets[socketIds: {__Integer}, timeout_, all: True | False] :=
Module[{pending = DeleteDuplicates[socketIds], deadline, events, readySockets},
    If[!MatchQ[timeout, _Integer | _Real] || !TrueQ[0 <= timeout <= 60],
        Message[waitForSockets::opts, timeout];
        Throw[Failure["InvalidTimeout", <|"SocketIDs" -> socketIds, "Timeout" -> timeout|>]]
    ];

    deadline = SessionTime[] + timeout;

    While[pending =!= {},
        events = poll[pending, Max[0, deadline - SessionTime[]], "Readiness"];
        readySockets = Cases[events, {socketId_Integer, flags_Integer} /; BitAnd[flags, $POLLIN] != 0 :> socketId];

        If[!all && readySockets =!= {}, Return[readySockets]];

        pending = Complement[pending, readySockets];

        If[pending =!= {} && SessionTime[] >= deadline,
            Message[waitForSockets::timeout, pending];
            Throw[Failure["SocketWaitTimeout", <|"SocketIDs" -> pending, "Timeout" -> timeout|>]]
        ];
    ];

    socketIds
];


accept::fail =
"Accept failed on socket `1`.";


accept[listenSocketId_Integer] :=
With[{acceptedSocketId = Check[socketAccept[listenSocketId], $Failed]},
    If[!IntegerQ[acceptedSocketId],
        Message[accept::fail, listenSocketId];
        Throw[Failure["socketAccept", <|"SocketID" -> listenSocketId|>]]
    ];

    acceptedSocketId
];


read::fail =
"Read failed on socket `1`.";


readDatagram[socketId_Integer] :=
With[{received = Check[Apply[List] @ socketRecvFrom[socketId, $CSockets[socketId, "Buffer"]], $Failed]},
    If[!MatchQ[received, {_String} | {_String, _NumericArray | _ByteArray}],
        Message[read::fail, socketId];
        Throw[Failure["socketRecvFrom", <|"SocketID" -> socketId|>]]
    ];

    received
];


read[socketId_Integer, allowEOF: True | False: False] :=
If[$CSockets[socketId, "Protocol"] === "UDP" && $CSockets[socketId, "Role"] === "Bound",
    With[{datagram = readDatagram[socketId]},
        {First[datagram], If[Length[datagram] === 1, ByteArray[{}], ByteArray[Last[datagram]]]}
    ],
    With[{received = Check[socketRecv[socketId, $CSockets[socketId, "Buffer"]], $Failed]},
        If[!ByteArrayQ[received] ||
            (!allowEOF && received === ByteArray[{}] && $CSockets[socketId, "Protocol"] === "TCP"),
            Message[read::fail, socketId];
            Throw[Failure["socketRecv", <|"SocketID" -> socketId|>]]
        ];

        received
    ]
];


write::fail =
"Write failed on socket `1`.";


write[socketId_Integer, bytes_ByteArray, host_String: "", port_Integer: 0] :=
Module[{bytesRequested = Length[bytes], sent, result, sendFunction,
    boundUDP = $CSockets[socketId, "Protocol"] === "UDP" && $CSockets[socketId, "Role"] === "Bound"
},
    If[boundUDP === (host === ""),
        Message[write::fail, socketId];
        Throw[Failure["write", <|"SocketID" -> socketId, "Host" -> host, "Port" -> port|>]]
    ];

    result = Check[
        sent = If[boundUDP,
            socketSendToRange[socketId, host, ToString[port], bytes, 0, bytesRequested],
            socketSendRange[socketId, bytes, 0, bytesRequested]
        ],
        $Failed
    ];

    If[result =!= bytesRequested,
        sendFunction = If[boundUDP, "socketSendTo", "socketSend"];
        Message[write::fail, socketId];
        Throw[Failure[sendFunction, <|
            "SocketID" -> socketId,
            "Host" -> host,
            "Port" -> port,
            "BytesSent" -> If[IntegerQ[sent] && 0 <= sent <= bytesRequested, sent, 0],
            "BytesRequested" -> bytesRequested
        |>]]
    ];

    sent
];


close::fail =
"Close failed on socket `1`.";


closeDescriptor[socketId_Integer] :=
Check[socketClose[socketId],
    Message[close::fail, socketId];
    Throw[Failure["socketClose", <|"SocketID" -> socketId|>]]
];


close[socketId_Integer, unregister: True | False: True] :=
If[KeyExistsQ[$CSockets, socketId],
    If[unregister || validSocketQ[socketId],
        closeDescriptor[socketId]
    ];

    If[unregister, unregisterSocket[socketId]];
];


toBlocking::fail =
"Failed to set socket `1` to blocking mode.";


toBlocking[socketId_Integer] :=
(
    Check[
        socketSetBlockingMode[socketId],

        Message[toBlocking::fail, socketId];
        Throw[Failure["socketSetBlockingMode", <|"SocketID" -> socketId|>]]
    ];

    $CSockets[socketId, "BlockingMode"] = "Blocking";
);


toNonBlocking::fail =
"Failed to set socket `1` to non-blocking mode.";


toNonBlocking[socketId_Integer] :=
(
    Check[
        socketSetNonBlockingMode[socketId],

        Message[toNonBlocking::fail, socketId];
        Throw[Failure["socketSetNonBlockingMode", <|"SocketID" -> socketId|>]]
    ];

    $CSockets[socketId, "BlockingMode"] = "NonBlocking";
);


getEvent[{task_AsynchronousTaskObject, name_String, data_List}] :=
getEvent[task, name, data];


getEvent[{socketId_Integer, flags_Integer}] :=
Which[
    BitAnd[flags, $POLLIN] != 0, getEvent[socketRoleCode[socketId], socketId],
    BitAnd[flags, BitOr[$POLLERR, $POLLNVAL]] != 0, getEvent[Null, "Error", {socketId, flags}],
    BitAnd[flags, $POLLHUP] != 0, getEvent[Null, "Closed", {socketId}],
    True, None
];


getEvent[role_Integer, listenSocketId_Integer] /; role === $SOCKETROLETCPBOUND :=
getEvent[Null, "Accepted", {listenSocketId, accept[listenSocketId]}];


getEvent[role_Integer, socketId_Integer] /; MemberQ[{$SOCKETROLEUDPBOUND, $SOCKETROLEUDPCONNECTED}, role] :=
With[{buffer = $CSockets[socketId, "Buffer"]},
    With[{received = Check[List @@ socketRecvFromInto[socketId, buffer], $Failed]},
        If[!MatchQ[received, {_Integer, _String}] || !TrueQ[0 <= First[received] <= Length[buffer]],
            Message[read::fail, socketId];
            Throw[Failure["socketRecvFrom", <|"SocketID" -> socketId|>]]
        ];

        getEvent[Null, "ReceivedFrom", {socketId, Last[received], Take[buffer, First[received]]}]
    ]
];


getEvent[role_Integer, socketId_Integer] /; MemberQ[{$SOCKETROLETCPCONNECTED, $SOCKETROLETCPACCEPTED}, role] :=
With[{buffer = $CSockets[socketId, "Buffer"]},
    With[{bytesRead = Check[socketRecvInto[socketId, buffer], $Failed]},
        If[!IntegerQ[bytesRead] || !TrueQ[0 <= bytesRead <= Length[buffer]],
            Message[read::fail, socketId];
            Throw[Failure["socketRecv", <|"SocketID" -> socketId|>]]
        ];

        If[bytesRead === 0,
            getEvent[Null, "Closed", {socketId}],
            getEvent[Null, "Received", {socketId, Take[buffer, bytesRead]}]
        ]
    ]
];


getEvent[task: _AsynchronousTaskObject | Null, "Accepted", {listenSocketId_Integer, acceptedSocketId_Integer}] :=
<|
    "Timestamp" -> Now,
    "MultipartComplete" -> True,
    "Task" -> task,
    "Event" -> "Accepted",
    "ListenSocket" -> CSocketObject[listenSocketId],
    "AcceptedSocket" -> CSocketObject[acceptedSocketId]
|>;


getEvent[task: _AsynchronousTaskObject | Null, "Closed", {socketId_Integer, ___}] :=
<|
    "Timestamp" -> Now,
    "MultipartComplete" -> True,
    "Task" -> task,
    "Event" -> "Closed",
    "ClosedSocket" -> CSocketObject[socketId]
|>;


getEvent[task: _AsynchronousTaskObject | Null, "Error", {socketId_Integer, code_Integer}] :=
<|
    "Timestamp" -> Now,
    "MultipartComplete" -> True,
    "Task" -> task,
    "Event" -> "Error",
    "ErrorSocket" -> CSocketObject[socketId],
    "ErrorCode" -> code
|>;


getEvent[task: _AsynchronousTaskObject | Null, "ReceivedFrom", {socketId_Integer, address_String}] :=
With[{byteArray = ByteArray[{}], source = CSocketObject[socketId]},
    <|
        "Timestamp" -> Now,
        "MultipartComplete" -> True,
        "Task" -> task,
        "Event" -> "ReceivedFrom",
        "Socket" -> Lookup[Lookup[$CSockets, socketId, <||>], "ListenSocket", source],
        "SourceSocket" -> source,
        "Data" :> ByteArrayToString[byteArray],
        "DataBytes" :> Normal[byteArray],
        "DataByteArray" :> byteArray,
        "Address" -> address
    |>
];


getEvent[
    task: _AsynchronousTaskObject | Null,
    "ReceivedFrom",
    {socketId_Integer, address_String, bytes: _NumericArray | _ByteArray}
] :=
With[{byteArray = ByteArray[bytes], source = CSocketObject[socketId]},
    <|
        "Timestamp" -> Now,
        "MultipartComplete" -> True,
        "Task" -> task,
        "Event" -> "ReceivedFrom",
        "Socket" -> Lookup[Lookup[$CSockets, socketId, <||>], "ListenSocket", source],
        "SourceSocket" -> source,
        "Data" :> ByteArrayToString[byteArray],
        "DataBytes" :> Normal[byteArray],
        "DataByteArray" :> byteArray,
        "Address" -> address
    |>
];


getEvent[task: _AsynchronousTaskObject | Null, "Received", {socketId_Integer, bytes: _NumericArray | _ByteArray}] :=
With[{byteArray = ByteArray[bytes], source = CSocketObject[socketId]},
    <|
        "Timestamp" -> Now,
        "MultipartComplete" -> True,
        "Task" -> task,
        "Event" -> "Received",
        "Socket" -> Lookup[Lookup[$CSockets, socketId, <||>], "ListenSocket", source],
        "SourceSocket" -> source,
        "Data" :> ByteArrayToString[byteArray],
        "DataBytes" :> Normal[byteArray],
        "DataByteArray" :> byteArray
    |>
];


registerAcceptedSocket::addresses =
"Failed to obtain addresses for accepted socket `1`.";


registerAcceptedSocket[listenSocketId_Integer, acceptedSocketId_Integer, task: (_AsynchronousTaskObject | Null): Null] :=
With[{addresses = Check[
        List @@ socketGetAddresses[acceptedSocketId, $SOCKETROLETCPACCEPTED],
        $Failed
    ],
    listenSocket = CSocketObject[listenSocketId],
    handler = Lookup[$CSockets[listenSocketId], "Handler", Null]
},

    If[!MatchQ[addresses, {_String, _String}],
        Message[registerAcceptedSocket::addresses, acceptedSocketId];
        closeDescriptor[acceptedSocketId];
        Throw[Failure["socketGetAddresses", <|"SocketID" -> acceptedSocketId, "ListenSocketID" -> listenSocketId|>]]
    ];

    registerSocket[acceptedSocketId, "TCP", "Accepted", $CSockets[listenSocketId, "BlockingMode"]];

    $CSockets[acceptedSocketId, "LocalAddress"] = First[addresses];
    $CSockets[acceptedSocketId, "RemoteAddress"] = Last[addresses];
    $CSockets[acceptedSocketId, "Addresses"] = addresses;
    $CSockets[acceptedSocketId, "ListenSocket"] = listenSocket;
    $CSockets[acceptedSocketId, "Listener"] = task;

    If[task === Null,
        $CSockets[acceptedSocketId, "Handler"] = handler,
        $CSockets[acceptedSocketId] = Join[$CSockets[acceptedSocketId], <|
            "Handler" :> inheritedSocketHandler[listenSocketId, task, handler]
        |>];
    ];
];


inheritedSocketHandler[listenSocketId_Integer, task_AsynchronousTaskObject, fallback_] :=
With[{metadata = Lookup[$CSockets, listenSocketId, <||>]},
    If[Lookup[metadata, {"Listener", "Role"}] === {task, "Bound"}, Lookup[metadata, "Handler", fallback], fallback]
];


unregisterSocket[socketId_Integer] :=
With[{handler = Lookup[Lookup[$CSockets, socketId, <||>], "Handler", Null]},
    If[MatchQ[handler, _CSocketHandler],
        removeSocketBuffer[handler, socketId]
    ];

    KeyDropFrom[$CSockets, socketId]
];


validSocketQ[socketId_Integer] :=
With[{valid = Check[socketValidQ[socketId], $Failed]},
    If[!BooleanQ[valid], Throw[Failure["socketValidQ", <|"SocketID" -> socketId|>]]];
    valid
];


errorEvent[socketId_Integer] :=
If[KeyExistsQ[$CSockets, socketId] && !validSocketQ[socketId],
    unregisterSocket[socketId]
];


socketEventSource[task_AsynchronousTaskObject, {socketId_Integer, ___}] :=
If[KeyExistsQ[$CSockets, socketId],
    socketId,
    SelectFirst[Keys[$CSockets], $CSockets[#, "Listener"] === task&, Missing["NotAvailable"]]
];


socketEventSource[task_AsynchronousTaskObject, {}] :=
Missing["NotAvailable"];


deliverSocketEvent[socketId_Integer, event_Association] :=
With[{handler = socketListenerHandler[$CSockets[socketId, "Handler"]]},
    handler[event];
    event
];


socketListenerHandler[handler_CSocketHandler] :=
Function[event, applySocketHandler[handler, event]];


socketListenerHandler[handler_] :=
Function[event,
    Lookup[$lifecycleActions, event["Event"], Function[Null]][event];
    With[{result = handler[event]},
        If[MemberQ[{"Received", "ReceivedFrom"}, event["Event"]] && MatchQ[result, _String | _ByteArray],
            sendResponse[Append[event, "Result" -> result]]
        ];

        result
    ]
];


packetBufferKey[packet_Association] :=
With[{source = packet["SourceSocket"]},
    Which[
        MatchQ[source, _SocketObject], source,
        KeyExistsQ[packet, "Address"], {source["UUID"], packet["Address"]},
        True, source["UUID"]
    ]
];


getExtendedPacket[packet_Association] :=
With[{handler = packet["Handler"], key = packetBufferKey[packet]},
    Module[{dataLength, last, expectedLength, storedLength = 0, buffer, accumulator},
        dataLength = Length[packet["DataByteArray"]];
        buffer = handler["Buffer"]["Lookup", key];

        If[!MissingQ[buffer] && buffer["Length"] > 0,
            last = buffer["Part", -1];
            expectedLength = last["ExpectedLength"];
            storedLength = last["StoredLength"],
        (*Else*)
            accumulator = handler["Accumulator"];
            expectedLength = If[AssociationQ[accumulator], conditionApply[accumulator][packet], accumulator[packet]]
        ];

        If[!IntegerQ[expectedLength] || expectedLength < 0 || (expectedLength === 0 && dataLength > 0),
            Message[CSocketHandler::length, expectedLength];
            Throw[Failure["CSocketHandler", <|"Option" -> "Accumulator", "Value" -> expectedLength|>]]
        ];

        Join[packet, <|
            "Completed" -> (storedLength + dataLength >= expectedLength),
            "ExpectedLength" -> expectedLength,
            "StoredLength" -> storedLength + dataLength,
            "DataLength" -> dataLength,
            "BufferKey" -> key
        |>]
    ]
];


getMessage[packet_Association] :=
With[{buffer = packet["Handler"]["Buffer"]["Lookup", packet["BufferKey"]]},
    If[!MissingQ[buffer] && buffer["Length"] > 0,
        Apply[Join, Append[buffer["Elements"][[All, "DataByteArray"]], packet["DataByteArray"]]],
        packet["DataByteArray"]
    ]
];


invokeHandler[packet_Association, callback_] :=
Module[{processedPacket = packet, handler = packet["Handler"]},
    processedPacket["Result"] = If[AssociationQ[callback], conditionApply[callback][packet], callback[packet]];
    processedPacket["Result"] = handler["Serializer"][processedPacket["Result"]];
    processedPacket
];


CSocketHandler::cntsnd =
"Can't send result to the client\n `1`";


CSocketHandler::packet =
"Cannot send response: invalid or missing `1` in packet.";


sendResponse[packet_Association] :=
Module[{result = Lookup[packet, "Result", Null], source, bytes, address},
    If[result === Null, Return[Null]];

    If[!MatchQ[result, _String | _ByteArray],
        Message[CSocketHandler::cntsnd, result];
        Throw[Failure["CSocketHandler", <|"Field" -> "Result", "Value" -> result|>]]
    ];

    source = Lookup[packet, "SourceSocket"];

    If[!MatchQ[source, CSocketObject[_Integer] | _SocketObject],
        Message[CSocketHandler::packet, "SourceSocket"];
        Throw[Failure["CSocketHandler", <|"Field" -> "SourceSocket", "Value" -> source|>]]
    ];

    bytes = If[StringQ[result], StringToByteArray[result], result];

    If[MatchQ[source, _SocketObject],
        Return[Check[BinaryWrite[source, bytes],
            Throw[Failure["BinaryWrite", <|"SourceSocket" -> source, "BytesRequested" -> Length[bytes]|>]]
        ]]
    ];

    If[KeyExistsQ[packet, "Address"] &&
        {source["Protocol"], source["Role"]} =!= {"UDP", "Connected"},
        address = packet["Address"];

        If[!StringQ[address] || !protohostportQ[address],
            Message[CSocketHandler::packet, "Address"];
            Throw[Failure["CSocketHandler", <|"Field" -> "Address", "Value" -> address|>]]
        ];

        address = splitAddress[address];
        write[First[source], bytes, address["Host"], address["Port"]],
        write[First[source], bytes]
    ]
];


savePacketToBuffer[packet_Association] :=
With[{handler = packet["Handler"], key = packet["BufferKey"]},
    With[{buffer = handler["Buffer"]["Lookup", key]},
        If[!MissingQ[buffer],
            buffer["Append", packet],
            handler["Buffer"]["Insert", key -> CreateDataStructure["DynamicArray", {packet}]]
        ]
    ]
];


clearBuffer[packet_Association] :=
packet["Handler"]["Buffer"]["KeyDrop", packet["BufferKey"]];


removeSocketBuffer[handler_CSocketHandler, socketId_Integer] :=
With[{buffer = handler["Buffer"]},
    Scan[buffer["KeyDrop", #]&, Select[buffer["Keys"],
        # === socketId || MatchQ[#, {socketId, _String}]&
    ]]
];


conditionApply[conditionAndFunctions: _ ? AssociationQ: <||>, defalut_: Function[Null], ___] :=
Function[
    With[{
        selected = SelectFirst[conditionAndFunctions, Function[f, First[f][##]], {defalut}]
    },
        selected[[-1]][##]
    ]
];


optionValidQ::invalid =
"Invalid value `2` for option `1`.";


optionValidQ[optName_String, optValue_, validator_] :=
If[!TrueQ[validator[optValue]],
    Message[optionValidQ::invalid, optName, optValue];
    Throw[Failure["InvalidOption", <|"Option" -> optName, "Value" -> optValue|>]]
];


registerSocket[
    socketId_Integer,
    protocol: "TCP" | "UDP": "TCP",
    role: "Unspecified" | "Bound" | "Accepted" | "Connected": "Unspecified",
    blockingMode: "Blocking" | "NonBlocking": "Blocking"] :=
With[{object = CSocketObject[socketId]},
    $CSockets[socketId] = <|
        "UUID" -> socketId,
        "Object" -> object,
        "Listener" -> Null,
        "Handler" -> Null,
        "Properties" :> Keys[$CSockets[socketId]],
        "Protocol" -> protocol,
        "Scheme" -> ToLowerCase[protocol],
        "InprocQ" -> False,
        "DirectionType" -> If[role === "Bound", "Server", "Client"],
        "BlockingMode" -> blockingMode,
        "Buffer" -> ByteArray[ConstantArray[0, 64 * 1024]],
        "LocalAddress" -> "-",
        "RemoteAddress" -> "-",
        "Addresses" -> {"-", "-"},
        "State" -> "Alive",
        "Role" -> role
    |>
];


splitAddress[host_String?ipv4HostQ, port_Integer?portQ, protocol: "TCP" | "UDP": "TCP"] :=
<|
    "Host" -> host,
    "Port" -> port,
    "Protocol" -> protocol,
    "Family" -> "IPv4"
|>;


splitAddress[host_String?ipv6HostQ, port_Integer?portQ, protocol: "TCP" | "UDP": "TCP"] :=
<|
    "Host" -> host,
    "Port" -> port,
    "Protocol" -> protocol,
    "Family" -> "IPv6"
|>;


splitAddress[host_String?hostnameQ, port_Integer?portQ, protocol: "TCP" | "UDP": "TCP"] :=
With[{numericHost = Check[HostLookup[host][[1, 1]], $Failed]},
    If[!StringQ[numericHost] || !numericHostQ[numericHost],
        Throw[Failure["HostLookup", <|"Host" -> host, "Port" -> port, "Protocol" -> protocol|>]]
    ];

    splitAddress[numericHost, port, protocol]
];


splitAddress[port_Integer?portQ, protocol: "TCP" | "UDP": "TCP"] :=
splitAddress["localhost", port, protocol];


splitAddress[address_String] :=
With[{parts = parseAddress[address]},
    If[MissingQ[parts], Throw[Failure["InvalidAddress", <|"Address" -> address|>]]];

    splitAddress[parts[[2]], parts[[3]], parts[[1]]]
];


parseAddress[address_String] :=
Module[{
    protocol = "TCP",
    endpoint = address,
    bracketed, pairs, host, port
},
    Which[
        StringStartsQ[endpoint, "tcp://", IgnoreCase -> True], endpoint = StringDrop[endpoint, 6],
        StringStartsQ[endpoint, "udp://", IgnoreCase -> True],
            protocol = "UDP";
            endpoint = StringDrop[endpoint, 6]
    ];

    bracketed = StringStartsQ[endpoint, "["];
    pairs = If[bracketed,
        StringCases[endpoint,
            StartOfString ~~ "[" ~~ h: Except["[" | "]"].. ~~ "]:" ~~ p: DigitCharacter.. ~~ EndOfString :>
                {h, FromDigits[p]}
        ],
        StringCases[endpoint,
            StartOfString ~~ h: Except[":" | "[" | "]"].. ~~ ":" ~~ p: DigitCharacter.. ~~ EndOfString :>
                {h, FromDigits[p]}
        ]
    ];

    If[Length[pairs] =!= 1, Return[Missing["InvalidAddress"]]];

    {host, port} = First[pairs];
    If[!portQ[port] || !If[bracketed, ipv6HostQ[host], hostQ[host]], Return[Missing["InvalidAddress"]]];

    {protocol, host, port}
];


addressQ[address__] :=
MatchQ[{address}, {PatternSequence[_String?hostQ, _Integer?portQ, "TCP" | "UDP"]} |
{PatternSequence[_String?hostQ, _Integer?portQ]} |
{PatternSequence[_Integer?portQ, "TCP" | "UDP"]} |
{_Integer?portQ} |
{_String?protohostportQ}];


portQ[port_Integer] :=
0 <= port < 2^16;


$byteSymbols = Repeated[CharacterRange["0", "9"], {1, 3}];


ipv4HostQ[host_String] :=
StringMatchQ[host, Repeated[$byteSymbols ~~ ".", {3}] ~~ $byteSymbols] &&
Apply[And] @ Map[0 <= # < 256 &] @ Map[ToExpression] @ StringSplit[host, "."];


$hexSymbols = Flatten[{CharacterRange["0", "9"], CharacterRange["a", "f"], CharacterRange["A", "F"]}];


$hex4Number = Repeated[$hexSymbols, {1, 4}];


$ipv6Pattern =
(Repeated[$hex4Number ~~ ":", {7}] ~~ $hex4Number) |                                                (* 1234:5678:90ab:cdef:1234:5678:90ab:cdef*)
("::" ~~ Repeated[$hex4Number ~~ ":", {0, 6}] ~~ $hex4Number) |                                     (*    ::5678:90ab:cdef:1234:5678:90ab:cdef*)
(Repeated[$hex4Number ~~ ":", {1, 7}] ~~ ":") |                                                     (* 1234:5678:90ab:cdef:1234:5678:90ab::   *)
($hex4Number ~~ "::" ~~ Repeated[$hex4Number ~~ ":", {0, 5}] ~~ $hex4Number) |
(Repeated[$hex4Number ~~ ":", {2}] ~~ ":" ~~ Repeated[$hex4Number ~~ ":", {0, 4}] ~~ $hex4Number) |
(Repeated[$hex4Number ~~ ":", {3}] ~~ ":" ~~ Repeated[$hex4Number ~~ ":", {0, 3}] ~~ $hex4Number) |
(Repeated[$hex4Number ~~ ":", {4}] ~~ ":" ~~ Repeated[$hex4Number ~~ ":", {0, 2}] ~~ $hex4Number) |
(Repeated[$hex4Number ~~ ":", {5}] ~~ ":" ~~ Repeated[$hex4Number ~~ ":", {0, 1}] ~~ $hex4Number) |
(Repeated[$hex4Number ~~ ":", {6}] ~~ ":" ~~ $hex4Number) |
"::";


ipv6HostQ[host_String] :=
StringMatchQ[host,
    $ipv6Pattern ~~ ("" | ("%" ~~ (LetterCharacter | DigitCharacter | "_" | "-" | "." | "~")..))
];


numericHostQ[host_String] :=
ipv4HostQ[host] ||
ipv6HostQ[host];


$letterSymbols = Join[CharacterRange["a", "z"], CharacterRange["A", "Z"]];


$nameSymbols = Join[$letterSymbols, CharacterRange["0", "9"], {".", "-"}];


hostnameQ[host_String] :=
StringMatchQ[host, Repeated[$nameSymbols]] &&
0 < StringLength[host] < 254 &&
StringContainsQ[host, $letterSymbols] &&
Apply[And] @ Map[0 < # < 64 &] @ Map[StringLength] @ StringSplit[host, ".", All] &&
Apply[And] @ Map[!StringStartsQ[#, "-"] && !StringEndsQ[#, "-"]&] @ StringSplit[host, ".", All];


hostQ[host_String] :=
hostnameQ[host] ||
numericHostQ[host];


protohostportQ[address_String] :=
!MissingQ[parseAddress[address]];


(* Library constants *)


$SOCKETROLETCPUNSPEC = 0;


$SOCKETROLETCPBOUND = 1;


$SOCKETROLETCPCONNECTED = 2;


$SOCKETROLETCPACCEPTED = 3;


$SOCKETROLEUDPUNSPEC = 4;


$SOCKETROLEUDPBOUND = 5;


$SOCKETROLEUDPCONNECTED = 6;


(* Protocol levels *)


$IPPROTOTCP::usage =
"IPPROTO_TCP - TCP protocol level";


$IPPROTOTCP = 6;


$IPPROTOUDP::usage =
"IPPROTO_UDP - UDP protocol level";


$IPPROTOUDP = 17;


$IPPROTOIPV6::usage =
"IPPROTO_IPV6 - IPv6 protocol level";


$IPPROTOIPV6 =
If[$OperatingSystem === "Windows", 41, 16^^0029];


(* Socket level - platform dependent *)


$SOL::usage =
"SOL_SOCKET - socket-level options";


$SOL =
If[$OperatingSystem === "Windows", 16^^FFFF, 1];


(* Socket options (SOL_SOCKET level) *)


$SOKEEPALIVE::usage =
"SO_KEEPALIVE - enable keep-alive packets";


$SOKEEPALIVE = 16^^0008;


$SORCVBUF::usage =
"SO_RCVBUF - receive buffer size";


$SORCVBUF = 16^^1002;


$SOSNDBUF::usage =
"SO_SNDBUF - send buffer size";


$SOSNDBUF = 16^^1001;


$SOLINGER::usage =
"SO_LINGER - linger on close";


$SOLINGER = 16^^0080;


$SOBROADCAST::usage =
"SO_BROADCAST - permit broadcast messages";


$SOBROADCAST = 16^^0020;


$SOERROR::usage =
"SO_ERROR - get pending socket error";


$SOERROR = 16^^1007;


$SOMAXCONN::usage =
"SOMAXCONN - maximum backlog for listen()";


$SOMAXCONN = 16^^7FFFFFFF;


$SOTYPE::usage =
"SO_TYPE - get socket type (STREAM/DGRAM)";


$SOTYPE = 16^^1008;


$SOACCEPTCONN::usage =
"SO_ACCEPTCONN - non-zero if socket is listening";


$SOACCEPTCONN = 16^^0002;


$SOREUSEADDR::usage =
"SO_REUSEADDR - reuse local address";


$SOREUSEADDR =
If[$OperatingSystem === "Windows", 4, 16^^0002];


(* TCP options (IPPROTO_TCP level) *)


$TCPNODELAY::usage =
"TCP_NODELAY - disable Nagle algorithm";


$TCPNODELAY = 16^^0001;


$TCPKEEPIDLE::usage =
"TCP_KEEPIDLE - idle time before keep-alive probes";


$TCPKEEPIDLE =
If[$OperatingSystem === "MacOSX", 16^^0010, 16^^0004];


$TCPKEEPINTVL::usage =
"TCP_KEEPINTVL - interval between keep-alive probes";


$TCPKEEPINTVL =
If[$OperatingSystem === "MacOSX", 16^^0011, 16^^0005];


$TCPKEEPCNT::usage =
"TCP_KEEPCNT - number of keep-alive probes before drop";


$TCPKEEPCNT =
If[$OperatingSystem === "MacOSX", 16^^0012, 16^^0006];


(* IPv4 options (IPPROTO_IP level) *)


$IPTTL::usage =
"IP_TTL - time-to-live for packets";


$IPTTL = 16^^0004;


$IPTOS::usage =
"IP_TOS - type of service / DSCP";


$IPTOS = 16^^0001;


$IPMTUDISCOVER::usage =
"IP_MTU_DISCOVER - path MTU discovery";


$IPMTUDISCOVER = 16^^000A;


(* IPv6 options (IPPROTO_IPV6 level) *)


$IPV6V6ONLY::usage =
"IPV6_V6ONLY - restrict socket to IPv6 only";


$IPV6V6ONLY =
If[$OperatingSystem === "Windows", 27, 16^^001A];


(* Address families *)


$AFINET::usage =
"AF_INET - IPv4 address family";


$AFINET = 16^^0002;


$AFINET6::usage =
"AF_INET6 - IPv6 address family";


$AFINET6 = Switch[$OperatingSystem, "Windows", 23, "MacOSX", 30, _, 10];


(* Socket types *)


$SOCKSTREAM::usage =
"SOCK_STREAM - reliable stream socket (TCP)";


$SOCKSTREAM = 16^^0001;


$SOCKDGRAM::usage =
"SOCK_DGRAM - datagram socket (UDP)";


$SOCKDGRAM = 16^^0002;


(* Windows-specific *)


$SOEXCLUSIVEADDRUSE::usage =
"SO_EXCLUSIVEADDRUSE - exclusive address binding (Windows only)";


$SOEXCLUSIVEADDRUSE =
If[$OperatingSystem === "Windows", 16^^0001, -5];


(*unified sockes_poll flags*)


$POLLIN = 16^^0001;


$POLLOUT = 16^^0002;


$POLLERR = 16^^0004;


$POLLHUP = 16^^0008;


$POLLNVAL = 16^^0010;


getLibraryLinkVersion[] :=
getLibraryLinkVersion[] = Which[
    $VersionNumber >= 14.3,
        8,
    $VersionNumber >= 13.1,
        7,
    $VersionNumber >= 12.1,
        6,
    $VersionNumber >= 12.0,
        5,
    $VersionNumber >= 11.2,
        4,
    $VersionNumber >= 10.0,
        3,
    $VersionNumber >= 9.0,
        2,
    True,
        1
];


$library = FileNameJoin[
    {
        DirectoryName[$InputFileName, 2],
        "LibraryResources",
        $SystemID <> "-v" <> ToString[getLibraryLinkVersion[]],
        "csockets." <> Internal`DynamicLibraryExtension[]
    }
];


(* :LibraryLoad: *)


socketPollLoopCreate::usage =
"socketPollLoopCreate[socketIds, roles, timeout, eventsMask, bufferSize] -> taskId.";


socketPollLoopCreate =
LibraryFunctionLoad[$library, "socketPollLoopCreate", {{Integer, 1}, {Integer, 1}, Integer, Integer, Integer}, Integer];


socketCreate::usage =
"socketCreate[family, protocol] -> socketId.";


socketCreate =
LibraryFunctionLoad[$library, "socketCreate", {Integer, Integer}, Integer];


socketClose::usage =
"socketClose[socketId].";


socketClose =
LibraryFunctionLoad[$library, "socketClose", {Integer}, "Void"];


socketBind::usage =
"socketBind[socketId, numerichost, port].";


socketBind =
LibraryFunctionLoad[$library, "socketBind", {Integer, String, String}, "Void"];


socketSetOpt::usage =
"socketSetOpt[socketId, level, optname, optval].";


socketSetOpt =
LibraryFunctionLoad[$library, "socketSetOpt", {Integer, Integer, Integer, Integer}, "Void"];


socketGetOpt::usage =
"socketGetOpt[socketId, level, optname] -> optval.";


socketGetOpt =
LibraryFunctionLoad[$library, "socketGetOpt", {Integer, Integer, Integer}, Integer];


socketSetBlockingMode::usage =
"socketSetBlockingMode[socketId].";


socketSetBlockingMode =
LibraryFunctionLoad[$library, "socketSetBlockingMode", {Integer}, "Void"];


socketSetNonBlockingMode::usage =
"socketSetNonBlockingMode[socketId].";


socketSetNonBlockingMode =
LibraryFunctionLoad[$library, "socketSetNonBlockingMode", {Integer}, "Void"];


socketGetAddresses::usage =
"socketGetAddresses[socketId, role] -> addresses.";


socketGetAddresses =
LibraryFunctionLoad[$library, "socketGetAddresses", {Integer, Integer}, "DataStore"];


socketListen::usage =
"socketListen[socketId, backlog].";


socketListen =
LibraryFunctionLoad[$library, "socketListen", {Integer, Integer}, "Void"];


socketConnect::usage =
"socketConnect[socketId, numerichost, port].";


socketConnect =
LibraryFunctionLoad[$library, "socketConnect", {Integer, String, String}, "Void"];


socketAccept::usage =
"socketAccept[listenSocketId] -> acceptedSocketId.";


socketAccept =
LibraryFunctionLoad[$library, "socketAccept", {Integer}, Integer];


socketRecv::usage =
"socketRecv[socketId, buffer] -> receivedData.";


socketRecv =
LibraryFunctionLoad[$library, "socketRecv", {Integer, {"ByteArray", "Shared"}}, "ByteArray"];


socketRecvFrom::usage =
"socketRecvFrom[socketId, buffer] -> dataStore.";


socketRecvFrom =
LibraryFunctionLoad[$library, "socketRecvFrom", {Integer, {"ByteArray", "Shared"}}, "DataStore"];


socketRecvInto::usage =
"socketRecvInto[socketId, buffer] -> bytesRead.";


socketRecvInto =
LibraryFunctionLoad[$library, "socketRecvInto", {Integer, {"ByteArray", "Shared"}}, Integer];


socketRecvFromInto::usage =
"socketRecvFromInto[socketId, buffer] -> result.";


socketRecvFromInto =
LibraryFunctionLoad[$library, "socketRecvFromInto", {Integer, {"ByteArray", "Shared"}}, "DataStore"];


socketSend::usage =
"socketSend[socketId, bytes] -> sentLength.";


socketSend =
LibraryFunctionLoad[$library, "socketSend", {Integer, {"ByteArray", "Shared"}}, Integer];


socketSendRange::usage =
"socketSendRange[socketId, bytes, offset, length] -> sentLength.";


socketSendRange =
LibraryFunctionLoad[$library, "socketSendRange", {Integer, {"ByteArray", "Shared"}, Integer, Integer}, Integer];


socketSendTo::usage =
"socketSendTo[socketId, numerichost, port, data] -> sentLength.";


socketSendTo =
LibraryFunctionLoad[$library, "socketSendTo", {Integer, String, String, {"ByteArray", "Shared"}}, Integer];


socketSendToRange::usage =
"socketSendToRange[socketId, numerichost, port, data, offset, length] -> sentLength.";


socketSendToRange =
LibraryFunctionLoad[$library, "socketSendToRange", {Integer, String, String, {"ByteArray", "Shared"}, Integer, Integer}, Integer];


socketsCheck::usage =
"socketsCheck[sockets] -> validSockets.";


socketsCheck =
LibraryFunctionLoad[$library, "socketsCheck", {{Integer, 1}}, {Integer, 1}];


socketConnectedQ::usage =
"socketConnectedQ[socketId] -> True | False.";


socketConnectedQ =
LibraryFunctionLoad[$library, "socketConnectedQ", {Integer}, True | False];


socketConnectionAliveQ::usage =
"socketConnectionAliveQ[socketId] -> False.";


socketConnectionAliveQ =
LibraryFunctionLoad[$library, "socketConnectionAliveQ", {Integer}, True | False];


socketValidQ::usage =
"socketValidQ[socketId] -> validState.";


socketValidQ =
LibraryFunctionLoad[$library, "socketValidQ", {Integer}, True | False];


socketsPoll::usage =
"socketsPoll[socketsTensor, timeout, eventsMask] -> resultTensor.";


socketsPoll =
LibraryFunctionLoad[$library, "socketsPoll", {{Integer, 1}, Integer, Integer}, {Integer, 2}];


End[];


EndPackage[];
