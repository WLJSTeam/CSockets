#!/usr/bin/env wolframscript

port = First @ SequenceCases[#, {"-p" | "--port", port_} :> ToExpression[port]]& @ $ScriptCommandLine;


Echo["Starting TCP streaming server on port " <> ToString[port]];


PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


serverSocket = CSocketOpen[port];


handler = CSocketHandler["Accepted" -> broadcastData, "Received" -> setNewParameters]


broadcastData = Echo[
    $sockets = Append[$sockets, #AcceptedSocket];
    #, "Accepted: "
]&;


setNewParameters = Echo[(*change T here*)#, "Received: "]&;


$T = 300.0;


SocketListen[serverSocket, handler];


$sockets = {};


serve = Function[
    Table[
        WriteString[socket, StringTemplate["REPORT: T=`1`\n"][$T]],
        {socket, $sockets}
    ]
]


While[True, Pause[1]; serve[]];