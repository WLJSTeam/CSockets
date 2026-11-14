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


(*SocketWaitNext::overrirde*)


(*SocketWaitNext[socketList, timeout=10^10]*)


(*SocketWaitAll::overrirde*)


(*SocketWaitAll[socketList, timeout=10^10]*)


(*SocketReadyQ::overrirde*)


(*SocketReadyQ[socketObject, timeout=10^10]*)


(*Close::overrirde*)


(*Close[socketObject]*)


(*DeleteObject::overrirde*)


(*DeleteObject[socketListener]*)


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
    addressStorage = Quiet[Check[
        socketAddressStorageCreate[
            host, ToString[port],
            $AFINET,
            protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
            $IPPROTOAUTO, ""
        ],
        $Failed
    ]]
},
    If[!MatchQ[addressStorage, _ByteArray],
        Message[CSocketOpen::open, host, port, protocol, "address resolution"];
        Return[$Failed]
    ];

    With[{
        socketObject = Quiet[Check[
            socketCreate[
                $AFINET,
                protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
                $IPPROTOAUTO
            ],
            $Failed
        ]]
    },
        If[!MatchQ[socketObject, {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}],
            Message[CSocketOpen::open, host, port, protocol, "socket creation"];
            Return[$Failed]
        ];

        If[Quiet[Check[socketBind[socketObject, addressStorage], $Failed]] =!= Null,
            Quiet[socketClose[socketObject]];
            Message[CSocketOpen::open, host, port, protocol, "bind"];
            Return[$Failed]
        ];

        If[protocol === "TCP" && Quiet[Check[socketListen[socketObject, $SOMAXCONN], $Failed]] =!= Null,
            Quiet[socketClose[socketObject]];
            Message[CSocketOpen::open, host, port, protocol, "listen"];
            Return[$Failed]
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
        addressStorage = Quiet[Check[
            socketAddressStorageCreate[
                host, ToString[port],
                $AFINET,
                protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
                $IPPROTOAUTO, ""
            ],
            $Failed
        ]]
    },
        If[!MatchQ[addressStorage, _ByteArray],
            Message[CSocketConnect::connect, host, port, protocol, "address resolution"];
            Return[$Failed]
        ];

        With[{
            socketObject = Quiet[Check[
                socketCreate[
                    $AFINET,
                    protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
                    $IPPROTOAUTO
                ],
                $Failed
            ]]
        },
            If[!MatchQ[socketObject, {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}],
                Message[CSocketConnect::connect, host, port, protocol, "socket creation"];
                Return[$Failed]
            ];

            If[(!blocking || !wait) && Quiet[Check[socketSetNonBlockingMode[socketObject], $Failed]] =!= Null,
                Quiet[socketClose[socketObject]];
                Message[CSocketConnect::connect, host, port, protocol, "setting nonblocking mode"];
                Return[$Failed]
            ];

            If[Quiet[Check[socketConnect[socketObject, addressStorage], $Failed]] =!= Null,
                Quiet[socketClose[socketObject]];
                Message[CSocketConnect::connect, host, port, protocol, "connect"];
                Return[$Failed]
            ];

            If[!wait && blocking && Quiet[Check[socketSetBlockingMode[socketObject], $Failed]] =!= Null,
                Quiet[socketClose[socketObject]];
                Message[CSocketConnect::connect, host, port, protocol, "restoring blocking mode"];
                Return[$Failed]
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


CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}]["Host"] :=
socketGetHost[socketData];



CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}]["DestinationPort"] :=
socketGetPort[socketData];


CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}]["DirectionType"] :=
If[socketData[[4]] === 1, "Server", "Client"];


CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}]["InprocQ"] :=
False;


CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}]["Protocol"] :=
If[socketData[[3]] === $SOCKDGRAM, "UDP", "TCP"];


CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}]["Scheme"] :=
If[socketData[[3]] === $SOCKDGRAM, "udp", "tcp"];


CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}]["UUID"] :=
First[socketData];


CSocketObject /: Close[CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}]] :=
Module[{
    id = First[socketData],
    object = CSocketObject[socketData],
    result
},
    result = socketClose[socketData];
    If[result === Null,
        KeyDropFrom[$CSockets, {id, object}]
    ];
    result
];


CSocketObject /: WriteString[
    CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}],
    text_String
] :=
socketSendString[socketData, text];


