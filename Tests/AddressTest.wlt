Needs["MUnit`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];
TestReport[{
 VerificationTest[
  Module[{server, client, data, buffer, result},
   server = CSocketOpen["127.0.0.1", 0, "UDP"];
   client = CSocketConnect["127.0.0.1", server["DestinationPort"], "UDP", "Wait" -> True];
   data = First[server];
   buffer = ByteArray[ConstantArray[0, 32]];
   BinaryWrite[client, ByteArray[{1, 2, 3}]];
   result = And[
    MatchQ[server, CSocketObject[_Integer]],
    server["Protocol"] === "UDP", server["DirectionType"] === "Server",
    client["Scheme"] === "udp", SocketReadyQ[server, 1] === True,
    With[{received = WLJS`CSockets`Private`socketRecvFrom[data, buffer]},
     Length[received] === 2 && ByteArray[received[[1]]] === ByteArray[{1, 2, 3}] &&
      First[WLJS`CSockets`Private`splitAddress[received[[2]]]] === "127.0.0.1" &&
      ToExpression[Last[WLJS`CSockets`Private`splitAddress[received[[2]]]]] === client["DestinationPort"]
    ]
   ]; Scan[Close, {client, server}]; result
  ], True, TestID -> "udp-id-address-roundtrip"],
 VerificationTest[
  Module[{server, clients, buffer, received, address, result},
   server = CSocketOpen["127.0.0.1", 0, "UDP"];
   clients = Table[CSocketConnect["127.0.0.1", server["DestinationPort"], "UDP", "Wait" -> True], {2}];
   buffer = ByteArray[ConstantArray[0, 7]];
   result = And @@ Table[
    BinaryWrite[clients[[i]], ByteArray[If[i === 1, Range[7], {}]]];
    If[!TrueQ[SocketReadyQ[server, 1]], False,
     received = WLJS`CSockets`Private`socketRecvFrom[First[server], buffer];
     address = WLJS`CSockets`Private`splitAddress[received[[2]]];
     ByteArray[received[[1]]] === ByteArray[If[i === 1, Range[7], {}]] &&
      First[address] === "127.0.0.1" && ToExpression[Last[address]] === clients[[i]]["DestinationPort"]
    ],
    {i, 2}
   ];
   Scan[Close, Append[clients, server]];
   result
  ], True, TestID -> "recvfrom-infers-buffer-size-and-returns-empty-datagram-address"],
 VerificationTest[
  Module[{server, buffer, result},
   server = CSocketOpen["127.0.0.1", 0, "UDP"];
   buffer = ByteArray[ConstantArray[0, 7]];
   WLJS`CSockets`Private`socketSetNonBlockingMode[First[server]];
   result = Quiet[WLJS`CSockets`Private`socketRecvFrom[First[server], buffer]];
   Close[server];
   MatchQ[result, _LibraryFunctionError]
  ], True, TestID -> "recvfrom-without-data-returns-native-error"],
 VerificationTest[
  Module[{server, client, received, result},
   server = CSocketOpen["127.0.0.1", 0, "UDP"];
   client = CSocketConnect["127.0.0.1", server["DestinationPort"], "UDP", "Wait" -> True];
   result = And @@ Table[
    BinaryWrite[client, bytes];
    If[!TrueQ[SocketReadyQ[server, 1]], False,
     received = SocketReadMessage[server];
     MatchQ[received, {(_NumericArray | {}), _String}] && ByteArray[received[[1]]] === bytes &&
      ToExpression[Last[WLJS`CSockets`Private`splitAddress[received[[2]]]]] === client["DestinationPort"] &&
      BinaryWrite[server, received[[2]], bytes] === Length[bytes] &&
      TrueQ[SocketReadyQ[client, 1]] && With[{reply = SocketReadMessage[client]},
       MatchQ[reply, {(_NumericArray | {}), _String}] && ByteArray[reply[[1]]] === bytes &&
        ToExpression[Last[WLJS`CSockets`Private`splitAddress[reply[[2]]]]] === server["DestinationPort"]
      ]
    ],
    {bytes, {ByteArray[{0, 128, 255}], ByteArray[{}]}}
   ];
   Scan[Close, {client, server}];
   result
  ], True, TestID -> "read-message-udp-client-and-server-return-raw-pair"],
 VerificationTest[
  With[{data = NumericArray[{1, 2}, "UnsignedInteger8"], address = "127.0.0.1:9000"},
   Block[{WLJS`CSockets`$CSockets = <||>, WLJS`CSockets`Private`socketRecvFrom = Function[{row, buffer}, Developer`DataStore[data, address]]},
    And @@ Table[
     SocketReadMessage[WLJS`CSockets`Private`registerSocket[42, "UDP", role, True]] === {data, address},
     {role, {"Binded", "Connected"}}
    ]
   ]
  ], True, TestID -> "read-message-preserves-both-native-udp-values"],
 VerificationTest[
  Module[{server, result}, server = CSocketOpen["127.0.0.1", 0];
   result = KeyExistsQ[$CSockets, server["UUID"]]; Close[server];
   result && $CSockets[server["UUID"]]["State"] === "Closed"], True, TestID -> "registry-uses-descriptor-key-and-retains-closed-state"]
}]
