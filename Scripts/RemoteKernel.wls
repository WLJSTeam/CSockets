#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


RemoteKernelStart[port_Integer] :=
With[{handler = CSocketHandler["Received" -> evaluate]},
    SocketListen[CSocketOpen[port], handler];
]


evaluate[assoc_Association?AssociationQ] :=
BinarySerialize @
ReleaseHold @
Echo[#, "CODE TO EVALUATE:"]& @
BinaryDeserialize @
#DataByteArray& @
assoc;


SetAttributes[RemoteKernelEvaluate, HoldRest];


RemoteKernelEvaluate[port_Integer, expr_] :=
Module[{client},
    If[!AssociationQ[$clients], $clients = <||>];
    If[!KeyExistsQ[$clients, port], $clients[port] = CSocketConnect[port]];

    client = $clients[port];
    BinaryWrite[client, #]& @
    BinarySerialize @
    HoldComplete[expr];

    Echo[#, "REMOTE RESULT:"]& @
    BinaryDeserialize @
    SocketReadMessage[client]
];


Switch[$ScriptCommandLine[[-1]],
    "server",
        RemoteKernelStart[8000];
        While[True, Pause[1]],
    "client",
        Echo[$ProcessID, "LOCAL RESULT:"];
        RemoteKernelEvaluate[8000, $ProcessID]
];