CSocketObject /: BinaryWrite[
    CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}],
    bytes_ByteArray
] :=
socketSend[socketData, bytes, Length[bytes]];


CSocketObject /: SocketReadyQ[
    CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}],
    t_: 0
] :=
Module[{events},
    If[socketData[[5]] === 0 || socketsCheck[{socketData}, 1] === {}, Return[$Failed]];
    events = socketsPoll[{socketData}, 1, Round[t * 10 ^ 6], $POLLIN];
    If[!ListQ[events], Return[$Failed]];
    Length[events] > 0 && BitAnd[events[[1, 7]], $POLLIN] != 0
];


CSocketObject /: SocketReadMessage[
    CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}]
] :=
With[{buffer = ByteArray[ConstantArray[0, 64 * 1024]]},
    socketRecv[socketData, buffer, Length[buffer]]
];


If[Not[ListQ[$ListenCSockets]], $ListenCSockets = {}];


CSocketList[initialSockets: {__CSocketObject}] :=
Module[{socketListId = socketListCreate[], socketList},
    socketList = CSocketList[socketListId];
    Scan[Append[socketList, #]&, initialSockets];
    socketList
];


CSocketObject /: SocketWaitNext[
    CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}]
] :=
socketsSelect[{socketData}, 1, 2 ^ 10, 1];


CSocketList /: Append[
    CSocketList[socketListId_Integer],
    CSocketObject[socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}]
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
    {socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}, data___}
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
    listenData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer},
    acceptedData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}
] :=
With[{
    listenSocket = CSocketObject[listenData],
    acceptedSocket = CSocketObject[acceptedData]
},
    $CSockets[First[acceptedData]] = acceptedSocket;
    $CSockets[acceptedSocket] = listenSocket;
    <|"ListenSocket" -> listenSocket, "AcceptedSocket" -> acceptedSocket|>
];


createEventData["Closed", socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}, ___] :=
<|"ClosedSocket" -> CSocketObject[ReplacePart[socketData, 5 -> 0]]|>;


createEventData["Error", socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer}, errorCode_Integer] :=
<|"ErrorSocket" -> CSocketObject[socketData], "ErrorCode" -> errorCode|>;


createEventData[
    "ReceivedFrom",
    socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer},
    address: (_ByteArray | _NumericArray),
    bytes: (_List | _ByteArray | _NumericArray | 0): {}
] :=
Join[createEventData["Received", socketData, bytes], <|"AddressStorage" -> AddressStorage[ByteArray[address]]|>];


