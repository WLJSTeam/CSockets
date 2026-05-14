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


CSocketSend[SocketObject[socketId_Integer], byteArray_ByteArray] :=
socketSend[socket];


CSocketSendString[SocketObject[socketId_Integer], message_String] :=
socketSend[socket];


CSocketObject /: WriteString[socket_CSocketObject, message_String] :=
CSocketSendString[socketId, message, StringLength[message]];


CSocketObject /: BinaryWrite[socket_CSocketObject, byteArray_ByteArray] :=
CSocketSend[socket, byteArray, Length[byteArray]];


CSocketObject /: SocketReadyQ[CSocketObject[socketId_Integer]] :=
socketsPoll[{socketId}, 1, 10^6, BitOr[SOCKET`POLLIN, SOCKET`POLLERR, SOCKET`POLLHUP, SOCKET`POLLNVAL]];


CSocketList[initialSockets : {__Integer}] :=
Module[{socketListId = socketListCreate[initialSockets, Length[initialSockets]]},
    CSocketList[socketListId]
];


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
        socketsSelectLoopHandler[handler, serverSocket, socketList, buffer, bufferSize]
    ]
];


socketsSelectLoopHandler[
    handler_,
    serverSocket: CSocketObject[serverSocketId_Integer],
    socketList: CSocketList[socketListId_Integer],
    buffer_Integer,
    bufferSize_Integer] :=
Function[
    PreemptProtect @ With[{
        task = #1,
        eventName = #2,
        event = #3[[1]],
        data = #3[[2]]
    },
        Switch[eventName,
            "ReadySockets",
                Table[
                    If[socketId === serverSocketId,
                        With[{time = Now, acceptedSocketId = socketAccept[socketId]},
                            socketListAdd[socketListId, acceptedSocketId];

                            handler @ <|
                                "Event" :> "Accepted",
                                "Timestamp" :> time,
                                "Socket" :> serverSocket,
                                "SourceSocket" :> CSocketObject[acceptedSocketId],
                                "Data" :> socketList
                            |>
                        ],
                    (*Else*)
                        With[{byteArray = socketRecv[socketId, buffer, bufferSize], time = Now},
                            If[Head[byteArray] === LibraryFunctionError,
                                    handler @ <|
                                    "Event" :> "ReceivingError",
                                    "Timestamp" :> time,
                                    "Socket" :> serverSocket,
                                    "SourceSocket" :> CSocketObject[socketId],
                                    "Data" :> socketList
                                |>,
                            (*Else*)
                                handler @ <|
                                    "Event" :> "Received",
                                    "Timestamp" :> time,
                                    "Socket" :> serverSocket,
                                    "SourceSocket" :> CSocketObject[socketId],
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

            "SelectError",
                With[{time = Now},
                    handler @ <|
                    "Event" :> "SelectError",
                    "Timestamp" :> time,
                    "Socket" :> serverSocket,
                    "SourceSocket" :> socketList,
                    "Data" :> data
                |>
            ]
        ];

        signalEvent[event];
    ]
];


End[];


EndPackage[];