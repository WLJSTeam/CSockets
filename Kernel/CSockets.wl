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
    buffer = socketBufferCreate[1024],
    event = createEvent[]
}, 
    socketListen[socketId, backlog];
    
    Internal`CreateAsynchronousTask[
        createSocketsSelectLoop,
        {socketList[[1]], usecInterval, event}, 
        socketsSelectLoopHandler[handler, socketId, socketList, buffer, bufferSize, event]
    ]
];


CSocketList[initialSockets : {__Integer}] :=
Module[{socketListId = socketListCreate[initialSockets, Length[initialSockets]]},
    CSocketList[socketListId]
];


response = "HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\nHello, World!";


socketsSelectLoopHandler[handler_, socketId_Integer, CSocketList[socketListId_Integer], buffer_Integer, bufferSize_Integer, event_Integer] :=
Function[
    Module[{accepted},
        PreemptProtect @ With[{
            task = #1, 
            eventName = #2, 
            readySockets = Flatten[{#3}]
        },
            If[eventName === "ReadySockets",
                Table[
                    If[s === socketId,
                        accepted = socketAccept[s];
                        socketListAdd[socketListId, accepted];,
                    (*Else*)
                        bytes = socketRecv[s, buffer, bufferSize];
                        If[Head[bytes] === LibraryFunctionError,
                            socketClose[s];
                            socketListClear[socketListId];,
                        (*Else*)
                            handler[s, bytes];
                            socketSendString[s, response, StringLength[response]];
                        ];
                    ];, 
                    {s, readySockets}
                ];,
                socketListClear[socketListId];
            ];

            signalEvent[event];
        ]
    ]
];


End[];


EndPackage[];
