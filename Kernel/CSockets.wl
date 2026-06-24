(* ::Package:: *)

BeginPackage["WLJS`CSockets`", {
    "LibraryLink`",
    "CCompilerDriver`"
}];


CSocketOpen::usage =
"CSocketOpen[host, port, protocol]";


CSocketConnect::usage =
"CSocketConnect[host, port, protocol]";


CSocketObject::usage =
"CSocketObject[id]";


CSocketList::usage =
"CSocketList[{{socketId1, type1}, {socketId2, type2}, ...}]";


Begin["`Private`"];


CSocketOpen[host_String: "localhost", port_Integer, protocol: "TCP" | "UDP": "TCP"] :=
Module[{internalType = If[protocol === "TCP", $TCPSERVER, $UDPSERVER],
    addressInfo = socketAddressInfoCreate[host, ToString[port],
        $AFINET,
        protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
        $IPPROTOAUTO, ""
    ],
    socketId = socketCreate[
        $AFINET,
        protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
        $IPPROTOAUTO
    ]
},
    socketBind[socketId, addressInfo];

    If[protocol == "TCP",
        socketListen[socketId, $SOMAXCONN]
    ];

    (*Return*)
    CSocketObject[socketId, internalType]
];


Options[CSocketConnect] = {
    "Wait" -> False,
    "Blocking" -> True
};


CSocketConnect[host_String: "localhost", port_Integer, protocol: "TCP" | "UDP": "TCP", OptionsPattern[]] :=
With[{
    internalType = If[protocol == "TCP", $TCPCLIENT, $UDPCLIENT],
    addressInfo = socketAddressInfoCreate[host, ToString[port],
        $AFINET,
        protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
        $IPPROTOAUTO,
        ""
    ],
    socketId = socketCreate[
        $AFINET,
        protocol /. {"TCP" -> $SOCKSTREAM, "UDP" -> $SOCKDGRAM},
        $IPPROTOAUTO
    ],
    wait = OptionValue["Wait"],
    blocking = OptionValue["Blocking"]
},
    If[!blocking,
        socketSetNonBlockingMode[socketId]
    ];

    socketBind[socketId, addressInfo];

    If[Not[wait] && blocking,
        socketSetNonBlockingMode[socketId]
    ];

    socketConnect[socketId, addressInfo];

    If[Not[wait] && blocking,
        socketSetBlockingMode[socketId]
    ];

    (*Return*)
    CSocketObject[socketId, internalType]
];


CSocketObject /: Close[CSocketObject[socketId_Integer, internalType_Integer]] :=
socketClose[socketId];


CSocketObject /: WriteString[CSocketObject[socketId_Integer, _], text_String] :=
socketSendString[socketId, text, StringLength[text]];


CSocketObject /: BinaryWrite[CSocketObject[socketId_Integer, internalType_Integer], byteArray_ByteArray] :=
socketSend[socketId, byteArray, Length[byteArray]];


CSocketObject /: SocketReadyQ[CSocketObject[socketId_Integer, _], t_: 0] :=
With[{validSockets = socketsCheck[{socketId}, 1]},
    If[validSockets =!= {socketId} || !socketIsConnected[socketId],
        Return[$Failed],
        socketsPoll[{socketId}, 1, Round[t * 10^6], $POLLIN] === {{socketId, 1}}
    ]
];


With[{bufferSize = 64 * 1024, buffer = socketBufferCreate[64 * 1024]},
    CSocketObject /: SocketReadMessage[CSocketObject[socketId_Integer, _]] :=
    socketRecv[socketId, buffer, bufferSize];
];


CSocketList[initialSockets : {__CSocketObject}] :=
Module[{socketListId = socketListCreate[initialSockets[[All, 1]], initialSockets[[All, 2]], Length[initialSockets]]},
    CSocketList[socketListId]
];


CSocketObject /: SocketWaitNext[CSocketObject[socketId_, socketType_]] :=
socketsSelect[{socketId}, 1, 10^10, 1];


