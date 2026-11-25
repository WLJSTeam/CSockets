#!/usr/bin/env wolframscript

(* Usage: wolframscript -f Scripts/HTTPServer.wls [port]; default: 8080.
    GET/HEAD only, one request per connection. Stop with Ctrl+C. *)


PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


$httpConnections = <||>;


$httpHeaders = <||>;


$httpRunning = True;


httpResponse[status_String, body_String, headOnly: True | False: False] :=
With[{bytes = StringToByteArray[body]},
    Join[
        StringToByteArray[StringRiffle[{
            "HTTP/1.1 " <> status,
            "Content-Type: text/plain; charset=utf-8",
            "Content-Length: " <> ToString[Length[bytes]],
            "Connection: close",
            "Allow: GET, HEAD"
        }, "\r\n"] <> "\r\n\r\n"],
        If[headOnly, ByteArray[{}], bytes]
    ]
];


forgetHTTPConnection[socket: CSocketObject[id_Integer]] :=
(
    KeyDropFrom[$httpHeaders, id];
    KeyDropFrom[$httpConnections, id];
);


receiveHTTPRequest[packet_Association] :=
Module[{
    id = First[packet["SourceSocket"]],
    headers, request, parts, method, target, headOnly
},
    headers = Join[Lookup[$httpHeaders, id, ByteArray[{}]], packet["DataByteArray"]];
    $httpHeaders[id] = headers;

    If[Length[headers] > 16 * 1024,
        Return[httpResponse["431 Request Header Fields Too Large", "Request headers are too large.\n"]]
    ];

    request = ByteArrayToString[headers];
    If[!StringContainsQ[request, "\r\n\r\n"], Return[Null]];

    parts = StringSplit[request, "\r\n"];
    If[parts === {}, Return[httpResponse["400 Bad Request", "Empty HTTP request.\n"]]];

    parts = StringSplit[First[parts], " "];
    If[Length[parts] =!= 3 || !MemberQ[{"HTTP/1.0", "HTTP/1.1"}, Last[parts]],
        Return[httpResponse["400 Bad Request", "Invalid HTTP request line.\n"]]
    ];

    {method, target} = Take[parts, 2];
    If[!MemberQ[{"GET", "HEAD"}, method],
        Return[httpResponse["405 Method Not Allowed", "Use GET or HEAD.\n"]]
    ];

    headOnly = method === "HEAD";
    If[!StringStartsQ[target, "/"],
        Return[httpResponse["400 Bad Request", "Expected a path starting with /.\n", headOnly]]
    ];

    target = First[StringSplit[target, "?", 2]];
    Switch[target,
        "/", httpResponse["200 OK", "Привет! Это HTTP-сервер на CSockets.\n", headOnly],
        "/health", httpResponse["200 OK", "ok\n", headOnly],
        _, httpResponse["404 Not Found", "Not found.\n", headOnly]
    ]
];


finishHTTPResponse[packet_Association] :=
If[packet["Event"] === "Received" && Lookup[packet, "Result", Null] =!= Null,
    (* CSocketHandler calls Logger after sending the response. *)
    Print[
        packet["SourceSocket"]["RemoteAddress"], " - ",
        First[StringSplit[ByteArrayToString[packet["Result"]], "\r\n"]]
    ];
    forgetHTTPConnection[packet["SourceSocket"]];
    Close[packet["SourceSocket"]];
];


handler = CSocketHandler[
    "Received" -> receiveHTTPRequest,
    "Accepted" -> Function[packet,
        With[{socket = packet["AcceptedSocket"]},
            $httpConnections[First[socket]] = socket;
        ]
    ],
    "Closed" -> Function[packet, forgetHTTPConnection[packet["ClosedSocket"]]],
    "Error" -> Function[packet,
        If[!KeyExistsQ[$CSockets, First[packet["ErrorSocket"]]],
            forgetHTTPConnection[packet["ErrorSocket"]]
        ]
    ],
    "Logger" -> finishHTTPResponse
];


arguments = Rest[$ScriptCommandLine];


If[Length[arguments] > 1 || (arguments =!= {} && !StringMatchQ[First[arguments], DigitCharacter..]),
    Print["Usage: wolframscript -f Scripts/HTTPServer.wls [port]"];
    Exit[1]
];


port = If[arguments === {}, 8080, FromDigits[First[arguments]]];


If[port < 0 || port > 65535,
    Print["Port must be between 0 and 65535."];
    Exit[1]
];


server = CSocketOpen["127.0.0.1", port, "TCP"];


If[!MatchQ[server, _CSocketObject], Exit[1]];


listener = SocketListen[server, handler];


If[!MatchQ[listener, _AsynchronousTaskObject],
    Close[server];
    Exit[1]
];


Print["HTTP server listening at ", StringReplace[server["LocalAddress"], "tcp://" -> "http://"], "/"];


CheckAbort[
    While[$httpRunning, Pause[0.1]],
    Null
];


RemoveAsynchronousTask[listener];


(* Allow the native poll call to finish before closing its sockets. *)
Pause[1.1];


Scan[Close, Values[$httpConnections]];


Close[server];


$httpConnections = <||>;


$httpHeaders = <||>;
