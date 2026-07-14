#!/usr/bin/env wolframscript

Map[PacletDirectoryLoad[FileNameJoin[{$HomeDirectory, "Projects", #}]]&] @ {
    "CSockets",
    "Internal"
};


Get["WLJS`CSockets`"];
Get["WLJS`Internal`Console`"];


port = First @ SequenceCases[#, {"-p" | "--port", port_} :> ToExpression[port]]& @ $ScriptCommandLine;


server = CSocketOpen[port];


svg = ExportString[Graphics[{Red, Disk[{0, 0}, 0.5], Blue, Thick,Circle[{0, 0}, 0.75]}], "SVG"];


handler = CSocketHandler["Received" -> Function[
    ConsoleEcho["RECEIVED"][#Data];
    "HTTP/1.1 200 OK\r\nContent-Type: image/svg+xml\r\nContent-Length: " <> ToString[StringLength[svg]] <> "\r\n\r\n" <> svg
]];


SocketListen[server, handler];


UsingFrontEnd[SystemOpen["http://localhost:" <> ToString[port]]];


While[True,
    Pause[10];
];