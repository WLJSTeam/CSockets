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
"CSocketObject[{socket, protocol, type, role, state, mode}]";


CSocketList::usage =
"CSocketList[{socket1, socket2, ...}]";


CSocketHandler::usage =
"CSocketHandler[] mutable handler object.";


AddressStorage::usage =
"AddressStorage[storage] wraps native sockaddr_storage bytes and exposes address properties.";


$CSockets::usage =
"$CSockets - internal variable for storing socket objects.";


$CSocketsDirectory::usage =
"$CSocketsDirectory - internal variable for storing the directory of the CSockets package.";


Begin["`Private`"];


$CSocketsDirectory =
DirectoryName[$InputFileName, 2];


If[!AssociationQ[$CSockets], $CSockets = <||>];


AddressStorage[storage_ByteArray]["Host"] :=
With[{host = socketAddressStorageHost[storage]},
    If[StringQ[host], host, $Failed]
];


AddressStorage[storage_ByteArray][property: "Port" | "Family"] :=
With[{properties = socketAddressStorageInspect[storage]},
    If[!MatchQ[properties, {_Integer, _Integer}], Return[$Failed]];

    Switch[property,
        "Family", If[First[properties] === 4, "IPv4", "IPv6"],
        "Port", properties[[2]]
    ]
];


$addressStorageIcon := $addressStorageIcon =
Import[FileNameJoin[{$CSocketsDirectory, "Images", "AddressIcon.png"}]];


