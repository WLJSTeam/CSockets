(* ::Package:: *)

BeginPackage["WLJS`CSockets`",
    {
        "LibraryLink`",
        "CCompilerDriver`"
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


CSocketList::usage =
"CSocketList[{socket1, socket2, ...}]";


CSocketHandler::usage =
"CSocketHandler[] mutable handler object.";


Begin["`Private`"];


(* :$CSockets: *)


$CSockets = If[AssociationQ[$CSockets],
     $CSockets,
     <||>
];


(* :CSocketOpen: *)


CSocketOpen[address__?addressQ] :=
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


CSocketConnect[address__?addressQ, opts: OptionsPattern[]] :=
With[{
    wait = OptionValue["Wait"]
},
    If[!BooleanQ[wait],
        Message[CSocketConnect::opts, "Wait", wait];
        Return[$Failed]
    ];

    Catch @ With[{
        addressAssoc = splitAddress[address]}, {
        host = addressAssoc["Host"],
        port = addressAssoc["Port"],
        family = addressAssoc["Family"],
        protocol = addressAssoc["Protocol"]}, {
        socketId = createSocket[family, protocol]
    },
        If[!wait, toNonBlocking[socketId]];
        connect[socketId, host, port];
        If[!wait, toBlocking[socketId]];

        Return[CSocketObject[socketId]]
    ]
];


(* :READ: *)


CSocketObject /: ReadByteArray[CSocketObject[id_Integer]] :=
Catch @ read[id];


CSocketObject /: ReadString[CSocketObject[id_Integer]] :=
Catch @ If[ByteArrayQ[#], ByteArayToString[#], {#[[1]], ByteArrayToString[#[[2]]]}]& @ read[id];


$directory =
DirectoryName[$InputFileName, 2];


$socketObjectIcon := $socketObjectIcon =
Import[FileNameJoin[{$directory, "Images", "SocketIcon.png"}]];


CSocketObject /: MakeBoxes[object: CSocketObject[id_Integer], form: (StandardForm | TraditionalForm)] :=
Module[{above, below},
    above = {
        {BoxForm`SummaryItem[{"SocketID: ", id}], SpanFromLeft},
        {BoxForm`SummaryItem[{"Local: ", object["LocalAddress"]}], SpanFromLeft},
        {BoxForm`SummaryItem[{"Remote: ", object["RemoteAddress"]}], SpanFromLeft}
    };

    below = Map[{BoxForm`SummaryItem[{# <> ": ", object[#]}], SpanFromLeft}&, {"Protocol", "State", "Role", "BlockingMode"}];

    BoxForm`ArrangeSummaryBox[CSocketObject, object, $socketObjectIcon, above, below, form, "Interpretable" -> Automatic]
];


CSocketObject[id_Integer]["DirectionType"] :=
If[socketProperty[id, "Role"] === $SOCKETROLETCPBOUND || socketProperty[id, "Role"] === $SOCKETROLEUDPBOUND, "Server", "Client"];


CSocketObject[id_Integer]["InprocQ"] :=
False;


CSocketObject[id_Integer][key: "Object" | "Protocol" | "Role" | "State" | "BlockingMode"] :=
socketProperty[id, key];


CSocketObject[id_Integer]["Scheme"] :=
Replace[socketProperty[id, "Protocol"], {"TCP" -> "tcp", "UDP" -> "udp"}];


CSocketObject[id_Integer]["UUID"] :=
id;


CSocketObject[id_Integer]["Blocking"] :=
socketProperty[id, "BlockingMode"] === "Blocking";


CSocketObject[id_Integer][key: "LocalAddress" | "RemoteAddress"] :=
(
    socketProperty[id, key]
);


CSocketObject[id_Integer]["Addresses"] :=
(
    {socketProperty[id, "LocalAddress"], socketProperty[id, "RemoteAddress"]}
);


CSocketObject /: Close[object: CSocketObject[id_Integer]] :=
Module[{},
    If[!socketAliveQ[id], Return[Null]];
    If[Quiet[Check[socketClose[id], $Failed]] =!= Null, Return[$Failed]];
    setSocketProperty[id, "State", "Closed"];
    If[KeyExistsQ[$ownedSocketLists, id],
        Close[$ownedSocketLists[id]];
        KeyDropFrom[$ownedSocketLists, id]
    ];
    Null
];


CSocketObject /: WriteString[object_CSocketObject, text_String] :=
BinaryWrite[object, StringToByteArray[text]];


CSocketObject /: WriteString[object_CSocketObject, address_String, text_String] :=
BinaryWrite[object, address, StringToByteArray[text]];


CSocketObject /: BinaryWrite[object: CSocketObject[id_Integer], bytes_ByteArray] :=
Module[{length = Length[bytes], sent, remaining},
    If[!socketAliveQ[id], Return[$Failed]];
    sent = socketSend[id, bytes, length];
    If[IntegerQ[sent], refreshSocketAddresses[id]];
    If[!IntegerQ[sent] || sent === length, Return[sent]];
    If[sent <= 0 || sent > length, Return[$Failed]];
    remaining = BinaryWrite[object, bytes[[sent + 1 ;;]]];
    If[IntegerQ[remaining], sent + remaining, remaining]
];


CSocketObject /: BinaryWrite[object: CSocketObject[id_Integer], address_String, bytes_ByteArray] :=
Module[{length = Length[bytes], sent, remaining, parts = splitAddress[address]},
    If[!socketAliveQ[id] || parts === $Failed, Return[$Failed]];
    sent = socketSendTo[id, parts[[1]], parts[[2]], bytes];
    If[IntegerQ[sent], refreshSocketAddresses[id]];
    If[!IntegerQ[sent] || sent === length, Return[sent]];
    If[sent <= 0 || sent > length, Return[$Failed]];
    remaining = BinaryWrite[object, address, bytes[[sent + 1 ;;]]];
    If[IntegerQ[remaining], sent + remaining, remaining]
];


CSocketObject /: SocketReadyQ[CSocketObject[id_Integer], t_: 0] :=
Module[{events},
    If[!socketAliveQ[id] || socketsCheck[{id}] === {}, Return[$Failed]];
    events = socketsPoll[{id}, Round[t * 10 ^ 6], $POLLIN];
    If[!ListQ[events], Return[$Failed]];
    If[events =!= {}, refreshSocketAddresses[id]];
    Length[events] > 0 && BitAnd[events[[1, 2]], $POLLIN] != 0
];


With[{readMessageBuffer = ByteArray[ConstantArray[0, 64 * 1024]]},
    CSocketObject /: SocketReadMessage[CSocketObject[id_Integer]] :=
    If[!socketAliveQ[id], $Failed,
        If[socketProperty[id, "Protocol"] === "UDP",
            List @@ socketRecvFrom[id, readMessageBuffer],
            socketRecv[id, readMessageBuffer]
        ]
    ];
];


CSocketList[initialSockets: {___CSocketObject}] :=
Module[{id = socketListCreate[{}, {}], list},
    If[!IntegerQ[id], Return[$Failed]];
    list = CSocketList[id];
    $socketLists[id] = True;
    If[AnyTrue[initialSockets, Append[list, #] =!= Null&], Close[list]; Return[$Failed]];
    list
];


CSocketObject /: SocketWaitNext[CSocketObject[id_Integer]] :=
If[socketAliveQ[id], socketsPoll[{id}, 2 ^ 10, $POLLIN], $Failed];


CSocketList /: Append[CSocketList[listId_Integer], CSocketObject[id_Integer]] :=
If[!socketAliveQ[id], $Failed,
    If[KeyExistsQ[$socketListTasks, listId] && setSocketBlocking[id, False] === $Failed,
        $Failed,
        socketListAdd[listId, id, socketRoleCode[id]]
    ]
];


CSocketList /: DeleteMissing[CSocketList[listId_Integer]] :=
socketListPrune[listId];


CSocketList /: Close[CSocketList[listId_Integer]] :=
Module[{},
    If[!KeyExistsQ[$socketLists, listId], Return[Null]];
    KeyDropFrom[$socketLists, listId];
    If[KeyExistsQ[$socketListTasks, listId],
        Quiet[RemoveAsynchronousTask[$socketListTasks[listId]], RemoveAsynchronousTask::asyncobj];
        KeyDropFrom[$socketListTasks, listId]
    ];
    socketListDelete[listId]
];


CSocketList /: SocketListen[CSocketList[listId_Integer], handler_] :=
Module[{ids = socketListGetAll[listId], task},
    If[!ListQ[ids], Return[$Failed]];
    If[KeyExistsQ[$socketListTasks, listId], Return[$Failed]];
    If[AnyTrue[ids, setSocketBlocking[#, False] =!= Null&], Return[$Failed]];
    task = Internal`CreateAsynchronousTask[
        createSocketsPollLoop,
        {listId, 10 ^ 6, $POLLIN},
        dispatchPollEvent[listId, handler, ##]&
    ];
    If[MatchQ[task, _AsynchronousTaskObject], $socketListTasks[listId] = task];
    task
];


CSocketObject /: SocketListen[object: CSocketObject[id_Integer], handler_] :=
Module[{list, task},
    If[KeyExistsQ[$ownedSocketLists, id], Return[$Failed]];
    list = CSocketList[{object}];
    If[list === $Failed, Return[$Failed]];
    task = SocketListen[list, handler];
    If[!MatchQ[task, _AsynchronousTaskObject], Close[list]; Return[$Failed]];
    $ownedSocketLists[id] = list;
    task
];


CSocketHandler::length =
"Accumulator returned invalid expected length `1`.";


Options[CSocketHandler] = {
    "Logger" :> Function[#],
    "Buffer" :> CreateDataStructure["HashTable"],
    "Serializer" :> Function[#],
    "Deserializer" :> Function[#],
    "Accumulator" :> Function[Length[#DataByteArray]],
    "Received" :> Function[Null],
    "Accepted" :> Function[Null],
    "Closed" :> Function[Null],
    "Error" :> Function[Null],
    "ReceivedFrom" :> Function[Null]
};


With[{store = Language`NewExpressionStore["CSocketHandler"]},

    CSocketHandler[OptionsPattern[]] :=
    With[{handler = CSocketHandler[Null]},
        Map[store["put"[handler, #, OptionValue[#]]]&] @ Keys[Options[CSocketHandler]];

        handler
    ];


    (handler_CSocketHandler)[key_] :=
    store["get"[handler, key]];


    (handler_CSocketHandler)[key_, rest__] :=
    store["get"[handler, key]][rest];


    CSocketHandler /: Set[(handler_CSocketHandler)[key_], value_] :=
    (
        store["put"[handler, key, value]];
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
SequenceForm[CSocketHandler] @ Map[Function[# -> handler[#]]] @ Keys @ Options[CSocketHandler];


CSocketHandler /: MakeBoxes[handler: CSocketHandler[Null], form: (StandardForm | TraditionalForm)] :=
Module[{above, below},
    {above, below} = TakeDrop[Map[# -> handler[#]&] @ Keys @ Options[CSocketHandler], 2];

    BoxForm`ArrangeSummaryBox[CSocketHandler, handler, Null, above, below, form, "Interpretable" -> Automatic]
];


(handler_CSocketHandler)[packet_Association] :=
Module[{
    processedPacket = Append[KeyDrop[packet, "Result"], "Handler" -> handler],
    event = packet["Event"], bytes, remaining
},
    If[!MemberQ[{"Received", "ReceivedFrom"}, packet["Event"]],
        processedPacket["Result"] = handler[packet["Event"]][processedPacket];
        handler["Logger"][processedPacket];
        Return[processedPacket]
    ];

    While[True,
        processedPacket = getExtendedPacket[processedPacket];
        If[processedPacket === $Failed, Return[$Failed]];
        If[!TrueQ[processedPacket["Completed"]],
            savePacketToBuffer[processedPacket];
            handler["Logger"][processedPacket];
            Return[processedPacket]
        ];

        bytes = getMessage[processedPacket];
        remaining = bytes[[processedPacket["ExpectedLength"] + 1 ;;]];
        processedPacket["DataByteArray"] = bytes[[1 ;; processedPacket["ExpectedLength"]]];
        processedPacket["DataBytes"] = Normal[processedPacket["DataByteArray"]];
        clearBuffer[processedPacket];
        processedPacket["Data"] = handler["Deserializer"][processedPacket["DataByteArray"]];
        processedPacket = invokeHandler[processedPacket];
        sendResponse[processedPacket];
        handler["Logger"][processedPacket];

        If[Length[remaining] === 0, Return[processedPacket]];
        processedPacket = Join[KeyDrop[packet, "Result"], <|
            "Handler" -> handler,
            "DataByteArray" -> remaining,
            "DataBytes" -> Normal[remaining],
            "Data" -> ByteArrayToString[remaining]
        |>]
    ]
];


createSocket[addressFamily: "IPv4" | "IPv6", protocol: "TCP" | "UDP": "TCP"] :=
With[{
    af = addressFamily /. {"IPv4" -> $AFINET, "IPv6" -> $AFINET6},
    proto = protocol /. {"TCP" -> $IPPROTOTCP, "UDP" -> $IPPROTOUDP}
},
    Check[
        With[{socketId = socketCreate[af, proto]},
            registerSocket[socketId, protocol, "Unspecified", "Blocking"];
            Return[socketId]
        ],

        Message[CSocketOpen::open, addressFamily, protocol, "socket creation"];
        Throw[$Failed]
    ]
];


bind::fail =
"Bind failed on socket `1` at `2`:`3`.";


bind[socketId_Integer, host_String, port_Integer] :=
Check[
    With[{result = socketBind[socketId, host, ToString[port]]},
        $CSockets[socketId, "Role"] = "Bound";
        $CSockets[socketId, "LocalAddress"] = host <> ":" <> ToString[port];
    ],

    Message[bind::fail, socketId, host, port];
    close[socketId];
    Throw[$Failed];
];


listen::fail =
"Listen failed on socket `1` at `2`.";


listen[socketId_Integer] :=
Check[
    With[{result = socketListen[socketId, $SOMAXCONN]},
        $CSockets[socketId, "Role"] = "Bound";
    ],

    Message[listen::fail, socketId, socketProperty[socketId, "LocalAddress"]];
    close[socketId];
    Throw[$Failed];
];


connect::fail =
"Connect failed on socket `1` to `2`:`3`.";

connect[socketId_Integer, host_String, port_Integer] :=
Check[
    With[{result = socketConnect[socketId, host, ToString[port]]},
        $CSockets[socketId, "Role"] = "Connected";
        $CSockets[socketId, "LocalAddress"] = socketGetAddresses[socketId, $SOCKETROLETCPCONNECTED];
        $CSockets[socketId, "RemoteAddress"] = host <> ":" <> ToString[port];
    ],

    Message[connect::fail, socketId, host, port];
    close[socketId];
    Throw[$Failed];
];


read::fail =
"Read failed on socket `1`.";


With[{buffer = ByteArray[ConstantArray[0, bufferSize]]},
    read[socketId_Integer] :=
    Check[
        If[socketProperty[socketId, "Protocol"] === "UDP",
            With[{received = socketRecvFrom[socketId, buffer]},
                If[!ListQ[received],
                    Throw[$Failed]
                ];

                Return[Apply[List] @ received];
            ],
        (*Else*)
            With[{received = socketRecv[socketId, buffer]},
                If[!ByteArrayQ[received],
                    Throw[$Failed]
                ];

                Return[received]
            ]
        ],

        (*Fail*)
        Message[read::fail, socketId];
        Throw[$Failed]
    ]
];


close::fail =
"Close failed on socket `1`.";


close[socketId_Integer] :=
Check[
    socketClose[socketId];
    KeyDropFrom[$CSockets, socketId];,

    Message[close::fail, socketId];
    Throw[$Failed]
];


toBlocking::fail =
"Failed to set socket `1` to blocking mode.";


toBlocking[socketId_Integer] :=
Check[
    socketSetBlockingMode[socketId];
    $CSockets[socketId, "BlockingMode"] = "Blocking";,

    Message[toBlocking::fail, socketId];
    Throw[$Failed]
];


toNonBlocking::fail =
"Failed to set socket `1` to non-blocking mode.";


toNonBlocking[socketId_Integer] :=
Check[
    socketSetNonBlockingMode[socketId];
    $CSockets[socketId, "BlockingMode"] = "NonBlocking";,

    Message[toNonBlocking::fail, socketId];
    Throw[$Failed]
];


socketProperty[socketId_Integer, key_String] :=
$CSockets[socketId, key];


socketSetProperty[socketId_Integer, key_String, value_] :=
If[KeyExistsQ[$CSockets[socketId], key],
    $CSockets[socketId, key] = value,
    $CSockets[socketId] = <|"key" -> value|>
];


makeSocketEvent[task_AsynchronousTaskObject, name_String, id_Integer, data___] :=
Join[<|"Timestamp" -> Now, "MultipartComplete" -> True, "Task" -> task, "Event" -> name|>, createEventData[name, id, data]];


createEventData["Accepted", listenId_Integer, acceptedId_Integer] :=
<|"ListenSocket" -> CSocketObject[listenId], "AcceptedSocket" -> CSocketObject[acceptedId]|>;


createEventData["Closed", id_Integer, ___] :=
<|"ClosedSocket" -> CSocketObject[id]|>;


createEventData["Error", id_Integer, code_] :=
<|"ErrorSocket" -> CSocketObject[id], "ErrorCode" -> code|>;


createEventData["Polled", data_List] :=
<|"Events" -> data|>;


createEventData["ReceivedFrom", id_Integer, address_String, bytes: (_List | _ByteArray | _NumericArray | 0): {}] :=
Join[createEventData["Received", id, bytes], <|"Address" -> address|>];


createEventData["Received", id_Integer, bytes: (_List | _ByteArray | _NumericArray | 0)] :=
With[{byteArray = If[bytes === 0, ByteArray[{}], ByteArray[bytes]], source = CSocketObject[id]},
    <|
        "Socket" -> Lookup[Lookup[$CSockets, id, <||>], "ListenSocket", source],
        "SourceSocket" -> source,
        "Data" :> ByteArrayToString[byteArray],
        "DataBytes" :> Normal[byteArray],
        "DataByteArray" :> byteArray
    |>
];


dispatchPollEvent[listId_Integer, handler_, task_AsynchronousTaskObject, name_String, data_List] :=
Module[{id, acceptedId},
    If[!KeyExistsQ[$socketLists, listId] || data === {}, Return[Null]];
    id = First[data];
    Switch[name,
        "Accepted",
            acceptedId = data[[2]];
            registerSocket[acceptedId, "TCP", $socketRoleTCPAccepted, False];
            setSocketProperty[acceptedId, "ListenSocket", CSocketObject[id]],
        "Closed",
            setSocketProperty[id, "State", "Closed"],
        "Error",
            If[!MemberQ[socketListGetAll[listId], id], setSocketProperty[id, "State", "Closed"]]
    ];
    handler[makeSocketEvent[task, name, Sequence @@ data]]
];


packetBufferKey[packet_Association] :=
If[KeyExistsQ[packet, "Address"],
    {packet["SourceSocket"]["UUID"], packet["Address"]},
    packet["SourceSocket"]["UUID"]
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
            Return[$Failed]
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


invokeHandler[packet_Association] :=
Module[{processedPacket = packet, handler = packet["Handler"], callback},
    callback = handler[packet["Event"]];
    processedPacket["Result"] = If[AssociationQ[callback], conditionApply[callback][packet], callback[packet]];
    processedPacket["Result"] = handler["Serializer"][processedPacket["Result"]];
    processedPacket
];


CSocketHandler::cntsnd =
"Can't send result to the client\n `1`";


CSocketHandler::packet =
"Cannot send response: invalid or missing `1` in packet.";


sendResponse[packet_Association] :=
Module[{result, write},
    If[!KeyExistsQ[packet, "Result"] || packet["Result"] === Null,
        Return[Null]
    ];

    result = packet["Result"];

    If[!MatchQ[result, _String | _ByteArray],
        Message[CSocketHandler::cntsnd, result];
        Return[$Failed]
    ];

    If[!MatchQ[Lookup[packet, "SourceSocket"], _CSocketObject],
        Message[CSocketHandler::packet, "SourceSocket"];
        Return[$Failed]
    ];

    write = If[StringQ[result], WriteString, BinaryWrite];

    If[KeyExistsQ[packet, "Address"],
        If[(!StringQ[packet["Address"]] || splitAddress[packet["Address"]] === $Failed),
            Message[CSocketHandler::packet, "Address"];
            Return[$Failed]
        ];

        write[packet["SourceSocket"], packet["Address"], result],
    (*Else*)
        write[packet["SourceSocket"], result]
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
With[{buffer = packet["Handler"]["Buffer"]["Lookup", packet["BufferKey"]]},
    If[!MissingQ[buffer], buffer["DropAll"]]
];


conditionApply[conditionAndFunctions: _ ? AssociationQ: <||>, defalut_: Function[Null], ___] :=
Function[
    With[{
        selected = SelectFirst[conditionAndFunctions, Function[f, First[f][##]], {defalut}]
    },
        selected[[-1]][##]
    ]
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
        "Protocol" -> protocol,
        "BlockingMode" -> blockingMode,
        "LocalAddress" -> "",
        "RemoteAddress" -> "",
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
splitAddress[HostLookup[host][[1, 1]], port, protocol];


splitAddress[address_String?protohostportQ] :=
Module[{proto, host, port, hostport},
    proto = If[StringStartsQ[address, "udp", IgnoreCase -> True],
        "UDP", "TCP"
    ];

    {host, port} = StringCases[StringSplit[address, "://"][[-1]],
        $host__ ~~ Shortest[":" ~~ $port__ ~~ EndOfString] :> {$host, ToExpression[$port]}
    ][[1]];

    splitAddress[host, port, proto]
];


addressQ[address__String] :=
MatchQ[{address}, {PatternSequence[_String?hostQ, _Integer?portQ, "TCP" | "UDP"]} |
{PatternSequence[_String?hostQ, _Integer?portQ]} |
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
StringMatchQ[host, $ipv6Pattern];


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
With[{pairs = StringCases[address, {"tcp://", "udp://", ""} ~~ host__ ~~ Shortest[":" ~~ port: NumberString ~~ EndOfString] :> {host, ToExpression[port]}]},
    Length[pairs] === 1 &&
    hostQ[pairs[[1, 1]]] &&
    portQ[pairs[[1, 2]]]
]


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


socketListPollLoopCrate::usage =
"socketListPollLoopCrate[list, timeout, eventsMask] -> taskId.";


socketListPollLoopCrate =
LibraryFunctionLoad[$library, "socketListPollLoopCrate", {Integer, Integer, Integer}, Integer];


socketListCreate::usage =
"socketListCreate[socketIds, socketRoles] -> socketListId.";


socketListCreate =
LibraryFunctionLoad[$library, "socketListCreate", {{Integer, 1}, {Integer, 1}}, Integer];


socketListAdd::usage =
"socketListAdd[list, socketId, role].";


socketListAdd =
LibraryFunctionLoad[$library, "socketListAdd", {Integer, Integer, Integer}, "Void"];


socketListGetAll::usage =
"socketListGetAll[list] -> socketsTensor.";


socketListGetAll =
LibraryFunctionLoad[$library, "socketListGetAll", {Integer}, {Integer, 1}];


socketListPrune::usage =
"socketListPrune[list].";


socketListPrune =
LibraryFunctionLoad[$library, "socketListPrune", {Integer}, "Void"];


socketListDelete::usage =
"socketListDelete[list].";


socketListDelete =
LibraryFunctionLoad[$library, "socketListDelete", {Integer}, "Void"];


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
"socketAccept[socketId] -> acceptedId.";


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


socketSend::usage =
"socketSend[socketId, bytes] -> sentLength.";


socketSend =
LibraryFunctionLoad[$library, "socketSend", {Integer, {"ByteArray", "Shared"}}, Integer];


socketSendTo::usage =
"socketSendTo[socketId, numerichost, port, data] -> sentLength.";


socketSendTo =
LibraryFunctionLoad[$library, "socketSendTo", {Integer, String, String, {"ByteArray", "Shared"}}, Integer];


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


test::usage =
"test[] -> result.";


test =
LibraryFunctionLoad[$library, "test", {}, "DataStore"];


End[];


EndPackage[];
