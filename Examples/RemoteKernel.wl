#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


RemoteKernelStart[port_Integer] :=
With[{handler = CSocketHandler["DefaultHandler" -> evaluate]},
    SocketListen[CSocketOpen[port], handler];
]


evaluate[assoc_Association?AssociationQ] :=
BinarySerialize @
ReleaseHold @
Echo @
BinaryDeserialize @
#DataByteArray& @
Echo @
assoc;


RemoteKernelEvaluate[port_Integer, expr_] :=
Module[{client},
    If[!AssociationQ[$clients], $clients = <||>];
    If[!KeyExistsQ[$clients, port], $clients[port] = CSocketConnect[port]];

    client = $clients[port];
    BinaryWrite[client, #]& @
    BinarySerialize @
    HoldComplete[expr];

    If[socketsSelect[{client[[1]]}, 1, 1000, 1] === {client[[1]]},
        buffer = socketBufferCreate[1024];

        Echo @
        BinaryDeserialize @
        socketRecv[client[[1]], buffer, 1024],
        Message[RemoteKernelEvaluate::timeout, port]
    ];
];


Echo[$ScriptCommandLine];


Switch[$ScriptCommandLine[[-1]],
    "server",
        RemoteKernelStart[8000];
        While[True, Pause[1]],
    "client",
        RemoteKernelEvaluate[8000, Hold[1 + 1]]
];