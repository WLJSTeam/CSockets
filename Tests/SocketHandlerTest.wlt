Needs["MUnit`"];

baseDir = If[$InputFileName === "", Directory[], DirectoryName[$InputFileName, 2]];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];

socketHandlerTests = {
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
   Lookup[WLJS`CSockets`Private`createEventData["Error", 4, 5, 99], "ErrorCode"] === 99,
   True,
   TestID -> "error-event-carries-code"
  ],

  VerificationTest[
   With[
    {event = WLJS`CSockets`Private`createEventData["Received", 7, WLJS`CSockets`$TCPSERVER, {65, 66, 67}]},
    And[
     Lookup[event, "SourceSocket"] === WLJS`CSockets`CSocketObject[7, WLJS`CSockets`$TCPSERVER],
     Lookup[event, "Data"] === "ABC",
     Lookup[event, "DataBytes"] === {65, 66, 67},
     Lookup[event, "DataByteArray"] === ByteArray[{65, 66, 67}]
    ]
   ],
   True,
   TestID -> "received-event-conversion"
  ],

  VerificationTest[
   Module[{handler = WLJS`CSockets`CSocketHandler[]},
    And[
     handler["Logger"][42] === 42,
     handler["Accumulator"][<|"DataByteArray" -> ByteArray[{1, 2, 3, 4}]|>] === 4,
     handler["Serializer"][5] === 5,
     handler["Deserializer"][ByteArray[{65}]] === ByteArray[{65}],
     handler["Received"][<||>] === Null,
     handler["Accepted"][<||>] === Null,
     handler["Closed"][<||>] === Null,
     handler["Error"][<||>] === Null
    ]
   ],
   True,
   TestID -> "handler-default-options"
  ],

  VerificationTest[
   Module[{handler = WLJS`CSockets`CSocketHandler[]},
    And[
     MemberQ[Keys[Options[WLJS`CSockets`CSocketHandler]], "Received"],
     MemberQ[Keys[Options[WLJS`CSockets`CSocketHandler]], "Error"]
    ]
   ],
   True,
   TestID -> "handler-exposes-expected-options"
  ],

  VerificationTest[
   Module[{handler = WLJS`CSockets`CSocketHandler[]},
    handler["Logger"] = "custom";
    handler["Logger"] === "custom"
   ],
   True,
   TestID -> "handler-setter-updates-single-key"
  ],

  VerificationTest[
   Module[{handler = WLJS`CSockets`CSocketHandler[]},
    handler["Logger", "Received"] = "combined";
    handler["Logger", "Received"] === "combined"
   ],
   True,
   TestID -> "handler-setter-updates-nested-key"
  ],

  VerificationTest[
   Module[{handler = WLJS`CSockets`CSocketHandler[]},
    StringContainsQ[ToString[InputForm[handler]], "CSocketHandler"]
   ],
   True,
   TestID -> "handler-format-is-readable"
  ],

  VerificationTest[
   Block[
    {
     WLJS`CSockets`Private`socketSendString = Function[{socketId, text, len}, {"text", socketId, text, len}],
     WLJS`CSockets`Private`socketSend = Function[{socketId, byteArray, len}, {"bytes", socketId, Length[byteArray], len}],
     handler = WLJS`CSockets`CSocketHandler[],
     client = WLJS`CSockets`CSocketObject[33, WLJS`CSockets`$TCPCLIENT]
    },
    And[
     WLJS`CSockets`Private`sendResponse[handler, <|"SourceSocket" -> client|>, "ok"] === {"text", 33, "ok", 2},
     WLJS`CSockets`Private`sendResponse[handler, <|"SourceSocket" -> client|>, ByteArray[{1, 2}]] === {"bytes", 33, 2, 2},
     WLJS`CSockets`Private`sendResponse[handler, <|"SourceSocket" -> client|>, Null] === Null
    ]
   ],
   True,
   TestID -> "handler-response-sends-supported-types"
  ],

  VerificationTest[
   Block[
    {message = WLJS`CSockets`Private`conditionApply[<|True -> Function[x, x + 1], False -> Function[x, x - 1]|>]},
    And[
     message[10] === 11,
     WLJS`CSockets`Private`conditionApply[<||>, Function[Null]][123] === Null
    ]
   ],
   True,
   TestID -> "condition-apply-picks-first-matching-branch"
  ]
};

TestReport[socketHandlerTests]
