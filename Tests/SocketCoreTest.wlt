Needs["MUnit`"];

baseDir = If[$InputFileName === "", Directory[], DirectoryName[$InputFileName, 2]];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];

socketCoreTests = {
  VerificationTest[
   Block[
    {
     calls = {},
     WLJS`CSockets`Private`socketAddressInfoCreate = Function[{host, port, af, socktype, protocol, local}, AppendTo[calls, "address"]; 23],
     WLJS`CSockets`Private`socketCreate = Function[{family, socktype, protocol}, AppendTo[calls, "create"]; 55],
     WLJS`CSockets`Private`socketBind = Function[{socketId, addressInfo}, AppendTo[calls, {"bind", socketId, addressInfo}]; Null],
     WLJS`CSockets`Private`socketListen = Function[{socketId, backlog}, AppendTo[calls, {"listen", socketId, backlog}]; Null],
     WLJS`CSockets`$CSockets = <||>
    },
    With[{server = WLJS`CSockets`CSocketOpen["localhost", 8080]},
     And[
      server["Protocol"] === "TCP",
      server["Scheme"] === "tcp",
      server["DirectionType"] === "Server",
      server["UUID"] === 55,
      KeyExistsQ[WLJS`CSockets`$CSockets, 55],
      calls === {"address", "create", {"bind", 55, 23}, {"listen", 55, WLJS`CSockets`$SOMAXCONN}}
     ]
    ]
   ],
   True,
   TestID -> "open-tcp-server-registers-and-listens"
  ],

  VerificationTest[
   Block[
    {
     calls = {},
     WLJS`CSockets`Private`socketAddressInfoCreate = Function[{host, port, af, socktype, protocol, local}, AppendTo[calls, "address"]; 23],
     WLJS`CSockets`Private`socketCreate = Function[{family, socktype, protocol}, AppendTo[calls, "create"]; 77],
     WLJS`CSockets`Private`socketBind = Function[{socketId, addressInfo}, AppendTo[calls, {"bind", socketId, addressInfo}]; Null],
     WLJS`CSockets`Private`socketListen = Function[{socketId, backlog}, AppendTo[calls, {"listen", socketId, backlog}]; Null],
     WLJS`CSockets`$CSockets = <||>
    },
    With[{server = WLJS`CSockets`CSocketOpen["localhost", 8081, "UDP"]},
     And[
      server["Protocol"] === "UDP",
      server["Scheme"] === "udp",
      server["DirectionType"] === "Server",
      server["UUID"] === 77,
      KeyExistsQ[WLJS`CSockets`$CSockets, 77],
      calls === {"address", "create", {"bind", 77, 23}}
     ]
    ]
   ],
   True,
   TestID -> "open-udp-server-skips-listen"
  ],

  VerificationTest[
   Block[
    {
     calls = {},
     WLJS`CSockets`Private`socketAddressInfoCreate = Function[{host, port, af, socktype, protocol, local}, AppendTo[calls, "address"]; 91],
     WLJS`CSockets`Private`socketCreate = Function[{family, socktype, protocol}, AppendTo[calls, "create"]; 88],
     WLJS`CSockets`Private`socketSetNonBlockingMode = Function[{socketId}, AppendTo[calls, "nonblocking"]; Null],
     WLJS`CSockets`Private`socketSetBlockingMode = Function[{socketId}, AppendTo[calls, "blocking"]; Null],
     WLJS`CSockets`Private`socketConnect = Function[{socketId, addressInfo}, AppendTo[calls, {"connect", socketId, addressInfo}]; Null],
     WLJS`CSockets`$CSockets = <||>
    },
    With[{client = WLJS`CSockets`CSocketConnect["localhost", 8082, "TCP", "Wait" -> False, "Blocking" -> True]},
     And[
      client["Protocol"] === "TCP",
      client["Scheme"] === "tcp",
      client["DirectionType"] === "Client",
      client["UUID"] === 88,
      KeyExistsQ[WLJS`CSockets`$CSockets, 88],
      calls === {"address", "create", "nonblocking", {"connect", 88, 91}, "blocking"}
     ]
    ]
   ],
   True,
   TestID -> "connect-tcp-temporarily-switches-blocking-mode"
  ],

  VerificationTest[
   Block[
    {
     calls = {},
     WLJS`CSockets`Private`socketAddressInfoCreate = Function[{host, port, af, socktype, protocol, local}, AppendTo[calls, "address"]; 93],
     WLJS`CSockets`Private`socketCreate = Function[{family, socktype, protocol}, AppendTo[calls, "create"]; 90],
     WLJS`CSockets`Private`socketSetNonBlockingMode = Function[{socketId}, AppendTo[calls, "nonblocking"]; Null],
     WLJS`CSockets`Private`socketSetBlockingMode = Function[{socketId}, AppendTo[calls, "blocking"]; Null],
     WLJS`CSockets`Private`socketConnect = Function[{socketId, addressInfo}, AppendTo[calls, {"connect", socketId, addressInfo}]; Null],
     WLJS`CSockets`$CSockets = <||>
    },
    With[{client = WLJS`CSockets`CSocketConnect["localhost", 8083, "UDP", "Wait" -> True, "Blocking" -> False]},
     And[
      client["Protocol"] === "UDP",
      client["Scheme"] === "udp",
      client["DirectionType"] === "Client",
      client["UUID"] === 90,
      KeyExistsQ[WLJS`CSockets`$CSockets, 90],
      calls === {"address", "create", "nonblocking", {"connect", 90, 93}}
     ]
    ]
   ],
   True,
   TestID -> "connect-udp-honors-wait-and-blocking-options"
  ],

  VerificationTest[
   Block[
    {
     WLJS`CSockets`Private`socketAddressInfoCreate = Function[{host, port, af, socktype, protocol, local}, 11],
     WLJS`CSockets`Private`socketCreate = Function[{family, socktype, protocol}, 22]
    },
    And[
     Quiet[WLJS`CSockets`CSocketConnect["localhost", 8084, "TCP", "Wait" -> "bad"]] === $Failed,
     Quiet[WLJS`CSockets`CSocketConnect["localhost", 8084, "TCP", "Blocking" -> "bad"]] === $Failed
    ]
   ],
   True,
   TestID -> "connect-rejects-invalid-option-values"
  ],

  VerificationTest[
   Block[
    {WLJS`CSockets`Private`socketGetPort = Function[{socketId}, 4321]},
    With[
     {
      tcpServer = WLJS`CSockets`CSocketObject[17, WLJS`CSockets`$TCPSERVER],
      udpClient = WLJS`CSockets`CSocketObject[18, WLJS`CSockets`$UDPCLIENT]
     },
     And[
      tcpServer["DestinationPort"] === 4321,
      tcpServer["DirectionType"] === "Server",
      tcpServer["Protocol"] === "TCP",
      tcpServer["Scheme"] === "tcp",
      tcpServer["UUID"] === 17,
      tcpServer["InprocQ"] === False,
      udpClient["DirectionType"] === "Client",
      udpClient["Protocol"] === "UDP",
      udpClient["Scheme"] === "udp",
      udpClient["UUID"] === 18
     ]
    ]
   ],
   True,
   TestID -> "socket-object-accessors-derive-public-state"
  ],

  VerificationTest[
   Block[
    {
     WLJS`CSockets`Private`socketClose = Function[{socketId}, socketId],
     socket = WLJS`CSockets`CSocketObject[19, WLJS`CSockets`$TCPSERVER],
     WLJS`CSockets`$CSockets = <|19 -> socket, socket -> socket|>
    },
    Close[socket];
    And[
     KeyExistsQ[WLJS`CSockets`$CSockets, 19] === False,
     KeyExistsQ[WLJS`CSockets`$CSockets, socket] === False
    ]
   ],
   True,
   TestID -> "close-removes-cached-entries"
  ],

  VerificationTest[
   Block[
    {
     WLJS`CSockets`Private`socketSendString = Function[{socketId, text, len}, {socketId, text, len}],
     WLJS`CSockets`Private`socketSend = Function[{socketId, byteArray, len}, {socketId, Length[byteArray], len}],
     WLJS`CSockets`Private`socketRecv = Function[{socketId, buffer, size}, ByteArray[{65, 66, 67}]]
    },
    And[
     WriteString[WLJS`CSockets`CSocketObject[5, WLJS`CSockets`$TCPCLIENT], "hi"] === {5, "hi", 2},
     BinaryWrite[WLJS`CSockets`CSocketObject[5, WLJS`CSockets`$TCPCLIENT], ByteArray[{1, 2, 3}]] === {5, 3, 3},
     WLJS`CSockets`SocketReadMessage[WLJS`CSockets`CSocketObject[5, WLJS`CSockets`$TCPSERVER]] === ByteArray[{65, 66, 67}]
    ]
   ],
   True,
   TestID -> "socket-io-delegates-to-native-functions"
  ]
};

TestReport[socketCoreTests]
