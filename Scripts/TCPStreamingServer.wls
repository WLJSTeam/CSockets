#!/usr/bin/env wolframscript

PacletDirectoryLoad[FileNameJoin[{$HomeDirectory, "Projects", #}]]& /@ {"CSockets", "Internal"};


port = First @ SequenceCases[$ScriptCommandLine, {"-p" | "--port", port_} :> ToExpression[port]];


Get["WLJS`CSockets`"];


Get["WLJS`Internal`Console`"];


serverSocket = CSocketOpen[port];


handler = CSocketHandler[
    "Accepted" -> broadcastData,
    "Received" -> setNewParameters,
    "Closed" -> Function[$sockets = DeleteCases[$sockets, #ClosedSocket]],
    "Error" -> Function[$sockets = DeleteCases[$sockets, #ErrorSocket]]
];


broadcastData = ConsoleEcho["Accept"][
    $sockets = Append[$sockets, #AcceptedSocket];
    #
]&;


setNewParameters = ConsoleEcho["Receive"][#]&;


$T = 300.0;


SocketListen[serverSocket, handler];


$sockets = {};


serve = Function[
    Table[
        WriteString[socket, StringTemplate["REPORT: T=`1`\n"][$T]],
        {socket, $sockets}
    ]
];


While[True, Pause[1]; serve[]];