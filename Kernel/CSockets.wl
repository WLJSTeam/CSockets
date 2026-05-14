(* ::Package:: *)

BeginPackage["WLJS`CSockets`", {
    "WLJS`CSockets`Constants`",
    "WLJS`CSockets`Library`"
}];


CSocketOpen::usage =
"CSocketOpen[host, port, protocol]";


CSocketClose::usage =
"CSocketClose[socket]";


CSocketConnect::usage =
"CSocketOpen[host, port, protocol]";


CSocketObject::usage =
"CSocketObject[id]";


CSocketList::usage =
"CSocketList[{socketId1, socketId2, ...}]";


Begin["`Private`"];


CSocketOpen[host_String: "localhost", port_Integer, protocol: "TCP" | "UDP": "TCP"] :=
Module[{
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
    If[protocol == "TCP", socketListen[socketId, SOCKET`SOMAXCONN]];

    (*Return*)
    CSocketObject[socketId]
];


Options[CSocketConnect] = {
    "Wait" -> False,
    "Blocking" -> True
};


CSocketConnect[host_String: "localhost", port_Integer, protocol: "TCP" | "UDP": "TCP", OptionsPattern[]] :=
With[{
    addressInfo = socketAddressInfoCreate[host, ToString[port],
        SOCKET`AFINET,
        protocol /. {"TCP" -> SOCKET`SOCKSTREAM, "UDP" -> SOCKET`SOCKDGRAM},
        SOCKET`IPPROTOAUTO
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
    CSocketObject[socketId]
];


CSocketClose[CSocketObject[socketId_Integer]] :=
socketClose[socketId];


CSocketObject /: Close[socketObject_CSocketObject] :=
CSocketClose[socketObject];


CSocketObject /: WriteString[CSocketObject[socketId_Integer], message_String] :=
socketSendString[socketId, message, StringLength[message]];

CSocketObject /: BinaryWrite[CSocketObject[socketId_Integer], byteArray_ByteArray] :=
socketSend[socketId, byteArray, Length[byteArray]];


CSocketObject /: SocketReadyQ[CSocketObject[socketId_Integer]] :=
socketsPoll[{socketId}, 1, 10^6, BitOr[SOCKET`POLLIN, SOCKET`POLLERR, SOCKET`POLLHUP, SOCKET`POLLNVAL]];


CSocketList[initialSockets : {__Integer}] :=
Module[{socketListId = socketListCreate[initialSockets, Length[initialSockets]]},
    CSocketList[socketListId]
];


CSocketList /: Append[CSocketList[socketListId_Integer], CSocketObject[socketId_Integer]] :=
socketListAdd[socketListId, socketId];


CSocketList /: DeleteMissing[CSocketList[socketListId_Integer]] :=
socketListClear[socketListId];


CSocketObject /: SocketListen[serverSocket: CSocketObject[serverSocketId_Integer], handler_] :=
Module[{
    backlog = SOCKET`SOMAXCONN,
    socketList = CSocketList[{serverSocketId}],
    usecInterval = 10 * 10^6,
    bufferSize = 64 * 1024,
    buffer = socketBufferCreate[64 * 1024]
},
    socketListen[serverSocketId, backlog];

    Internal`CreateAsynchronousTask[
        createSocketsSelectLoop,
        {socketList[[1]], usecInterval},
        handleSelectLoopEvent[handler, serverSocket, socketList, buffer, bufferSize]
    ]
];


handleSelectLoopEvent[
    handler_,
    serverSocket: CSocketObject[serverSocketId_Integer],
    socketList: CSocketList[socketListId_Integer],
    buffer_Integer,
    bufferSize_Integer] :=
Function[With[{task = #1, eventName = #2, event = #3[[1]], data = #3[[2]]},
    PreemptProtect @ Switch[eventName,
        "Selected", Table[
            If[socketId === serverSocketId,
                With[{acceptedSocketId = socketAccept[socketId], time = Now},
                    handler @ <|
                        "Event" :> "Accepted",
                        "Timestamp" :> time,
                        "Socket" :> serverSocket,
                        "SourceSocket" :> CSocketObject[acceptedSocketId],
                        "Data" :> socketList
                    |>
                ],
            (*Else*)
                With[{byteArray = socketRecv[socketId, buffer, bufferSize], time = Now, sourceSocket = socketId},
                    If[Head[byteArray] === LibraryFunctionError,
                        handler @ <|
                            "Event" :> "Closed",
                            "Timestamp" :> time,
                            "Socket" :> serverSocket,
                            "SourceSocket" :> CSocketObject[sourceSocket],
                            "Data" :> socketList
                        |>,
                    (*Else*)
                        handler @ <|
                            "Event" :> "Received",
                            "Timestamp" :> time,
                            "Socket" :> serverSocket,
                            "SourceSocket" :> CSocketObject[sourceSocket],
                            "Data" :> ByteArrayToString[byteArray],
                            "DataByteArray" :> byteArray,
                            "Bytes" :> Normal[byteArray],
                            "MultipartComplete" :> True
                        |>
                    ]
                ]
            ],
            {socketId, data}
        ],

        "SelectError", With[{time = Now},
            handler @ <|
                "Event" :> "SelectError",
                "Timestamp" :> time,
                "Socket" :> serverSocket,
                "SourceSocket" :> socketList,
                "Data" :> data
            |>
        ]
    ];

    (*Unfreeze select loop on the c-side*)
    signalEvent[event]]
];


End[];


EndPackage[];