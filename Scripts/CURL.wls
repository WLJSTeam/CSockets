(* ::Package:: *)

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


buffer = ByteArray[ConstantArray[0, 4096]];


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

    socketId = WLJS`CSockets`Private`socketCreate[2, 6]; (* AF_INET, TCP *)
    WLJS`CSockets`Private`socketConnect[socketId,
        FirstCase[HostLookup[host], (IPAddress[ip_String] /; !StringContainsQ[ip, ":"]) :> ip],
        ToString[port]
    ];

    If[WLJS`CSockets`Private`socketsPoll[{socketId}, 10 ^ 5, 2] === {},
        Message[HTTPRequestEvaluate::timeout, absolutePath];
        WLJS`CSockets`Private`socketClose[socketId];
        Return[$Failed];
    ];

    WriteString[CSocketObject[socketId], message];

    If[WLJS`CSockets`Private`socketsPoll[{socketId}, 5 * 10 ^ 6, 1] === {},
        Message[HTTPRequestEvaluate::timeout, absolutePath];
        WLJS`CSockets`Private`socketClose[socketId];
        Return[$Failed];
    ];

    response = ByteArray[{}];

    While[WLJS`CSockets`Private`socketsPoll[{socketId}, 1, 1] =!= {},
        With[{chunk = WLJS`CSockets`Private`socketRecv[socketId, buffer]},
            If[!MatchQ[chunk, _ByteArray] || Length[chunk] === 0, Break[]];
            response = Join[response, chunk]
        ];
    ];

    WLJS`CSockets`Private`socketClose[socketId];

    (*Return*)
    ImportByteArray[response, "HTTPResponse"]
];


