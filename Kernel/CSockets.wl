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
    "Wait" -> False
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
    wait = OptionValue["Wait"]
},
    If[!wait,
        socketSetBlockingMode[socketId, False]
    ];

    socketConnect[socketId, addressInfo];

    If[!wait,
        socketSetBlockingMode[socketId, True]
    ];

    (*Return*)
    CSocketObject[socketId]
];


CSocketClose[CSocketObject[socketId_Integer]] :=
socketClose[socketId];


CSocketObject /: WriteString[CSocketObject[socketId_Integer], message_String] :=
socketWriteString


End[];


EndPackage[];