CSocketList /: Append[CSocketList[socketListId_Integer], CSocketObject[socketId_Integer, internalType_Integer]] :=
socketListAdd[socketListId, socketId];


CSocketList /: DeleteMissing[CSocketList[socketListId_Integer]] :=
socketListClear[socketListId];


CSocketList /: Delete[CSocketList[socketListId_Integer], CSocketObject[socketId_Integer, internalType_Integer]] :=
socketListDelete[socketListId, socketId];


CSocketList /: SocketListen[CSocketList[socketListId_Integer], handler_] :=
With[{
    bufferSize = 8 * 1024,
    usecInterval = 10^6,
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


createEvent[task_, eventName_, {socketId_, socketType_, data__}] :=
With[{eventData = createEventData[eventName, socketId, socketType, data]},
    Join[<|
        "Timestamp" -> Now,
        "MultipartComplete" -> True,
        "Task" -> task,
        "Event" -> eventName
    |>, eventData]
];


createEventData["Accepted", listenSocketId_, listenSocketType_, acceptedSocketId_, acceptedSocketType_] :=
With[{
    listenSocket = CSocketObject[listenSocketId, listenSocketType],
    acceptedSocket = CSocketObject[acceptedSocketId, acceptedSocketType]
},
    $csockets[acceptedSocket] = listenSocket;
    <|
        "ListenSocket" ->listenSocket,
        "AcceptedSocket" -> acceptedSocket
    |>
];


createEventData["Closed", closedSocketId_, socketType_, _] :=
<|"ClosedSocket" -> CSocketObject[closedSocketId, socketType]|>;


createEventData["Error", socketId_, socketType_, errorCode_] :=
<|
    "ErrorSocket" -> CSocketObject[socketId, socketType],
    "ErrorCode" -> errorCode
|>;


createEventData["Received", socketId_, socketType_, receivedData_] :=
With[{
    byteArray = ByteArray[receivedData],
    sourceSocket = CSocketObject[socketId, socketType]}, {
    socket = $csockets[sourceSocket]
},
    <|
        "Socket" -> socket,
        "SourceSocket" -> sourceSocket,
        "Data" :> ByteArrayToString[byteArray],
        "DataBytes" :> Normal[byteArray],
        "DataByteArray" :> byteArray
    |>
];


$INTERUPTER = 0;


$TCPSERVER = 1;


$UDPSERVER = 2;


$TCPCLIENT = 3;


$UDPCLIENT = 4


(* Protocol levels *)
$IPPROTOAUTO::usage = "IPPROTOAUTO - auto protocol level";
$IPPROTOAUTO = 0;


$IPPROTOTCP::usage = "IPPROTO_TCP - TCP protocol level";
$IPPROTOTCP = 6;


$IPPROTOUDP::usage = "IPPROTO_UDP - UDP protocol level";
$IPPROTOUDP = 17;


$IPPROTOIPV6::usage = "IPPROTO_IPV6 - IPv6 protocol level";
$IPPROTOIPV6 = If[$OperatingSystem === "Windows", 41, 16^^0029];


(* Socket level - platform dependent *)
$SOL::usage = "SOL_SOCKET - socket-level options";
$SOL = If[$OperatingSystem === "Windows", 16^^FFFF, 1];


(* Socket options (SOL_SOCKET level) *)
$SOKEEPALIVE::usage = "SO_KEEPALIVE - enable keep-alive packets";
$SOKEEPALIVE = 16^^0008;


$SORCVBUF::usage = "SO_RCVBUF - receive buffer size";
$SORCVBUF = 16^^1002;


$SOSNDBUF::usage = "SO_SNDBUF - send buffer size";
$SOSNDBUF = 16^^1001;


$SOLINGER::usage = "SO_LINGER - linger on close";
$SOLINGER = 16^^0080;


$SOBROADCAST::usage = "SO_BROADCAST - permit broadcast messages";
$SOBROADCAST = 16^^0020;


$SOERROR::usage = "SO_ERROR - get pending socket error";
$SOERROR = 16^^1007;


$SOMAXCONN::usage = "SOMAXCONN - maximum backlog for listen()";
$SOMAXCONN = 16^^7FFFFFFF;


$SOTYPE::usage = "SO_TYPE - get socket type (STREAM/DGRAM)";
$SOTYPE = 16^^1008;


$SOACCEPTCONN::usage = "SO_ACCEPTCONN - non-zero if socket is listening";
$SOACCEPTCONN = 16^^0002;


$SOREUSEADDR::usage = "SO_REUSEADDR - reuse local address";
$SOREUSEADDR = If[$OperatingSystem === "Windows", 4, 16^^0002];


(* TCP options (IPPROTO_TCP level) *)
$TCPNODELAY::usage = "TCP_NODELAY - disable Nagle algorithm";
$TCPNODELAY = 16^^0001;


$TCPKEEPIDLE::usage = "TCP_KEEPIDLE - idle time before keep-alive probes";
$TCPKEEPIDLE = If[$OperatingSystem === "MacOSX", 16^^0010, 16^^0004];

$TCPKEEPINTVL::usage = "TCP_KEEPINTVL - interval between keep-alive probes";
$TCPKEEPINTVL = If[$OperatingSystem === "MacOSX", 16^^0011, 16^^0005];

$TCPKEEPCNT::usage = "TCP_KEEPCNT - number of keep-alive probes before drop";
$TCPKEEPCNT = If[$OperatingSystem === "MacOSX", 16^^0012, 16^^0006];


(* IPv4 options (IPPROTO_IP level) *)
$IPTTL::usage = "IP_TTL - time-to-live for packets";
$IPTTL = 16^^0004;


$IPTOS::usage = "IP_TOS - type of service / DSCP";
$IPTOS = 16^^0001;


$IPMTUDISCOVER::usage = "IP_MTU_DISCOVER - path MTU discovery";
$IPMTUDISCOVER = 16^^000A;


(* IPv6 options (IPPROTO_IPV6 level) *)
$IPV6V6ONLY::usage = "IPV6_V6ONLY - restrict socket to IPv6 only";
$IPV6V6ONLY = If[$OperatingSystem === "Windows", 27, 16^^001A];


(* Address families *)
$AFINET::usage = "AF_INET - IPv4 address family";
$AFINET = 16^^0002;


$AFINET6::usage = "AF_INET6 - IPv6 address family";
$AFINET6 = 16^^000A;


(* Socket types *)
$SOCKSTREAM::usage = "SOCK_STREAM - reliable stream socket (TCP)";
$SOCKSTREAM = 16^^0001;


$SOCKDGRAM::usage = "SOCK_DGRAM - datagram socket (UDP)";
$SOCKDGRAM = 16^^0002;


(* Windows-specific *)
$SOEXCLUSIVEADDRUSE::usage = "SO_EXCLUSIVEADDRUSE - exclusive address binding (Windows only)";
$SOEXCLUSIVEADDRUSE = If[$OperatingSystem === "Windows", 16^^0001, -5];


(*unified sockes_poll flags*)


$POLLIN = 16^^0001;


$POLLOUT = 16^^0002;


$POLLERR = 16^^0004;


$POLLHUP  = 16^^0008;


$POLLNVAL = 16^^0010;


If[!AssociationQ[$csockets],
    $csockets = <||>
];


getLibraryLinkVersion[] := getLibraryLinkVersion[] =
Which[
    $VersionNumber >= 14.1,
        With[{n = LibraryVersionInformation[FindLibrary["demo"] ]["WolframLibraryVersion"]},
            If[!NumberQ[n], 7, n]
        ],
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


$library = FileNameJoin[{
    DirectoryName[$InputFileName, 2],
    "LibraryResources",
    $SystemID <> "-v" <> ToString[getLibraryLinkVersion[]],
    "csockets." <> Internal`DynamicLibraryExtension[]
}];


(* :LibraryLoad: *)


End[];


EndPackage[];