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


CSocketObject /: WriteString[CSocketObject[socketId_Integer], message_String] :=
socketSendString[socketId, message, StringLength[message]];


CSocketObject /: BinaryWrite[CSocketObject[socketId_Integer], byteArray_ByteArray] :=
socketSendString[socketId, byteArray, Length[byteArray]];


CSocketObject /: SocketReadyQ[CSocketObject[socketId_Integer]] :=
socketsPoll[{socketId}, 1, 10^6, BitOr[SOCKET`POLLIN, SOCKET`POLLERR, SOCKET`POLLHUP, SOCKET`POLLNVAL]];


CSocketObject /: SocketListen[CSocketObject[socketId_Integer], handler_] :=
Module[{
    backlog = 1024, 
    socketList = CSocketList[{socketId}], 
    usecInterval = 60 * 10^6, 
    bufferSize = 1024,
    buffer = socketBufferCreate[1024]
}, 
    socketListen[socketId, backlog];
    
    Internal`CreateAsynchronousTask[
        createSocketsSelectLoop,
        {socketList[[1]], usecInterval}, 
        socketsSelectLoopHandler[handler, socketId, socketList, buffer, bufferSize]
    ]
];


CSocketList[initialSockets : {__Integer}] :=
Module[{socketListId = socketListCreate[initialSockets, Length[initialSockets]]},
    CSocketList[socketListId]
];


response = "HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\nHello, World!";


socketsSelectLoopHandler[handler_, serverSocketId_Integer, CSocketList[socketListId_Integer], buffer_Integer, bufferSize_Integer] :=
Function[
    Module[{acceptedSocketId, bytes},
        PreemptProtect @ With[{
            task = #1, 
            eventName = #2, 
            event = #3[[1]],
            readySockets = #3[[2]]
        },
            If[eventName === "ReadySockets",
                Table[
                    If[socketId === serverSocketId,
                        acceptedSocketId = socketAccept[socketId];
                        socketListAdd[socketListId, acceptedSocketId];,
                    (*Else*)
                        bytes = socketRecv[socketId, buffer, bufferSize];
                        If[Head[bytes] === LibraryFunctionError,
                            socketClose[socketId];
                            socketListClear[socketListId];,
                        (*Else*)
                            socketSendString[socketId, response, StringLength[response]];
                        ];
                    ];, 
                    {socketId, readySockets}
                ];,
                socketListClear[socketListId];
            ];

            signalEvent[event];
        ]
    ]
];


End[];


EndPackage[];
