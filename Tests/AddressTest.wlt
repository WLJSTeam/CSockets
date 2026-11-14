Needs["MUnit`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];
TestReport[{
 VerificationTest[
  Module[{server, client, data, address, buffer, result},
   server = CSocketOpen["127.0.0.1", 0, "UDP"];
   client = CSocketConnect["127.0.0.1", server["DestinationPort"], "UDP", "Wait" -> True];
   data = First[server];
   address = WLJS`CSockets`Private`socketAddressStorageCreate["127.0.0.1", "0", 2, 2, 17, ""];
   buffer = ByteArray[ConstantArray[0, 32]];
   BinaryWrite[client, ByteArray[{1, 2, 3}]];
   result = And[
    MatchQ[server, CSocketObject[{_Integer, _Integer, 2, 1, 1, 0}]],
    server["Protocol"] === "UDP", server["DirectionType"] === "Server",
    client["Scheme"] === "udp", SocketReadyQ[server, 1] === True,
    WLJS`CSockets`Private`socketRecvFrom[data, address, buffer, 32] === ByteArray[{1, 2, 3}]
   ]; Scan[Close, {client, server}]; result
  ], True, TestID -> "udp-six-field-address-roundtrip"],
 VerificationTest[
  Module[{server, result}, server = CSocketOpen["127.0.0.1", 0];
   result = KeyExistsQ[$CSockets, server["UUID"]]; Close[server];
   result && Length[$CSockets] === 0], True, TestID -> "registry-uses-descriptor-key-and-close-removes-it"]
}]
