#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


HTTPEchoStart[port_Integer] :=
With[{handler = CSocketHandler["DefaultHandler" -> echo]},
    SocketListen[CSocketOpen[port], handler];
]


echo[assoc_Association?AssociationQ] :=
(
    Print[assoc["Data"]];
    StringTemplate["HTTP/1.1 200 OK\r\nContent-Length: `1`\r\nContent-Type: text/plain\r\n\r\n`2`"][StringLength[assoc["Data"]], assoc["Data"]]
);


HTTPEchoStart[8080];
While[True, Pause[1]];