Needs["MUnit`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];
TestReport[Table[
 VerificationTest[
  Module[{server, client, list, task, events = {}, received, result},
   server = CSocketOpen["127.0.0.1", 0, protocol];
   list = CSocketList[{server}];
   task = SocketListen[list, (AppendTo[events, #] &)];
   client = CSocketConnect["127.0.0.1", server["DestinationPort"], protocol, "Wait" -> True];
   WriteString[client, "ping"];
   Do[Pause[0.05]; If[AnyTrue[events, MemberQ[{"Received", "ReceivedFrom"}, #["Event"]] &], Break[]], {60}];
   received = SelectFirst[events, MemberQ[{"Received", "ReceivedFrom"}, #["Event"]] &, <||>];
   result = KeyExistsQ[received, "SourceSocket"] && Length[First[received["SourceSocket"]]] === 6 && received["DataBytes"] === {112, 105, 110, 103};
   If[protocol === "TCP", result = result && AnyTrue[events, #["Event"] === "Accepted" && MatchQ[#["AcceptedSocket"], CSocketObject[{_Integer, 6, 1, 3, 1, 0}]] &]];
   RemoveAsynchronousTask[task];
   If[protocol === "TCP" && KeyExistsQ[received, "SourceSocket"], Close[received["SourceSocket"]]];
   Scan[Close, {client, server}];
   WLJS`CSockets`Private`socketListDelete[First[list]];
   result
  ], True, TestID -> ("async-six-field-" <> protocol)],
 {protocol, {"TCP", "UDP"}}]]
