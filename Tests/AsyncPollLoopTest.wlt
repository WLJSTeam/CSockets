Needs["MUnit`"];
Get[FileNameJoin[{DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}]];
Begin["WLJS`CSockets`Private`"];
report = TestReport[Flatten[Table[
 VerificationTest[
  Module[{server, client, list, task, events = {}, received, accepted, result, port},
   server = CSocketOpen[host, 0, protocol];
   port = ToExpression[Last[StringSplit[server["LocalAddress"], ":"]]];
   list = CSocketList[{server}];
   task = SocketListen[list, (AppendTo[events, #])&];
   client = CSocketConnect[host, port, protocol, "Wait" -> True];
   socketSend[First[client], ByteArray[{112, 105, 110, 103}]];
   Do[Pause[0.02]; If[AnyTrue[events, MemberQ[{"Received", "ReceivedFrom"}, #["Event"]]&], Break[]], {150}];
   received = SelectFirst[events, MemberQ[{"Received", "ReceivedFrom"}, #["Event"]]&, <||>];
   result = Lookup[received, "DataBytes", {}] === {112, 105, 110, 103};
   Pause[0.05];
   result = result && Count[Lookup[events, "Event"], "Received" | "ReceivedFrom"] === 1;
   If[protocol === "TCP",
    accepted = SelectFirst[events, #["Event"] === "Accepted"&, <||>];
    result = result && KeyExistsQ[accepted, "AcceptedSocket"] && received["SourceSocket"] === accepted["AcceptedSocket"];
    Module[{clientEvents = {}, clientTask},
     clientTask = SocketListen[client, (AppendTo[clientEvents, #])&];
     socketSend[First[accepted["AcceptedSocket"]], ByteArray[{42}]];
     Do[Pause[0.02]; If[Length[clientEvents] > 0, Break[]], {150}];
     result = result && Length[clientEvents] === 1 && First[clientEvents]["DataBytes"] === {42};
    ];
    Close[client];
    Do[Pause[0.02]; If[AnyTrue[events, #["Event"] === "Closed"&], Break[]], {150}];
    result = result && AnyTrue[events, #["Event"] === "Closed"&] && Length[socketListGetAll[First[list]]] === 1,
    socketSend[First[client], ByteArray[{}]];
    Do[Pause[0.02]; If[Length[events] > 1, Break[]], {150}];
    result = result && Last[events]["DataBytes"] === {};
    Close[client]
   ];
   Close[list]; Close[server];
   result
  ], True, TestID -> ("native-read-" <> host <> "-" <> protocol)
 ], {host, {"127.0.0.1", "::1"}}, {protocol, {"TCP", "UDP"}}]]];
(* Allow canceled poll calls to return before the test kernel unloads the library. *)
Pause[1.1];
End[];
WLJS`CSockets`Private`report
