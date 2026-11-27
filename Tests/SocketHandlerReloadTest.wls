socketListenOptions = Options[SocketListen];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Begin["WLJS`CSockets`Private`"];


events = {}; checks = {Options[SocketListen] === Global`socketListenOptions};


serverId = createSocket["IPv4", "TCP"];


Catch[
    bind[serverId, "127.0.0.1", 0]
]; Catch[
    listen[serverId]
];


server = CSocketObject[serverId];


task = SocketListen[
    server,
    (
        AppendTo[events, {"old", #}]
    )&
];


clientId = createSocket["IPv4", "TCP"];


Catch[
    connect[
        clientId,
        "127.0.0.1",
        splitAddress[
            server["LocalAddress"]
        ]["Port"]
    ]
];


Do[
    Pause[0.02];
    If[AnyTrue[
            events,
            #[[2]]["Event"] === "Accepted"&
        ],
        Break[]
    ],
    {100}
];


acceptedPacket = SelectFirst[
    events,
    #[[2]]["Event"] === "Accepted"&,
    {"none", <||>}
];


accepted = Lookup[
    acceptedPacket[[2]],
    "AcceptedSocket",
    CSocketObject[-1]
];


AppendTo[
    checks,
    acceptedPacket[[1]] === "old" && accepted["Listener"] === task &&
        acceptedPacket[[2]]["Task"] === task
];


socketSend[
    clientId,
    ByteArray[{1}]
];


Do[
    Pause[0.02];
    If[AnyTrue[
            events,
            #[[2]]["Event"] === "Received"&
        ],
        Break[]
    ],
    {100}
];


AppendTo[
    checks,
    AnyTrue[
        events,
        #[[1]] === "old" && #[[2]]["Task"] === task && Lookup[
            #[[2]],
            "DataBytes",
            {}
        ] === {1}&
    ]
];


newTask = SocketListen[
    server,
    (
        AppendTo[events, {"new", #}]
    )&
];


AppendTo[
    checks,
    newTask === task && server["Listener"] === task
];


AppendTo[
    checks,
    accepted["Handler"] === server["Handler"]
];


socketSend[
    clientId,
    ByteArray[{2}]
];


Do[
    Pause[0.02];
    If[AnyTrue[
            events,
            #[[1]] === "new" && #[[2]]["Task"] === task && Lookup[
                #[[2]],
                "DataBytes",
                {}
            ] === {2}&
        ],
        Break[]
    ],
    {100}
];


AppendTo[
    checks,
    AnyTrue[
        events,
        #[[1]] === "new" && #[[2]]["Task"] === task && Lookup[
            #[[2]],
            "DataBytes",
            {}
        ] === {2}&
    ]
];


client2 = createSocket["IPv4", "TCP"];


Catch[
    connect[
        client2,
        "127.0.0.1",
        splitAddress[
            server["LocalAddress"]
        ]["Port"]
    ]
];


Do[
    Pause[0.02];
    If[AnyTrue[
            events,
            #[[1]] === "new" && #[[2]]["Event"] === "Accepted"&
        ],
        Break[]
    ],
    {100}
];


AppendTo[
    checks,
    AnyTrue[
        events,
        #[[1]] === "new" && #[[2]]["Event"] === "Accepted"&
    ]
];


Catch[
    close[clientId]
]; Catch[
    close[client2]
];


Do[
    Pause[0.02];
    If[Count[
            events,
            {"new", packet_} /; packet["Event"] === "Closed"
        ] >= 2,
        Break[]
    ],
    {100}
];


AppendTo[
    checks,
    Count[
        events,
        {"new", packet_} /; packet["Event"] === "Closed"
    ] === 2
];


RemoveAsynchronousTask[task]; Pause[1.2]; Catch[
    close[serverId]
];


Print[checks]; If[!And @@ checks,
    Exit[1]
];


End[];
