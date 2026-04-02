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
With[{
    addressInfo = socketAddressInfoCreate[host, ToString[port],
        SOCKET`AFINET,
        protocol /. {"TCP" -> SOCKET`SOCKSTREAM, "UDP" -> SOCKET`SOCKDGRAM},
        SOCKET`IPPROTOIP
    ],
    socketId = socketCreate[
        SOCKET`AFINET,
        protocol /. {"TCP" -> SOCKET`SOCKSTREAM, "UDP" -> SOCKET`SOCKDGRAM},
        SOCKET`IPPROTOIP
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
        SOCKET`IPPROTOIP
    ],
    socketId = socketCreate[
        SOCKET`AFINET,
        protocol /. {"TCP" -> SOCKET`SOCKSTREAM, "UDP" -> SOCKET`SOCKDGRAM},
        SOCKET`IPPROTOIP
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
socketsPoll[];


End[];


EndPackage[];