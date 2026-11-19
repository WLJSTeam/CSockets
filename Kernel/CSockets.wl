(* ::Package:: *)

BeginPackage["WLJS`CSockets`",
    {
        "LibraryLink`",
        "CCompilerDriver`"
    }
];


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


$CSockets::usage =
"$CSockets - association of socket IDs to objects and metadata.";


$CSocketsDirectory::usage =
"$CSocketsDirectory - internal variable for storing the directory of the CSockets package.";


Begin["`Private`"];


$CSocketsDirectory =
DirectoryName[$InputFileName, 2];


If[!AssociationQ[$CSockets], $CSockets = <||>];


splitAddress[address_String] :=
Module[{parts},
    parts = StringCases[address, {
        StartOfString ~~ "[" ~~ host: Except["]"].. ~~ "]:" ~~ port: DigitCharacter.. ~~ EndOfString :> {host, port},
        StartOfString ~~ host: Except[":"].. ~~ ":" ~~ port: DigitCharacter.. ~~ EndOfString :> {host, port}
    }];
    If[Length[parts] === 1, First[parts], $Failed]
];


If[!AssociationQ[$socketLists], $socketLists = <||>];


If[!AssociationQ[$socketListTasks], $socketListTasks = <||>];


If[!AssociationQ[$ownedSocketLists], $ownedSocketLists = <||>];


registerSocket[id_Integer, protocol_String, role_String, blocking: True | False] :=
Module[{object = CSocketObject[id]},
    $CSockets[id] = <|
        "Object" -> object,
        "Protocol" -> protocol,
        "BlockingMode" -> If[blocking, "Blocking", "NonBlocking"],
        "LocalAddress" -> "",
        "RemoteAddress" -> "",
        "State" -> "Alive",
        "Role" -> role
    |>;
    refreshSocketAddresses[id];
    object
];


socketProperty[id_Integer, key_String] :=
Lookup[Lookup[$CSockets, id, <||>], key, Missing["NotAvailable"]];


setSocketProperty[id_Integer, key_String, value_] :=
($CSockets[id] = Append[Lookup[$CSockets, id, <||>], key -> value]);


refreshSocketAddresses[id_Integer] :=
Module[{addresses, role = socketProperty[id, "Role"]},
    If[socketProperty[id, "State"] =!= "Alive", Return[Null]];
    addresses = Quiet[Check[List @@ socketGetAddresses[id, Replace[role, {"Undefined" -> 0, "Binded" -> 1, "Connected" -> 2, "Accepted" -> 3}]], $Failed]];
    If[MatchQ[addresses, {_String, _String}],
        setSocketProperty[id, "LocalAddress", addresses[[1]]];
        setSocketProperty[id, "RemoteAddress", addresses[[2]]]
    ];
    Null
];


socketAliveQ[id_Integer] :=
socketProperty[id, "State"] =!= "Closed";


setSocketBlocking[id_Integer, blocking: True | False] :=
Module[{result},
    If[!socketAliveQ[id], Return[$Failed]];
    result = Quiet[Check[If[blocking, socketSetBlockingMode[id], socketSetNonBlockingMode[id]], $Failed]];
    If[result =!= Null, Return[$Failed]];
    setSocketProperty[id, "BlockingMode", If[blocking, "Blocking", "NonBlocking"]];
    Null
];


createSocket[family_Integer, protocol: "TCP" | "UDP"] :=
Module[{id},
    id = Quiet[Check[socketCreate[family, protocol /. {"TCP" -> $IPPROTOTCP, "UDP" -> $IPPROTOUDP}], $Failed]];
    If[!IntegerQ[id], Return[$Failed]];
    registerSocket[id, protocol, "Undefined", True];
    id
];


bindSocket[id_Integer, host_String, port_Integer] :=
Module[{result},
    If[!socketAliveQ[id], Return[$Failed]];
    result = Quiet[Check[socketBind[id, host, ToString[port]], $Failed]];
    If[result =!= Null, Return[$Failed]];
    setSocketProperty[id, "Role", "Binded"];
    refreshSocketAddresses[id];
    Null
];


connectSocket[id_Integer, host_String, port_Integer] :=
Module[{result},
    If[!socketAliveQ[id], Return[$Failed]];
    result = Quiet[Check[socketConnect[id, host, ToString[port]], $Failed]];
    If[result =!= Null, Return[$Failed]];
    setSocketProperty[id, "Role", "Connected"];
    refreshSocketAddresses[id];
    Null
];


