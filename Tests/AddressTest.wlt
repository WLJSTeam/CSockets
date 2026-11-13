Needs["MUnit`"];

baseDir = If[$InputFileName === "", Directory[], DirectoryName[$InputFileName, 2]];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];

TestReport[
 {
  VerificationTest[
   Block[
    {
     WLJS`CSockets`Private`socketAddressInfoCreate = Function[{host, port, af, socktype, protocol, local}, 23],
     WLJS`CSockets`Private`socketCreate = Function[{family, socktype, protocol}, 55],
     WLJS`CSockets`Private`socketBind = Function[{socketId, addressInfo}, Null],
     WLJS`CSockets`Private`socketListen = Function[{socketId, backlog}, Null],
     WLJS`CSockets`$CSockets = <||>
    },
    With[{server = WLJS`CSockets`CSocketOpen["localhost", 8080]},
     And[
      server["Protocol"] === "TCP",
      server["Scheme"] === "tcp",
      server["DirectionType"] === "Server",
      server["UUID"] === 55,
      KeyExistsQ[WLJS`CSockets`$CSockets, 55]
     ]
    ]
   ],
   True,
   TestID -> "open-registers-tcp-server"
  ],

  VerificationTest[
   Block[
    {
     calls = {},
     WLJS`CSockets`Private`socketAddressInfoCreate = Function[{host, port, af, socktype, protocol, local}, AppendTo[calls, "address"]; 77],
     WLJS`CSockets`Private`socketCreate = Function[{family, socktype, protocol}, AppendTo[calls, "create"]; 88],
     WLJS`CSockets`Private`socketSetNonBlockingMode = Function[{socketId}, AppendTo[calls, "nonblocking"]; Null],
     WLJS`CSockets`Private`socketSetBlockingMode = Function[{socketId}, AppendTo[calls, "blocking"]; Null],
     WLJS`CSockets`Private`socketConnect = Function[{socketId, addressInfo}, AppendTo[calls, {"connect", socketId, addressInfo}]; Null],
     WLJS`CSockets`$CSockets = <||>
    },
    With[{client = WLJS`CSockets`CSocketConnect["localhost", 8081, "TCP", "Wait" -> False, "Blocking" -> True]},
     And[
      client["Protocol"] === "TCP",
      client["Scheme"] === "tcp",
      client["DirectionType"] === "Client",
      client["UUID"] === 88,
      KeyExistsQ[WLJS`CSockets`$CSockets, 88],
      calls === {"address", "create", "nonblocking", {"connect", 88, 77}, "blocking"}
     ]
    ]
   ],
   True,
   TestID -> "connect-uses-nonblocking-temporary-mode"
  ],

  VerificationTest[
   Lookup[WLJS`CSockets`Private`createEventData["Accepted", 10, 1, 20, 3], "AcceptedSocket"] ===
    WLJS`CSockets`CSocketObject[20, 3],
   True,
   TestID -> "accepted-event-structure"
  ],

  VerificationTest[
   Lookup[WLJS`CSockets`Private`createEventData["Closed", 1, 2, Null], "ClosedSocket"] ===
    WLJS`CSockets`CSocketObject[1, 2],
   True,
   TestID -> "closed-event-structure"
  ],

  VerificationTest[
   Module[{handler = WLJS`CSockets`CSocketHandler[]},
    And[
     handler["Logger"][42] === 42,
     handler["Accumulator"][<|"DataByteArray" -> ByteArray[{1, 2, 3, 4}]|>] === 4
    ]
   ],
   True,
   TestID -> "handler-default-options"
  ],

  VerificationTest[
   Module[{handler = WLJS`CSockets`CSocketHandler[], packet, extendedPacket},
    handler["Buffer"] = CreateDataStructure["HashTable"];
    packet = <|
      "SourceSocket" -> WLJS`CSockets`CSocketObject[7, WLJS`CSockets`$TCPSERVER],
      "DataByteArray" -> ByteArray[{65, 66, 67}]
    |>;
    extendedPacket = WLJS`CSockets`Private`getExtendedPacket[handler, packet];
    And[
     extendedPacket["Completed"] === True,
     extendedPacket["ExpectedLength"] === 3,
     extendedPacket["StoredLength"] === 3,
     extendedPacket["DataLength"] === 3
    ]
   ],
   True,
   TestID -> "extended-packet-calculation"
  ],

  VerificationTest[
   With[
    {event = WLJS`CSockets`Private`createEventData["ReceivedFrom", 7, WLJS`CSockets`$UDPCLIENT, ByteArray[{1, 2, 3}]]},
    Lookup[event, "AddressObject"] === WLJS`CSockets`AddressObject[ByteArray[{1, 2, 3}]]
   ],
   True,
   TestID -> "receivedfrom-address-object"
  ],

  VerificationTest[
   Block[
    {WLJS`CSockets`Private`socketsCheck = Function[{sockets, length}, sockets],
     WLJS`CSockets`Private`socketIsConnected = Function[{id}, True],
     WLJS`CSockets`Private`socketsPoll = Function[{sockets, length, timeout, mask}, {{1, 1}}]}
    , WLJS`CSockets`SocketReadyQ[WLJS`CSockets`CSocketObject[1, WLJS`CSockets`$TCPSERVER], 0.25]
   ],
   True,
   TestID -> "socket-readyq-ready"
  ],

  VerificationTest[
   Block[
    {WLJS`CSockets`Private`socketClose = Function[{id}, id],
     socket = WLJS`CSockets`CSocketObject[17, WLJS`CSockets`$TCPSERVER],
     WLJS`CSockets`$CSockets = <|17 -> socket, socket -> socket|>}
    , Close[socket];
    And[
     KeyExistsQ[WLJS`CSockets`$CSockets, 17] === False,
     KeyExistsQ[WLJS`CSockets`$CSockets, socket] === False
    ]
   ],
   True,
   TestID -> "close-removes-cached-entries"
  ],

  VerificationTest[
   Block[
    {calls = {},
     WLJS`CSockets`Private`socketListCreate = Function[{}, AppendTo[calls, {"list"}]; 99],
     WLJS`CSockets`Private`socketListAdd = Function[{list, socket}, AppendTo[calls, {"add", list, socket}]; Null],
     WLJS`CSockets`Private`createSocketsPollLoop = Function[{socketListId, bufferSize, timeout, eventMask}, AppendTo[calls, {"loop", socketListId, bufferSize, timeout, eventMask}]; 123],
     Internal`CreateAsynchronousTask = Function[{f, args, handler}, AppendTo[calls, {"task", f, args}]; 456]}
    , And[
     WLJS`CSockets`SocketListen[WLJS`CSockets`CSocketObject[7, WLJS`CSockets`$TCPSERVER], Function[Null]] === 456,
     calls === {{"list"}, {"add", 99, 7}, {"task", Function[{socketListId, bufferSize, timeout, eventMask}, AppendTo[calls, {"loop", socketListId, bufferSize, timeout, eventMask}]; 123], {99, 8192, 1000000, 1}}}
    ]
   ],
   True,
   TestID -> "socket-listen-creates-task"
  ],

  VerificationTest[
   Block[
    {WLJS`CSockets`Private`socketSendString = Function[{id, text, len}, {id, text, len}]}
    , WLJS`CSockets`WriteString[WLJS`CSockets`CSocketObject[5, WLJS`CSockets`$TCPCLIENT], "hi"]
   ],
   {5, "hi", 2},
   TestID -> "write-string-delegates-to-native-send"
  ],

  VerificationTest[
   Block[
    {WLJS`CSockets`Private`socketSend = Function[{id, ba, len}, {id, Length[ba], len}]}
    , WLJS`CSockets`BinaryWrite[WLJS`CSockets`CSocketObject[5, WLJS`CSockets`$TCPCLIENT], ByteArray[{1, 2, 3}]]
   ],
   {5, 3, 3},
   TestID -> "binary-write-delegates-to-native-send"
  ],

  VerificationTest[
   Block[
    {WLJS`CSockets`Private`socketRecv = Function[{id, buffer, size}, ByteArray[{65, 66, 67}]]}
    , WLJS`CSockets`SocketReadMessage[WLJS`CSockets`CSocketObject[5, WLJS`CSockets`$TCPSERVER]]
   ],
   ByteArray[{65, 66, 67}],
   TestID -> "socket-read-message-delegates-to-native-recv"
  ],

  VerificationTest[
   Block[
    {WLJS`CSockets`Private`socketListAdd = Function[{list, socket}, {list, socket}],
     WLJS`CSockets`Private`socketListPrune = Function[{list}, list]}
    , Append[WLJS`CSockets`CSocketList[99], WLJS`CSockets`CSocketObject[7, WLJS`CSockets`$TCPCLIENT]]
   ],
   {99, 7},
   TestID -> "socket-list-append-delegates"
  ],

  VerificationTest[
   Block[
    {WLJS`CSockets`Private`socketListPrune = Function[{list}, list]}
    , DeleteMissing[WLJS`CSockets`CSocketList[99]]
   ],
   99,
   TestID -> "socket-list-delete-missing-delegates"
  ]
 }
]
