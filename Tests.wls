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


Echo[addressInfo];


socketId = WLJS`CSockets`Library`socketCreate[
    SOCKET`AFINET,
    SOCKET`SOCKSTREAM,
    SOCKET`IPPROTOAUTO
];


Echo[socketId];


WLJS`CSockets`Library`socketBind[socketId, addressInfo];


Echo["Socket bound to address..."]l


WLJS`CSockets`Library`socketListen[socketId, 1024];


Echo["Listening on socket..."];
