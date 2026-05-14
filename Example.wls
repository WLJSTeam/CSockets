#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName]];


Get["WLJS`CSockets`"];


server = CSocketOpen[8080];


handler = CSocketHandler[]


svg = ExportString[
    Graphics[{Thick, Green, Rectangle[{0, -1}, {2, 1}], Red, Disk[], Blue,
   Circle[{2, 0}], Yellow, Polygon[{{2, 0}, {4, 1}, {4, -1}}], Purple,
   Arrowheads[Large], Arrow[{{4, 3/2}, {0, 3/2}, {0, 0}}], Black,
  Dashed, Line[{{-1, 0}, {4, 0}}]}], "SVG"];


handler["DefaultHandler"] = Function[
    Echo[#Data];
    "HTTP/1.1 200 OK\r\nContent-Type: image/svg+xml\r\nContent-Length: " <> ToString[StringLength[svg]] <> "\r\n\r\n" <> svg
];


SocketListen[server, handler];


While[True,
    Pause[10];
];