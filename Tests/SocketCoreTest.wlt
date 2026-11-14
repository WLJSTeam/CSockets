Needs["MUnit`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];
TestReport[{
 VerificationTest[
  With[{tcp = CSocketObject[{10, 0, 1, 1, 1, 0}], udp = CSocketObject[{11, 0, 2, 2, 1, 1}]},
   {tcp["DirectionType"], tcp["Protocol"], tcp["Scheme"], tcp["UUID"], tcp["InprocQ"], udp["DirectionType"], udp["Protocol"], udp["Scheme"], udp["UUID"]}],
  {"Server", "TCP", "tcp", 10, False, "Client", "UDP", "udp", 11}, TestID -> "accessors-use-role-type-and-descriptor"],
 VerificationTest[
  Quiet[CSocketConnect["localhost", 80, "TCP", "Wait" -> "invalid"]], $Failed,
  TestID -> "invalid-options-rejected-before-native-call"],
 VerificationTest[
  Module[{server, data, result}, server = CSocketOpen["127.0.0.1", 0]; data = First[server];
   WLJS`CSockets`Private`socketSetNonBlockingMode[data]; result = data[[6]] === 1;
   WLJS`CSockets`Private`socketSetBlockingMode[data]; result = result && data[[6]] === 0;
   Close[server]; result && data[[5]] === 0], True, TestID -> "shared-row-tracks-mode-and-close"],
 VerificationTest[
  Module[{server, client, result}, server = CSocketOpen["127.0.0.1", 0];
   client = CSocketConnect["127.0.0.1", server["DestinationPort"]];
   result = MatchQ[client, CSocketObject[{_Integer, _Integer, 1, 2, 1, 0}]];
   Scan[Close, {client, server}]; result], True, TestID -> "default-connect-updates-role"],
 VerificationTest[
  Module[{server, client, accepted, port, data, list, rows, result},
   server = CSocketOpen["127.0.0.1", 0]; port = server["DestinationPort"];
   client = CSocketConnect["127.0.0.1", port, "TCP", "Wait" -> True];
   data = WLJS`CSockets`Private`socketAccept[First[server]];
   accepted = CSocketObject[data];
   list = CSocketList[{server, client, accepted}];
   rows = WLJS`CSockets`Private`socketListGetAll[First[list]];
   WriteString[client, "hello"];
   result = And[
    MatchQ[server, CSocketObject[{_Integer, _Integer, 1, 1, 1, 0}]],
    MatchQ[client, CSocketObject[{_Integer, _Integer, 1, 2, 1, 0}]],
    MatchQ[accepted, CSocketObject[{_Integer, 6, 1, 3, 1, 0}]],
    Dimensions[rows] === {3, 6}, rows === (First /@ {server, client, accepted}),
    server["Protocol"] === "TCP", client["DirectionType"] === "Client",
    SocketReadyQ[accepted, 1] === True,
    WLJS`CSockets`Private`socketsSelect[{data}, 1, 1000000, 1] === {data},
    Dimensions[WLJS`CSockets`Private`socketsPoll[{data}, 1, 0, 1]] === {1, 7},
    SocketReadMessage[accepted] === ByteArray[ToCharacterCode["hello"]]
   ];
   WLJS`CSockets`Private`socketListDelete[First[list]];
   Scan[Close, {accepted, client, server}]; result
  ], True, TestID -> "tcp-six-field-roundtrip-and-bulk-operations"],
 VerificationTest[
  Block[{WLJS`CSockets`Private`socketSendString = Function[{row, text}, {row, text}],
    WLJS`CSockets`Private`socketSend = Function[{row, bytes, len}, {row, Length[bytes], len}]},
   With[{row = {42, 17, 2, 2, 1, 1}},
    {WriteString[CSocketObject[row], "hi"], BinaryWrite[CSocketObject[row], ByteArray[{1, 2}]]} === {{row, "hi"}, {row, 2, 2}}]],
  True, TestID -> "write-wrappers-pass-all-six-fields"],
 VerificationTest[
  Block[{WLJS`CSockets`Private`socketsSelect = Function[{rows, count, timeout, mode}, rows]},
   SocketWaitNext[CSocketObject[{42, 6, 1, 2, 1, 0}]]],
  {{42, 6, 1, 2, 1, 0}}, TestID -> "wait-passes-six-field-row"],
 VerificationTest[
  Quiet[WLJS`CSockets`Private`socketGetPort[{1, 2}]], _LibraryFunctionError,
  SameTest -> MatchQ, TestID -> "native-boundary-rejects-short-row"]
}]
