#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName]];


Get["WLJS`CSockets`"];
Get["WLJS`CSockets`Handler`"];


server = CSocketOpen[8080];


handler = CSocketHandler[]


handler["DefaultHandler"] = Function[
    Echo[#Data];
    "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\n\r\nHello, World!"
];


SocketListen[server, handler];


While[True,
    Pause[10];
];