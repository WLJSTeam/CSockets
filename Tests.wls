#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName]];


Get["WLJS`CSockets`"];


addressInfo = WLJS`CSockets`Library`socketAddressInfoCreate[
    "localhost",
    "8080",
    SOCKET`AFINET,
    SOCKET`SOCKSTREAM,
    SOCKET`IPPROTOAUTO,
    ""
];


socketId = WLJS`CSockets`Library`socketCreate[
    SOCKET`AFINET,
    SOCKET`SOCKSTREAM,
    SOCKET`IPPROTOAUTO
];


WLJS`CSockets`Library`socketBind[socketId, addressInfo];


WLJS`CSockets`Library`socketListen[socketId, 1024];


SocketListen[CSocketObject[socketId], FileProvider];


FileProvider[assoc_Association] :=
Echo[assoc];


While[True,
    Pause[10];
];
