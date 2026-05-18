(* ::Package:: *)

PacletDirectoryLoad[Directory[]];


Get["WLJS`CSockets`"];


buffer = socketBufferCreate[4096];


HTTPRequestEvaluate::invalidURL = "The URL `1` is invalid or not supported.";


HTTPRequestEvaluate::timeout = "The request to `1` timed out.";


HTTPRequestEvaluate[httpRequest_HTTPRequest] := Module[{
    host, port, message = ExportString[httpRequest, "HTTPRequest"], parsedURL, response,
    absolutePath = httpRequest["AbsolutePath"], socketId, addressInfo
},
    parsedURL = URLParse[absolutePath];

    If[parsedURL === $Failed || parsedURL["Scheme"] =!= "http",
        Message[HTTPRequestEvaluate::invalidURL, absolutePath];
        Return[$Failed];
    ];

    host = URLParse[parsedURL]["Domain"];
    port = URLParse[parsedURL]["Port"] /. None -> 80;

    socketId = socketCreate[2, 1, 0]; (* AF_INET, SOCK_STREAM, AUTO *)
    addressInfo = socketAddressInfoCreate[host, ToString[port], 2, 1, 0, ""]; (* AF_INET, SOCK_STREAM, AUTO *)
    socketConnect[socketId, addressInfo];

    If[socketsSelect[{socketId}, 1, 5 * 10^6, 2] =!= {socketId},
        Message[HTTPRequestEvaluate::timeout, absolutePath];
        socketClose[socketId];
        Return[$Failed];
    ];

    socketSendString[socketId, message, StringLength[message]];

    If[socketsSelect[{socketId}, 1, 5 * 10^6, 1] =!= {socketId},
        Message[HTTPRequestEvaluate::timeout, absolutePath];
        socketClose[socketId];
        Return[$Failed];
    ];

    response = ByteArray[{}];

    While[socketsSelect[{socketId}, 1, 0, 1] === {socketId},
        response = Join[response, socketRecv[socketId, buffer, 4096]];
    ];

    socketClose[socketId];
    socketAddressInfoRemove[addressInfo];

    (*Return*)
    ImportByteArray[response, "HTTPResponse"]
];


Print[ExportString[URLRead["http://jsfiddle.net/echo/jsonp/?name=fred&callback=callbackName"], "HTTPResponse"]]


Print["\n\n"]


Print[ExportString[HTTPRequestEvaluate[HTTPRequest["http://jsfiddle.net/echo/jsonp/?name=fred&callback=callbackName"]], "HTTPResponse"]]
