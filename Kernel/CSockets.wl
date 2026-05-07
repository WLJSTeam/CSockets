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
    
    Echo @ Internal`CreateAsynchronousTask[
    	createSocketsSelectLoop,
		{socketList[[1]], usecInterval}, 
		socketsSelectLoopHandler[handler, socketId, socketList, buffer, bufferSize]
	];
];


CSocketList[initialSockets : {__Integer}] :=
Module[{socketListId = socketListCreate[initialSockets, Length[initialSockets]]},
    CSocketList[socketListId]
];


socketsSelectLoopHandler[handler_, socketId_Integer, CSocketList[socketListId_Integer], buffer_Integer, bufferSize_Integer] :=
Function[
    PreemptProtect @ Module[{accepted},
        With[{
            task = #1, 
            eventName = #2, 
            readySockets = Flatten[{#3}]
        }, 
            Echo[task];
            Echo[readySockets];

            Echo[socketListGetAll[socketListId]];

            Table[
                If[s === socketId,
                    accepted = socketAccept[s];
                    socketListAdd[socketListId, accepted];
                    Echo["Accepting new connection... " <> ToString[accepted]];,
                (*Else*)
                    Echo[socketRecv[s, buffer, bufferSize]];
                ];, 
                {s, readySockets}
            ];

            Echo["Select loop triggered..."];
        ]
    ]
];


End[];


EndPackage[];
