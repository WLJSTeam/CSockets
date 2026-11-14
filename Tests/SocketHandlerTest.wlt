Needs["MUnit`"];

baseDir = If[$InputFileName === "", Directory[], DirectoryName[$InputFileName, 2]];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];

socketHandlerTests = {
  VerificationTest[
   Lookup[WLJS`CSockets`Private`createEventData["Accepted", {10, 6, 1, 1, 1, 0}, {20, 6, 1, 3, 1, 0}], "AcceptedSocket"] ===
    WLJS`CSockets`CSocketObject[{20, 6, 1, 3, 1, 0}],
   True,
   TestID -> "accepted-event-structure"
  ],

  VerificationTest[
   Lookup[WLJS`CSockets`Private`createEventData["Closed", {1, 17, 2, 1, 0, 0}, Null], "ClosedSocket"] ===
    WLJS`CSockets`CSocketObject[{1, 17, 2, 1, 0, 0}],
   True,
   TestID -> "closed-event-structure"
  ],

  VerificationTest[
   Lookup[WLJS`CSockets`Private`createEventData["Error", {4, 6, 1, 3, 1, 0}, 99], "ErrorCode"] === 99,
   True,
   TestID -> "error-event-carries-code"
  ],

  VerificationTest[
   With[
    {event = WLJS`CSockets`Private`createEventData["ReceivedFrom", {7, 17, 2, 2, 1, 0}, ByteArray[{1, 2, 3}]]},
    And[
     Lookup[event, "SourceSocket"] === WLJS`CSockets`CSocketObject[{7, 17, 2, 2, 1, 0}],
     Lookup[event, "AddressStorage"] === WLJS`CSockets`AddressStorage[ByteArray[{1, 2, 3}]]
    ]
   ],
   True,
   TestID -> "receivedfrom-address-only-conversion"
  ],

  VerificationTest[
   With[
    {event = WLJS`CSockets`Private`createEventData["ReceivedFrom", {7, 17, 2, 2, 1, 0}, ByteArray[{1, 2, 3}], {65, 66, 67}]},
    And[
     Lookup[event, "SourceSocket"] === WLJS`CSockets`CSocketObject[{7, 17, 2, 2, 1, 0}],
     Lookup[event, "AddressStorage"] === WLJS`CSockets`AddressStorage[ByteArray[{1, 2, 3}]],
     Lookup[event, "Data"] === "ABC",
     Lookup[event, "DataBytes"] === {65, 66, 67},
     Lookup[event, "DataByteArray"] === ByteArray[{65, 66, 67}]
    ]
   ],
   True,
   TestID -> "receivedfrom-address-and-data-conversion"
  ],

  VerificationTest[
   With[
    {event = WLJS`CSockets`Private`createEventData["Received", {7, 6, 1, 1, 1, 0}, {65, 66, 67}]},
    And[
     Lookup[event, "SourceSocket"] === WLJS`CSockets`CSocketObject[{7, 6, 1, 1, 1, 0}],
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
   With[{handler = WLJS`CSockets`CSocketHandler[]},
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
     WLJS`CSockets`Private`socketSendString = Function[{socketData, text}, {"text", socketData, text}],
     WLJS`CSockets`Private`socketSend = Function[{socketId, byteArray, len}, {"bytes", socketId, Length[byteArray], len}],
     handler = WLJS`CSockets`CSocketHandler[],
     client = WLJS`CSockets`CSocketObject[{33, 6, 1, 2, 1, 0}]
    },
    And[
     WLJS`CSockets`Private`sendResponse[handler, <|"SourceSocket" -> client|>, "ok"] === {"text", {33, 6, 1, 2, 1, 0}, "ok"},
     WLJS`CSockets`Private`sendResponse[handler, <|"SourceSocket" -> client|>, ByteArray[{1, 2}]] === {"bytes", {33, 6, 1, 2, 1, 0}, 2, 2},
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
