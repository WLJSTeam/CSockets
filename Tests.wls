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


FileProvider[socket_Integer, bytes_ByteArray] :=
Module[{body, file, response, contenct, path}, 
    body = ByteArrayToString[bytes];
    path = StringSplit[StringSplit[body, "\r\n"][[1]], " "][[2]];
    file = URLParse[path, "Path"];
    content = ReadByteArray[FileNameJoin[Flatten[{DirectoryName[$InputFileName], file}]]];
    response = "HTTP/1.1 200 OK\r\nContent-Length: " <> ToString[ByteArrayLength[content]] <> "\r\n\r\n";
    WLJS`CSockets`Library`socketSendString[socket, response, StringLength[response]];
    WLJS`CSockets`Library`socketSend[socket, content, ByteArrayLength[content]];
];


While[True,
    Pause[10];
];