acceptSocket[id_Integer, blocking: True | False] :=
Module[{acceptedId},
    If[!socketAliveQ[id], Return[$Failed]];
    acceptedId = Quiet[Check[socketAccept[id, !blocking], $Failed]];
    If[!IntegerQ[acceptedId], Return[$Failed]];
    registerSocket[acceptedId, "TCP", "Accepted", blocking];
    setSocketProperty[acceptedId, "ListenSocket", CSocketObject[id]];
    refreshSocketAddresses[id];
    acceptedId
];


(* An unsuccessful constructor must release its intermediate socket. *)
discardSocket[id_Integer] :=
If[Close[CSocketObject[id]] === Null, KeyDropFrom[$CSockets, id]];


CSocketOpen::open =
"Cannot open `3` socket at `1`:`2`: `4` failed.";


CSocketOpen[host_String: "127.0.0.1", port_Integer: 0, protocol: "TCP" | "UDP": "TCP"] :=
Module[{id},
    id = createSocket[If[StringContainsQ[host, ":"], $AFINET6, $AFINET], protocol];
    If[!IntegerQ[id],
        Message[CSocketOpen::open, host, port, protocol, "socket creation"];
        Return[$Failed]
    ];
    If[bindSocket[id, host, port] =!= Null,
        discardSocket[id];
        Message[CSocketOpen::open, host, port, protocol, "bind"];
        Return[$Failed]
    ];
    If[protocol === "TCP" && Quiet[Check[socketListen[id, $SOMAXCONN], $Failed]] =!= Null,
        discardSocket[id];
        Message[CSocketOpen::open, host, port, protocol, "listen"];
        Return[$Failed]
    ];
    socketProperty[id, "Object"]
];


Options[CSocketConnect] = {
    "Wait" -> False,
    "Blocking" -> True
};


CSocketConnect::opts =
"CSocketConnect called with invalid option `1` -> `2`.";


CSocketConnect::connect =
"Cannot connect `3` socket to `1`:`2`: `4` failed.";


CSocketConnect[host_String: "127.0.0.1", port_Integer, protocol: "TCP" | "UDP": "TCP", OptionsPattern[]] :=
Module[{wait = OptionValue["Wait"], blocking = OptionValue["Blocking"], id},
    If[!BooleanQ[wait], Message[CSocketConnect::opts, "Wait", wait]; Return[$Failed]];
    If[!BooleanQ[blocking], Message[CSocketConnect::opts, "Blocking", blocking]; Return[$Failed]];
    id = createSocket[If[StringContainsQ[host, ":"], $AFINET6, $AFINET], protocol];
    If[!IntegerQ[id],
        Message[CSocketConnect::connect, host, port, protocol, "socket creation"];
        Return[$Failed]
    ];
    If[!wait && setSocketBlocking[id, False] =!= Null,
        discardSocket[id];
        Message[CSocketConnect::connect, host, port, protocol, "setting nonblocking mode"];
        Return[$Failed]
    ];
    If[connectSocket[id, host, port] =!= Null,
        discardSocket[id];
        Message[CSocketConnect::connect, host, port, protocol, "connect"];
        Return[$Failed]
    ];
    If[wait && !blocking && setSocketBlocking[id, False] =!= Null,
        discardSocket[id];
        Message[CSocketConnect::connect, host, port, protocol, "setting nonblocking mode"];
        Return[$Failed]
    ];
    If[!wait && blocking && setSocketBlocking[id, True] =!= Null,
        discardSocket[id];
        Message[CSocketConnect::connect, host, port, protocol, "restoring blocking mode"];
        Return[$Failed]
    ];
    socketProperty[id, "Object"]
];


$socketObjectIcon := $socketObjectIcon =
Import[FileNameJoin[{$CSocketsDirectory, "Images", "SocketIcon.png"}]];


