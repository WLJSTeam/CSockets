#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


SocketListen[CSocketOpen[8080], (
    Print[#];
    If[KeyExistsQ[#, "Data"],
        Print[#["Data"]];
        WriteString[#SourceSocket, "HTTP/1.1 200 OK\r\nContent-Length: 5\r\nContent-Type: text/plain\r\n\r\nhello"]
    ];
)&];


While[True, Pause[1]];