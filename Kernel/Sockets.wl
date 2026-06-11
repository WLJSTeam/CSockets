(* ::Package:: *)

BeginPackage["WLJS`CSockets`Sockets`", {
    "WLJS`CSockets`Constants`",
    "WLJS`CSockets`Library`"
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
Module[{internalType = If[protocol === "TCP", 1, 2],
    addressInfo = socketAddressInfoCreate[host, ToString[port],
        SOCKET`AFINET,
        protocol /. {"TCP" -> SOCKET`SOCKSTREAM, "UDP" -> SOCKET`SOCKDGRAM},
        SOCKET`IPPROTOAUTO, ""
    ],
    socketId = socketCreate[
        SOCKET`AFINET,
        protocol /. {"TCP" -> SOCKET`SOCKSTREAM, "UDP" -> SOCKET`SOCKDGRAM},
        SOCKET`IPPROTOAUTO
    ]
},
    socketBind[socketId, addressInfo];

    If[protocol == "TCP",
        socketListen[socketId, SOCKET`SOMAXCONN]
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
    internalType = If[protocol == "TCP", 3, 4],
    addressInfo = socketAddressInfoCreate[host, ToString[port],
        SOCKET`AFINET,
        protocol /. {"TCP" -> SOCKET`SOCKSTREAM, "UDP" -> SOCKET`SOCKDGRAM},
        SOCKET`IPPROTOAUTO,
        ""
    ],
    socketId = socketCreate[
        SOCKET`AFINET,
        protocol /. {"TCP" -> SOCKET`SOCKSTREAM, "UDP" -> SOCKET`SOCKDGRAM},
        SOCKET`IPPROTOAUTO
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
        socketsPoll[{socketId}, 1, Round[t * 10^6], SOCKET`POLLIN] === {{socketId, 1}}
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


CSocketList /: Append[CSocketList[socketListId_Integer], CSocketObject[socketId_Integer, internalType_Integer]] :=
socketListAdd[socketListId, socketId];


CSocketList /: DeleteMissing[CSocketList[socketListId_Integer]] :=
socketListClear[socketListId];


CSocketList /: Delete[CSocketList[socketListId_Integer], CSocketObject[socketId_Integer, internalType_Integer]] :=
socketListDelete[socketListId, socketId];


CSocketObject /: SocketListen[serverSocket_CSocketObject, handler_] :=
Module[{
    socketList = CSocketList[{serverSocket}],
    bufferSize = 8 * 1024,
    usecInterval = 10 * 10^6,
    eventMask = SOCKET`POLLIN
},
    Echo @ Internal`CreateAsynchronousTask[
        createSocketsPollLoop,
        {socketList[[1]], bufferSize, usecInterval, eventMask},
        handler[createEvent[serverSocket, socketList, ##]]&
    ]
];


createEvent[serverSocket_, socketList_, task_, eventName_, {socketId_, socketType_, data__}] :=
With[{eventData = createEventData[eventName, data]},
    Join[<|
        "Timestamp" -> Now,
        "MultipartComplete" -> True,
        "Task" -> task,
        "Event" -> eventName,
        "Socket" -> serverSocket,
        "SocketList" -> socketList,
        "SourceSocket" -> CSocketObject[socketId, socketType]
    |>, eventData]
];


createEventData["Accepted", data__] :=
<|"AcceptedSocket" -> CSocketObject[data]|>


createEventData["Closed", data__] :=
<|"ClosedSocket" -> CSocketObject[data]|>


createEventData["Error", data_] :=
<|"ErrorCode" -> data|>


createEventData["Received", data_] :=
With[{byteArray = ByteArray[data]},
    <|
        "Data" :> ByteArrayToString[byteArray],
        "DataBytes" :> Normal[byteArray],
        "DataByteArray" :> byteArray
    |>
];


End[];


EndPackage[];