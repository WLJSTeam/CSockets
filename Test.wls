#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName]];


Get["WLJS`CSockets`"];


socketId = WLJS`CSockets`Library`socketCreate[SOCKET`AFINET, SOCKET`SOCKSTREAM, SOCKET`IPPROTOAUTO];


Print["socket id: ", socketId];


host = "localhost" (*server host here*)
port = "4578" (*port here*)
gateway = "" (*"169.0.0.1"*)


addressInfo = WLJS`CSockets`Library`socketAddressInfoCreate[host, port, SOCKET`AFINET, SOCKET`SOCKSTREAM, SOCKET`IPPROTOAUTO, gateway];


WLJS`CSockets`Library`socketBind[socketId, addressInfo];


WLJS`CSockets`Library`socketConnect[socketId, addressInfo];


WLJS`CSockets`Library`socketsSelect[{socketId}, 1, 1000, 2];


request = "GET /temp/set/300 HTTP/1.1\r\n";


Print["request: ", request];


WLJS`CSockets`Library`socketSendString[socketId, request, StringLength[request]];


Print["sent!"];


WLJS`CSockets`Library`socketsSelect[{socketId}, 1, 1000, 1];


buffer = WLJS`CSockets`Library`socketBufferCreate[1024];


response = WLJS`CSockets`Library`socketRecv[socketId, buffer, 1024];


Print["response: ", ByteArrayToString[response]];