CSocketObject /: MakeBoxes[object: CSocketObject[id_Integer], form: (StandardForm | TraditionalForm)] :=
Module[{above, below},
    above = {
        {BoxForm`SummaryItem[{"SocketID: ", id}], SpanFromLeft},
        {BoxForm`SummaryItem[{"Host: ", object["Host"]}], SpanFromLeft},
        {BoxForm`SummaryItem[{"Port: ", object["DestinationPort"]}], SpanFromLeft}
    };
    below = Map[{BoxForm`SummaryItem[{# <> ": ", object[#]}], SpanFromLeft}&, {"Protocol", "State", "Role", "BlockingMode"}];
    BoxForm`ArrangeSummaryBox[CSocketObject, object, $socketObjectIcon, above, below, form, "Interpretable" -> Automatic]
];


CSocketObject[id_Integer]["Host"] :=
With[{parts = splitAddress[CSocketObject[id]["LocalAddress"]]},
    If[ListQ[parts], First[parts], Missing["NotAvailable"]]
];


CSocketObject[id_Integer]["DestinationPort"] :=
With[{parts = splitAddress[CSocketObject[id]["LocalAddress"]]},
    If[ListQ[parts], FromDigits[Last[parts]], Missing["NotAvailable"]]
];


CSocketObject[id_Integer]["DirectionType"] :=
If[socketProperty[id, "Role"] === "Binded", "Server", "Client"];


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
Module[{id = socketListCreate[], list},
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
        socketListAdd[listId, id]
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


makeSocketEvent[task_AsynchronousTaskObject, name_String, id_Integer, data___] :=
Join[<|"Timestamp" -> Now, "MultipartComplete" -> True, "Task" -> task, "Event" -> name|>, createEventData[name, id, data]];


createEventData["Accepted", listenId_Integer, acceptedId_Integer] :=
<|"ListenSocket" -> CSocketObject[listenId], "AcceptedSocket" -> CSocketObject[acceptedId]|>;


createEventData["Closed", id_Integer, ___] :=
<|"ClosedSocket" -> CSocketObject[id]|>;


createEventData["Error", id_Integer, code_] :=
<|"ErrorSocket" -> CSocketObject[id], "ErrorCode" -> code|>;


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


(* Poll notifications may already be queued after another callback drained a
   socket. Recheck readiness and use nonblocking IO before consuming data. *)
dispatchPollEvent[listId_Integer, handler_, task_AsynchronousTaskObject, "Polled", {rows_List}] :=
If[KeyExistsQ[$socketLists, listId], Scan[processSocketEvent[listId, handler, task, #]&, rows]];


dispatchPollEvent[listId_Integer, handler_, task_AsynchronousTaskObject, "Error", {code_Integer}] :=
handler[<|"Timestamp" -> Now, "Task" -> task, "Event" -> "Error", "ErrorCode" -> code|>];


processSocketEvent[listId_Integer, handler_, task_AsynchronousTaskObject, {id_Integer, mask_Integer}] :=
Module[{object = CSocketObject[id], ready, accepted, data, event, protocol, role},
    If[!KeyExistsQ[$socketLists, listId] || !socketAliveQ[id], Return[Null]];
    protocol = socketProperty[id, "Protocol"];
    role = socketProperty[id, "Role"];
    If[BitAnd[mask, $POLLIN] != 0,
        ready = Quiet[Check[socketsPoll[{id}, 0, $POLLIN], $Failed]];
        If[!ListQ[ready] || ready === {}, Return[Null]];
        If[setSocketBlocking[id, False] === $Failed, Return[Null]];
        If[protocol === "TCP" && role === "Binded",
            accepted = acceptSocket[id, False];
            If[!IntegerQ[accepted], Return[Null]];
            event = makeSocketEvent[task, "Accepted", id, accepted];
            If[socketListAdd[listId, accepted] =!= Null, Close[CSocketObject[accepted]]; Return[$Failed]];
            handler[event];
            Return[Null]
        ];
        data = Quiet[Check[SocketReadMessage[object], $Failed]];
        If[MatchQ[data, _ByteArray],
            If[Length[data] > 0,
                handler[makeSocketEvent[task, "Received", id, data]],
                Close[object];
                handler[makeSocketEvent[task, "Closed", id]];
                If[KeyExistsQ[$socketLists, listId], socketListPrune[listId]]
            ];
            Return[Null]
        ];
        If[MatchQ[data, {(_ByteArray | _NumericArray | {}), _String}],
            handler[makeSocketEvent[task, "ReceivedFrom", id, data[[2]], data[[1]]]];
            Return[Null]
        ];
    ];
    If[BitAnd[mask, $POLLERR + $POLLHUP + $POLLNVAL] != 0,
        Close[object];
        If[KeyExistsQ[$socketLists, listId], socketListPrune[listId]];
        handler[makeSocketEvent[task, If[BitAnd[mask, $POLLERR + $POLLNVAL] != 0, "Error", "Closed"], id, mask]]
    ];
    Null
];


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


packetBufferKey[packet_Association] :=
If[KeyExistsQ[packet, "Address"],
    {packet["SourceSocket"]["UUID"], packet["Address"]},
    packet["SourceSocket"]["UUID"]
];


CSocketHandler::length =
"Accumulator returned invalid expected length `1`.";


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
            "DataLength" -> dataLength
        |>]
    ]
];


getMessage[packet_Association] :=
With[{buffer = packet["Handler"]["Buffer"]["Lookup", packetBufferKey[packet]]},
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
    If[!KeyExistsQ[packet, "Result"], Return[Null]];

    result = packet["Result"];

    If[result === Null, Return[Null]];

    If[!MatchQ[result, _ByteArray | _String],
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
With[{handler = packet["Handler"], key = packetBufferKey[packet]},
    With[{buffer = handler["Buffer"]["Lookup", key]},
        If[!MissingQ[buffer],
            buffer["Append", packet],
            handler["Buffer"]["Insert", key -> CreateDataStructure["DynamicArray", {packet}]]
        ]
    ]
];


clearBuffer[packet_Association] :=
With[{buffer = packet["Handler"]["Buffer"]["Lookup", packetBufferKey[packet]]},
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


If[!AssociationQ[$csockets],
    $csockets = <||>
];


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


socketsPollAsync::usage =
"socketsPollAsync[socketIds, timeout, eventsMask] -> taskId.";


socketsPollAsync =
LibraryFunctionLoad[$library, "socketsPollAsync", {{Integer, 1}, Integer, Integer}, Integer];


createSocketsPollLoop::usage =
"createSocketsPollLoop[list, timeout, eventsMask] -> taskId.";


createSocketsPollLoop =
LibraryFunctionLoad[$library, "createSocketsPollLoop", {Integer, Integer, Integer}, Integer];


socketListCreate::usage =
"socketListCreate[] -> socketListId.";


socketListCreate =
LibraryFunctionLoad[$library, "socketListCreate", {}, Integer];


socketListAdd::usage =
"socketListAdd[list, socketId].";


socketListAdd =
LibraryFunctionLoad[$library, "socketListAdd", {Integer, Integer}, "Void"];


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


socketGetPort::usage =
"socketGetPort[socketId] -> port.";


socketGetPort =
LibraryFunctionLoad[$library, "socketGetPort", {Integer}, Integer];


socketGetHost::usage =
"socketGetHost[socketId] -> host.";


socketGetHost =
LibraryFunctionLoad[$library, "socketGetHost", {Integer}, String];


socketListen::usage =
"socketListen[socketId, backlog].";


socketListen =
LibraryFunctionLoad[$library, "socketListen", {Integer, Integer}, "Void"];


socketConnect::usage =
"socketConnect[socketId, numerichost, port].";


socketConnect =
LibraryFunctionLoad[$library, "socketConnect", {Integer, String, String}, "Void"];


socketAccept::usage =
"socketAccept[socketId, nonBlocking] -> acceptedId.";


socketAccept =
LibraryFunctionLoad[$library, "socketAccept", {Integer, Alternatives[True, False]}, Integer];


socketRecv::usage =
"socketRecv[socketId, buffer] -> receivedData.";


socketRecv =
LibraryFunctionLoad[$library, "socketRecv", {Integer, {"ByteArray", "Shared"}}, "ByteArray"];


socketRecvFrom::usage =
"socketRecvFrom[socketId, buffer] -> dataStore.";


socketRecvFrom =
LibraryFunctionLoad[$library, "socketRecvFrom", {Integer, {"ByteArray", "Shared"}}, "DataStore"];


socketSend::usage =
"socketSend[socketId, bytes, length] -> sentLength.";


socketSend =
LibraryFunctionLoad[$library, "socketSend", {Integer, {"ByteArray", "Shared"}, Integer}, Integer];


socketSendTo::usage =
"socketSendTo[socketId, numerichost, port, data] -> sentLength.";


socketSendTo =
LibraryFunctionLoad[$library, "socketSendTo", {Integer, String, String, {"ByteArray", "Shared"}}, Integer];


socketsCheck::usage =
"socketsCheck[sockets] -> validSockets.";


socketsCheck =
LibraryFunctionLoad[$library, "socketsCheck", {{Integer, 1}}, {Integer, 1}];


socketConnectedQ::usage =
"socketConnectedQ[socketId, blockingMode] -> False.";


socketConnectedQ =
LibraryFunctionLoad[$library, "socketConnectedQ", {Integer, Alternatives[True, False]}, Alternatives[True, False]];


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
