#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


udpEcho[packet_Association] :=
With[{address = packet["AddressStorage"]},
    Print[
        address["Host"], ":", address["Port"],
        " received ", Length[packet["DataByteArray"]], " bytes"
    ];
    packet["DataByteArray"]
];


server = CSocketOpen["127.0.0.1", 8080, "UDP"];


If[server === $Failed, Exit[1]];


handler = CSocketHandler["ReceivedFrom" -> udpEcho];


listener = SocketListen[server, handler];


Print["UDP echo server listening on ", server["Host"], ":", server["DestinationPort"]];


CheckAbort[
    While[True, Pause[1]],
    Null
];


RemoveAsynchronousTask[listener];


Close[server];