AddressStorage /: MakeBoxes[
    addressStorage: AddressStorage[storage_ByteArray],
    form: (StandardForm | TraditionalForm)
] :=
With[{
    icon = $addressStorageIcon,
    above = {
        {BoxForm`SummaryItem[{"Family: ", addressStorage["Family"]}], SpanFromLeft},
        {BoxForm`SummaryItem[{"Host: ", addressStorage["Host"]}], SpanFromLeft},
        {BoxForm`SummaryItem[{"Port: ", addressStorage["Port"]}], SpanFromLeft}
    }
},
    BoxForm`ArrangeSummaryBox[
        Head[addressStorage],
        addressStorage,
        icon,
        above,
        {},
        form,
        "Interpretable" -> Automatic
    ]
];


CSocketOpen::open =
"Cannot open `3` socket at `1`:`2`: `4` failed.";


CSocketOpen[host_String: "localhost", port_Integer: 0, protocol: "TCP" | "UDP": "TCP"] :=
With[{
    addressStorage = Check[
        socketAddressStorageCreate[
            host, ToString[port],
            $AFINET,
            protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
            $IPPROTOAUTO, ""
        ],
        $Failed
    ]
},
    If[!ByteArrayQ[addressStorage],
        Message[CSocketOpen::open, host, port, protocol, "address resolution"];
        Return[$Failed]
    ];

    With[{
        socketObject = Check[
            socketCreate[
                $AFINET,
                protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
                $IPPROTOAUTO
            ],
            $Failed
        ]
    },
        If[!MatchQ[socketObject, socketDataPattern],
            Message[CSocketOpen::open, host, port, protocol, "socket creation"];
            Return[$Failed]
        ];

        Check[socketBind[socketObject, addressStorage],
            socketClose[socketObject];
            Message[CSocketOpen::open, host, port, protocol, "bind"];
            Return[$Failed]
        ];

        If[protocol === "TCP", 
            Check[socketListen[socketObject, $SOMAXCONN],
                socketClose[socketObject];
                Message[CSocketOpen::open, host, port, protocol, "listen"];
                Return[$Failed]
            ]
        ];

        $CSockets[First[socketObject]] = CSocketObject[socketObject]
    ]
];


Options[CSocketConnect] = {
    "Wait" -> False,
    "Blocking" -> True
};


CSocketConnect::opts =
"CSocketConnect called with invalid option `1` -> `2`.";


CSocketConnect::connect =
"Cannot connect `3` socket to `1`:`2`: `4` failed.";


CSocketConnect[host_String: "localhost", port_Integer, protocol: "TCP" | "UDP": "TCP", OptionsPattern[]] :=
With[{
    wait = OptionValue["Wait"],
    blocking = OptionValue["Blocking"]
},
    If[!BooleanQ[wait],
        Message[CSocketConnect::opts, "Wait", wait];
        Return[$Failed]
    ];

    If[!BooleanQ[blocking],
        Message[CSocketConnect::opts, "Blocking", blocking];
        Return[$Failed]
    ];

    With[{
        addressStorage = Check[
            socketAddressStorageCreate[
                host, ToString[port],
                $AFINET,
                protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
                $IPPROTOAUTO, ""
            ],
            $Failed
        ]
    },
        If[!ByteArrayQ[addressStorage],
            Message[CSocketConnect::connect, host, port, protocol, "address resolution"];
            Return[$Failed]
        ];

        With[{
            socketObject = Check[
                socketCreate[
                    $AFINET,
                    protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
                    $IPPROTOAUTO
                ],
                $Failed
            ]
        },
            If[!MatchQ[socketObject, socketDataPattern],
                Message[CSocketConnect::connect, host, port, protocol, "socket creation"];
                Return[$Failed]
            ];

            If[(!blocking || !wait) && Quiet[Check[socketSetNonBlockingMode[socketObject], $Failed]] =!= Null,
                socketClose[socketObject];
                Message[CSocketConnect::connect, host, port, protocol, "setting nonblocking mode"];
                Return[$Failed]
            ];

            Check[socketConnect[socketObject, addressStorage],
                socketClose[socketObject];
                Message[CSocketConnect::connect, host, port, protocol, "connect"];
                Return[$Failed]
            ];

            If[!wait && blocking, 
                Check[socketSetBlockingMode[socketObject],
                    socketClose[socketObject];
                    Message[CSocketConnect::connect, host, port, protocol, "restoring blocking mode"];
                    Return[$Failed]
                ]
            ];

            $CSockets[First[socketObject]] = CSocketObject[socketObject]
        ]
    ]
];


$socketObjectIcon := $socketObjectIcon =
Import[FileNameJoin[{$CSocketsDirectory, "Images", "SocketIcon.png"}]];


CSocketObject /: MakeBoxes[
    socketObject: CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}],
    form: (StandardForm | TraditionalForm)
] :=
With[{
    icon = $socketObjectIcon,
    host = If[socketData[[5]] === 1, Quiet[Check[socketGetHost[socketData], Missing["NotAvailable"]]], Missing["NotAvailable"]],
    port = If[socketData[[5]] === 1, Quiet[Check[socketGetPort[socketData], Missing["NotAvailable"]]], Missing["NotAvailable"]]
},
    Module[{above, below},
        above = {
            {BoxForm`SummaryItem[{"SocketID: ", socketData[[1]]}], SpanFromLeft},
            {BoxForm`SummaryItem[{"Host: ", host}], SpanFromLeft},
            {BoxForm`SummaryItem[{"Port: ", port}], SpanFromLeft}
        };
        below = {
            {BoxForm`SummaryItem[{"Protocol: ", socketData[[3]] /. {1 -> "TCP", 2 -> "UDP"}}], SpanFromLeft},
            {BoxForm`SummaryItem[{"State: ", socketData[[5]] /. {0 -> "Closed", 1 -> "Alive"}}], SpanFromLeft},
            {BoxForm`SummaryItem[{"Role: ", socketData[[4]] /. {0 -> "Interrupter", 1 -> "Listener", 2 -> "Connected", 3 -> "Accepted"}}], SpanFromLeft},
            {BoxForm`SummaryItem[{"Mode: ", socketData[[6]] /. {0 -> "Blocking", 1 -> "Non blocking"}}], SpanFromLeft}
        };

        (*Return*)
        BoxForm`ArrangeSummaryBox[
            Head[socketObject],
            socketObject,
            icon,
            above,
            below,
            form,
            "Interpretable" -> Automatic
        ]
    ]
];


socketDataPattern = 
{_Integer, _Integer, _Integer, _Integer, _Integer, _Integer};


CSocketObject[socketData: sockeDataPattern]["Host"] :=
socketGetHost[socketData];



CSocketObject[socketData: sockeDataPattern]["DestinationPort"] :=
socketGetPort[socketData];


CSocketObject[socketData: sockeDataPattern]["DirectionType"] :=
If[socketData[[4]] === 1, "Server", "Client"];


CSocketObject[socketData: sockeDataPattern]["InprocQ"] :=
False;


CSocketObject[socketData: sockeDataPattern]["Protocol"] :=
If[socketData[[3]] === $SOCKDGRAM, "UDP", "TCP"];


CSocketObject[socketData: sockeDataPattern]["Scheme"] :=
If[socketData[[3]] === $SOCKDGRAM, "udp", "tcp"];


CSocketObject[socketData: sockeDataPattern]["UUID"] :=
First[socketData];


CSocketObject /: Close[socketObject: CSocketObject[socketData: sockeDataPattern]] :=
With[{id = First[socketData]},
    Check[socketClose[socketData], Return[$Failed]];
    KeyDropFrom[$CSockets, {id, socketObject}];
];


CSocketObject /: WriteString[
    socketObject: CSocketObject[socketData: sockeDataPattern],
    text_String
] :=
BinaryWrite[socketObject, StringToByteArray[text]];


CSocketObject /: WriteString[
    socketObject: CSocketObject[socketData: sockeDataPattern],
    addressStorage: AddressStorage[storage_ByteArray],
    text_String
] :=
BinaryWrite[socketObject, addressStorage, StringToByteArray[text]];


CSocketObject /: BinaryWrite[
    socketObject: CSocketObject[socketData: sockeDataPattern],
    bytes_ByteArray
] :=
Module[{length = Length[bytes], sent, remaining},
    sent = socketSend[socketData, bytes, length];
    If[!IntegerQ[sent], Return[sent]];
    If[sent === length, Return[sent]];
    If[sent <= 0 || sent > length, Return[$Failed]];

    remaining = BinaryWrite[socketObject, bytes[[sent + 1 ;;]]];
    If[IntegerQ[remaining], sent + remaining, remaining]
];


CSocketObject /: BinaryWrite[
    socketObject: CSocketObject[socketData: sockeDataPattern],
    addressStorage: AddressStorage[storage_ByteArray],
    bytes_ByteArray
] :=
Module[{length = Length[bytes], sent, remaining},
    sent = socketSendToAddressStorage[socketData, storage, bytes];
    If[!IntegerQ[sent], Return[sent]];
    If[sent === length, Return[sent]];
    If[sent <= 0 || sent > length, Return[$Failed]];

    remaining = BinaryWrite[socketObject, addressStorage, bytes[[sent + 1 ;;]]];
    If[IntegerQ[remaining], sent + remaining, remaining]
];


CSocketObject /: SocketReadyQ[
    CSocketObject[socketData: sockeDataPattern],
    t_: 0
] :=
Module[{events},
    If[socketData[[5]] === 0 || socketsCheck[{socketData}, 1] === {}, Return[$Failed]];
    events = socketsPoll[{socketData}, 1, Round[t * 10 ^ 6], $POLLIN];
    If[!ListQ[events], Return[$Failed]];
    Length[events] > 0 && BitAnd[events[[1, 7]], $POLLIN] != 0
];


With[{readMessageBuffer = ByteArray[ConstantArray[0, 64 * 1024]]}, 
    CSocketObject /: SocketReadMessage[
        CSocketObject[socketData: sockeDataPattern]
    ] :=
    If[socketData[[3]] =!= $SOCKDGRAM,
        socketRecv[socketData, readMessageBuffer], 
    (*Else*)
        Apply[List][socketRecvFrom[socketData, readMessageBuffer]]
    ]
];


If[Not[ListQ[$ListenCSockets]], $ListenCSockets = {}];


CSocketList[initialSockets: {__CSocketObject}] :=
Module[{socketListId = socketListCreate[], socketList},
    socketList = CSocketList[socketListId];
    Scan[Append[socketList, #]&, initialSockets];
    socketList
];


CSocketObject /: SocketWaitNext[
    CSocketObject[socketData: sockeDataPattern]
] :=
socketsSelect[{socketData}, 1, 2 ^ 10, 1];


CSocketList /: Append[
    CSocketList[socketListId_Integer],
    CSocketObject[socketData: sockeDataPattern]
] :=
socketListAdd[socketListId, socketData];


CSocketList /: DeleteMissing[CSocketList[socketListId_Integer]] :=
socketListPrune[socketListId];


CSocketList /: SocketListen[CSocketList[socketListId_Integer], handler_] :=
With[{
    bufferSize = 8 * 1024,
    usecInterval = 10 ^ 6,
    eventMask = $POLLIN
},
    Internal`CreateAsynchronousTask[
        createSocketsPollLoop,
        {socketListId, bufferSize, usecInterval, eventMask},
        handler[createEvent[##]]&
    ]
];


CSocketObject /: SocketListen[serverSocket_CSocketObject, handler_] :=
SocketListen[CSocketList[{serverSocket}], handler];


createEvent[
    task_AsynchronousTaskObject,
    eventName_String,
    {socketData: sockeDataPattern, data___}
] :=
Join[
    <|
        "Timestamp" -> Now,
        "MultipartComplete" -> True,
        "Task" -> task,
        "Event" -> eventName
    |>,
    createEventData[eventName, socketData, data]
];


createEventData[
    "Accepted",
    listenData: sockeDataPattern,
    acceptedData: sockeDataPattern
] :=
With[{
    listenSocket = CSocketObject[listenData],
    acceptedSocket = CSocketObject[acceptedData]
},
    $CSockets[First[acceptedData]] = acceptedSocket;
    $CSockets[acceptedSocket] = listenSocket;
    <|"ListenSocket" -> listenSocket, "AcceptedSocket" -> acceptedSocket|>
];


createEventData["Closed", socketData: sockeDataPattern, ___] :=
<|"ClosedSocket" -> CSocketObject[ReplacePart[socketData, 5 -> 0]]|>;


createEventData["Error", socketData: sockeDataPattern, errorCode_Integer] :=
<|"ErrorSocket" -> CSocketObject[socketData], "ErrorCode" -> errorCode|>;


createEventData[
    "ReceivedFrom",
    socketData: sockeDataPattern,
    address: (_ByteArray | _NumericArray),
    bytes: (_List | _ByteArray | _NumericArray | 0): {}
] :=
Join[createEventData["Received", socketData, bytes], <|"AddressStorage" -> AddressStorage[ByteArray[address]]|>];


createEventData[
    "Received",
    socketData: sockeDataPattern,
    bytes: (_List | _ByteArray | _NumericArray | 0)
] :=
With[{
    byteArray = If[bytes === 0, ByteArray[{}], ByteArray[bytes]],
    source = CSocketObject[socketData]
},
    <|
        "Socket" -> $CSockets[source],
        "SourceSocket" -> source,
        "Data" :> ByteArrayToString[byteArray],
        "DataBytes" :> Normal[byteArray],
        "DataByteArray" :> byteArray
    |>
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
If[KeyExistsQ[packet, "AddressStorage"],
    {packet["SourceSocket"]["UUID"], packet["AddressStorage"]},
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

    If[KeyExistsQ[packet, "AddressStorage"],
        If[!MatchQ[packet["AddressStorage"], AddressStorage[_ByteArray]],
            Message[CSocketHandler::packet, "AddressStorage"];
            Return[$Failed]
        ];

        write[packet["SourceSocket"], packet["AddressStorage"], result],
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


$INTERUPTER = 0;


$TCPSERVER = 1;


$UDPSERVER = 2;


$TCPCLIENT = 3;


$UDPCLIENT = 4;


$TCPACCEPTED = 5;


(* Protocol levels *)


$IPPROTOAUTO::usage =
"IPPROTOAUTO - auto protocol level";


$IPPROTOAUTO = 0;


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


$AFINET6 = 16^^000A;


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


socketAddressStorageCreate::usage =
"socketAddressStorageCreate[host, port, aiFamily, aiSocktype, aiProtocol, localIP] -> address.";


socketAddressStorageCreate =
LibraryFunctionLoad[$library, "socketAddressStorageCreate", {String, String, Integer, Integer, Integer, String}, "ByteArray"];


socketAddressStorageHost::usage =
"socketAddressStorageHost[addressStorage] -> host.";


socketAddressStorageHost =
LibraryFunctionLoad[$library, "socketAddressStorageHost", {"ByteArray"}, String];


socketAddressStorageInspect::usage =
"socketAddressStorageInspect[addressStorage] -> properties.";


socketAddressStorageInspect =
LibraryFunctionLoad[$library, "socketAddressStorageInspect", {"ByteArray"}, {Integer, 1}];


socketsSelectAsync::usage =
"socketsSelectAsync[socketIds, length, timeout] -> taskId.";


socketsSelectAsync =
LibraryFunctionLoad[$library, "socketsSelectAsync", {{Integer, 2}, Integer, Integer}, Integer];


createSocketsPollLoop::usage =
"createSocketsPollLoop[socketList, bufferSize, timeout, eventsMask] -> taskId.";


createSocketsPollLoop =
LibraryFunctionLoad[$library, "createSocketsPollLoop", {Integer, Integer, Integer, Integer}, Integer];


socketListCreate::usage =
"socketListCreate[] -> socketListPtr.";


socketListCreate =
LibraryFunctionLoad[$library, "socketListCreate", {}, Integer];


socketListAdd::usage =
"socketListAdd[socketList, socketObject].";


socketListAdd =
LibraryFunctionLoad[$library, "socketListAdd", {Integer, {Integer, 1, "Shared"}}, "Void"];


socketListGetAll::usage =
"socketListGetAll[socketList] -> socketsTensor.";


socketListGetAll =
LibraryFunctionLoad[$library, "socketListGetAll", {Integer}, {Integer, 2}];


socketListPrune::usage =
"socketListPrune[socketList].";


socketListPrune =
LibraryFunctionLoad[$library, "socketListPrune", {Integer}, "Void"];


socketListDelete::usage =
"socketListDelete[socketList].";


socketListDelete =
LibraryFunctionLoad[$library, "socketListDelete", {Integer}, "Void"];


socketCreate::usage =
"socketCreate[family, socktype, protocol] -> socketObject.";


socketCreate =
LibraryFunctionLoad[$library, "socketCreate", {Integer, Integer, Integer}, {Integer, 1}];


socketClose::usage =
"socketClose[socketObject].";


socketClose =
LibraryFunctionLoad[$library, "socketClose", {{Integer, 1, "Shared"}}, "Void"];


socketBind::usage =
"socketBind[socketObject, addressStorage].";


socketBind =
LibraryFunctionLoad[$library, "socketBind", {{Integer, 1, "Shared"}, "ByteArray"}, "Void"];


socketSetOpt::usage =
"socketSetOpt[socketObject, level, optname, optval].";


socketSetOpt =
LibraryFunctionLoad[$library, "socketSetOpt", {{Integer, 1}, Integer, Integer, Integer}, "Void"];


socketGetOpt::usage =
"socketGetOpt[socketObject, level, optname] -> optval.";


socketGetOpt =
LibraryFunctionLoad[$library, "socketGetOpt", {{Integer, 1}, Integer, Integer}, Integer];


socketSetBlockingMode::usage =
"socketSetBlockingMode[socketObject].";


socketSetBlockingMode =
LibraryFunctionLoad[$library, "socketSetBlockingMode", {{Integer, 1, "Shared"}}, "Void"];


socketSetNonBlockingMode::usage =
"socketSetNonBlockingMode[socketObject].";


socketSetNonBlockingMode =
LibraryFunctionLoad[$library, "socketSetNonBlockingMode", {{Integer, 1, "Shared"}}, "Void"];


socketGetPort::usage =
"socketGetPort[socketObject] -> port.";


socketGetPort =
LibraryFunctionLoad[$library, "socketGetPort", {{Integer, 1}}, Integer];


socketGetHost::usage =
"socketGetHost[socketObject] -> host.";


socketGetHost =
LibraryFunctionLoad[$library, "socketGetHost", {{Integer, 1}}, String];


socketListen::usage =
"socketListen[socketObject, backlog].";


socketListen =
LibraryFunctionLoad[$library, "socketListen", {{Integer, 1, "Shared"}, Integer}, "Void"];


socketConnect::usage =
"socketConnect[socketObject, addressStorage].";


socketConnect =
LibraryFunctionLoad[$library, "socketConnect", {{Integer, 1, "Shared"}, "ByteArray"}, "Void"];


socketAccept::usage =
"socketAccept[listenSocket] -> acceptedSocketObject.";


socketAccept =
LibraryFunctionLoad[$library, "socketAccept", {{Integer, 1}}, {Integer, 1}];


socketRecv::usage =
"socketRecv[socketObject, buffer] -> bufferData.";


socketRecv =
LibraryFunctionLoad[$library, "socketRecv", {{Integer, 1}, {"ByteArray", "Shared"}}, "ByteArray"];


socketRecvFrom::usage =
"socketRecvFrom[socketObject, buffer] -> dataStore.";


socketRecvFrom =
LibraryFunctionLoad[$library, "socketRecvFrom", {{Integer, 1}, {"ByteArray", "Shared"}}, "DataStore"];


socketSend::usage =
"socketSend[socketObject, data, length] -> sentLength.";


socketSend =
LibraryFunctionLoad[$library, "socketSend", {{Integer, 1}, {"ByteArray", "Shared"}, Integer}, Integer];


socketSendTo::usage =
"socketSendTo[socketObject, host, port, data, length] -> sentLength.";


socketSendTo =
LibraryFunctionLoad[$library, "socketSendTo", {{Integer, 1}, String, Integer, {"ByteArray", "Shared"}, Integer}, Integer];


socketSendToAddressStorage::usage =
"socketSendToAddressStorage[socketObject, addressStorage, data] -> sentLength.";


socketSendToAddressStorage =
LibraryFunctionLoad[$library, "socketSendToAddressStorage", {{Integer, 1}, "ByteArray", {"ByteArray", "Shared"}}, Integer];


socketsCheck::usage =
"socketsCheck[sockets, length] -> validSockets.";


socketsCheck =
LibraryFunctionLoad[$library, "socketsCheck", {{Integer, 2}, Integer}, {Integer, 2}];


socketConnectedQ::usage =
"socketConnectedQ[socketObject] -> False.";


socketConnectedQ =
LibraryFunctionLoad[$library, "socketConnectedQ", {{Integer, 1}}, Alternatives[True, False]];


socketsSelect::usage =
"socketsSelect[sockets, length, timeout, mode] -> readySockets.";


socketsSelect =
LibraryFunctionLoad[$library, "socketsSelect", {{Integer, 2}, Integer, Integer, Integer}, {Integer, 2}];


socketsPoll::usage =
"socketsPoll[socketsTensor, length, timeoutUs, eventsMask] -> resultTensor.";


socketsPoll =
LibraryFunctionLoad[$library, "socketsPoll", {{Integer, 2}, Integer, Integer, Integer}, {Integer, 2}];


test::usage =
"test[] -> result.";


test =
LibraryFunctionLoad[$library, "test", {}, "DataStore"];


End[];


EndPackage[];
