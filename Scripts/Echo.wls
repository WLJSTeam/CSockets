#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


EchoStart[port_Integer] :=
SocketListen[CSocketOpen[port], echo];


echo[assoc_Association?AssociationQ] := (
Print[assoc];
If[KeyExistsQ[assoc, "Data"],
    Print[assoc["Data"]];
    WriteString[assoc["SourceSocket"], assoc["Data"]]
]);


EchoStart[8080];


While[True, Pause[1]];