createEventData[
    "Received",
    socketData: {_Integer, _Integer, _Integer, _Integer, _Integer, _Integer},
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
Module[{result, eventHandler},
    eventHandler = handler[packet["Event"]];

    If[MemberQ[{handler["Received"], handler["ReceivedFrom"]}, eventHandler],
        result = handler["Serializer"] @ eventHandler[packet];
        sendResponse[handler, packet, result];
        Return[result];
    ];

    eventHandler[packet]
];


getExtendedPacket[handler_CSocketHandler, packet_Association] :=
With[{uuid = packet["SourceSocket"]["UUID"]},
    Module[{
        dataLength,
        last,
        expectedLength,
        storedLength,
        completed,
        buffer
    },
        dataLength = Length[packet["DataByteArray"]];
        buffer = handler["Buffer"]["Lookup", uuid]; (*DataStructure[DynamicArray]*)

        If[!MissingQ[buffer] && buffer["Length"] > 0,
            last = buffer["Part", -1]; (*Association[]*)
            expectedLength = last["ExpectedLength"];
            storedLength = last["StoredLength"];,

        (*Else*)
            expectedLength = conditionApply[handler["Accumulator"]][packet];
            storedLength = 0;
        ];

        completed = storedLength + dataLength >= expectedLength;

        (*Return: Association[]*)
        Join[
            packet,
            <|
                "Completed" -> completed,
                "ExpectedLength" -> expectedLength,
                "StoredLength" -> storedLength + dataLength,
                "DataLength" -> dataLength
            |>
        ]
    ]
];


getMessage[handler_CSocketHandler, extendedPacket_Association] :=
With[{
    buffer = handler["Buffer"]["Lookup", extendedPacket["SourceSocket"]["UUID"]],
    expectedLength = extendedPacket["ExpectedLength"]
},
    If[!MissingQ[buffer] && buffer["Length"] > 0,

        (*Return: _ByteArray*)
        Part[#, 1 ;; expectedLength]& @
        Apply[Join] @
        Append[extendedPacket["DataByteArray"]] @
        buffer["Elements"][[All, "DataByteArray"]],

    (*Else*)

        (*Return: _ByteArray*)
        extendedPacket["DataByteArray"][[1 ;; expectedLength]]
    ]
];


invokeHandler[handler_CSocketHandler, packet_Association] :=
Module[{messageHandler, defaultMessageHandler},
    messageHandler = handler["Received"];

    (*Return: ByteArray[] | _String | Null*)
    conditionApply[messageHandler, defaultMessageHandler][packet]
];


CSocketHandler::cntsnd =
"Can't send result to the client\n `1`";


sendResponse[
    handler_CSocketHandler,
    packet_Association /; KeyExistsQ[packet, "AddressStorage"],
    result: _ByteArray | _String | Null
] :=
sendResponse[handler, packet, result, packet["AddressStorage"][[1]]];


sendResponse[
    _CSocketHandler,
    packet_Association,
    result: _ByteArray | _String | Null,
    addressStorage_ByteArray
] :=
With[{socketObject = packet["SourceSocket"][[1]]},
    Switch[result,
        _String,
            socketSendToAddressStorage[socketObject, addressStorage, StringToByteArray[result]],

        _ByteArray,
            socketSendToAddressStorage[socketObject, addressStorage, result],

        Null,
            Null
    ]
];


sendResponse[handler_CSocketHandler, packet_Association, result: _ByteArray | _String | Null] :=
With[{client = packet["SourceSocket"]},
    Switch[result,
        _String,
            WriteString[client, result],

        _ByteArray,
            BinaryWrite[client, result],

        Null,
            Null
    ]
];


sendResponse[_CSocketHandler, _Association, result_] :=
Message[CSocketHandler::cntsnd, result];


savePacketToBuffer[handler_CSocketHandler, extendedPacket_Association] :=
With[{
    buffer = handler["Buffer"]["Lookup", extendedPacket["SourceSocket"]["UUID"]],
    uuid = extendedPacket["SourceSocket"]["UUID"]
},
    If[!MissingQ[buffer],
        buffer["Append", extendedPacket],
        handler["Buffer"]["Insert", uuid -> CreateDataStructure["DynamicArray", {extendedPacket}]]
    ]
];


clearBuffer[handler_CSocketHandler, packet_Association] :=
With[{buffer = handler["Buffer"]["Lookup", packet["SourceSocket"]["UUID"]]},
    buffer["DropAll"];
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
"socketRecv[socketObject, buffer, bufferSize] -> buffer.";


socketRecv =
LibraryFunctionLoad[$library, "socketRecv", {{Integer, 1}, {"ByteArray", "Shared"}, Integer}, "ByteArray"];


socketRecvFrom::usage =
"socketRecvFrom[socketObject, addressStorage, buffer, bufferSize] -> buffer.";


socketRecvFrom =
LibraryFunctionLoad[$library, "socketRecvFrom", {{Integer, 1}, "ByteArray", {"ByteArray", "Shared"}, Integer}, "ByteArray"];


socketSend::usage =
"socketSend[socketObject, data, length] -> sentLength.";


socketSend =
LibraryFunctionLoad[$library, "socketSend", {{Integer, 1}, {"ByteArray", "Shared"}, Integer}, Integer];


socketSendString::usage =
"socketSendString[socketObject, text] -> sentLength.";


socketSendString =
LibraryFunctionLoad[$library, "socketSendString", {{Integer, 1}, String}, Integer];


socketSendTo::usage =
"socketSendTo[socketObject, host, port, data, length] -> sentLength.";


socketSendTo =
LibraryFunctionLoad[$library, "socketSendTo", {{Integer, 1}, String, Integer, {"ByteArray", "Shared"}, Integer}, Integer];


socketSendToAddressStorage::usage =
"socketSendToAddressStorage[socketObject, addressStorage, data] -> sentLength.";


socketSendToAddressStorage =
LibraryFunctionLoad[$library, "socketSendToAddressStorage", {{Integer, 1}, "ByteArray", {"ByteArray", "Shared"}}, Integer];


socketSendStringTo::usage =
"socketSendStringTo[socketObject, host, port, text] -> sentLength.";


socketSendStringTo =
LibraryFunctionLoad[$library, "socketSendStringTo", {{Integer, 1}, String, Integer, String}, Integer];


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


End[];


EndPackage[];
