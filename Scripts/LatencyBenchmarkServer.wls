#!/usr/bin/env wolframscript

(* Started by LatencyBenchmark.py with a JSON configuration file. *)


Print["BENCHMARK_STARTING"];


Get[FileNameJoin[{DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}]];


arguments = If[$ScriptCommandLine === {}, {}, Rest[$ScriptCommandLine]];


If[arguments === {} && StringQ[Environment["CSOCKETS_LATENCY_CONFIG"]],
    arguments = {Environment["CSOCKETS_LATENCY_CONFIG"]}
];


If[Length[arguments] =!= 1,
    Print["Usage: wolframscript -f Scripts/LatencyBenchmarkServer.wls config.json"];
    Exit[1]
];


configuration = Import[First[arguments], "RawJSON"];


If[!AssociationQ[configuration] || !StringQ[configuration["ReadyFile"]] || !StringQ[configuration["StopToken"]],
    Print["Expected ReadyFile and StopToken strings in the configuration."];
    Exit[1]
];


benchmarkFailed = False;


closeBenchmarkSockets[] :=
Scan[Close, CSocketObject /@ Keys[$CSockets]];


benchmarkError[packet_Association] :=
(
    benchmarkFailed = True;
    Print["BENCHMARK ERROR: ", packet];
    closeBenchmarkSockets[];
    Null
);


setNoDelay[packet_Association] :=
Check[
    WLJS`CSockets`Private`socketSetOpt[
        First[packet["AcceptedSocket"]],
        WLJS`CSockets`Private`$IPPROTOTCP,
        WLJS`CSockets`Private`$TCPNODELAY,
        1
    ],
    benchmarkFailed = True;
    closeBenchmarkSockets[];
];


stopBenchmark[packet_Association] :=
(
    If[packet["DataByteArray"] === StringToByteArray[configuration["StopToken"]],
        closeBenchmarkSockets[]
    ];

    Null
);


tcpHandler = CSocketHandler[
    "Accepted" -> setNoDelay,
    "Received" -> (#DataByteArray&),
    "Error" -> benchmarkError
];


udpHandler = CSocketHandler[
    "ReceivedFrom" -> (#DataByteArray&),
    "Error" -> benchmarkError
];


controlHandler = CSocketHandler["ReceivedFrom" -> stopBenchmark, "Error" -> benchmarkError];


tcpServer = CSocketOpen["127.0.0.1", 0, "TCP"];


udpServer = CSocketOpen["127.0.0.1", 0, "UDP"];


controlServer = CSocketOpen["127.0.0.1", 0, "UDP"];


If[!AllTrue[{tcpServer, udpServer, controlServer}, MatchQ[#, _CSocketObject]&],
    closeBenchmarkSockets[];
    Exit[1]
];


readyFile = configuration["ReadyFile"];


Export[readyFile <> ".tmp", <|
    "TCP" -> tcpServer["LocalAddress"],
    "UDP" -> udpServer["LocalAddress"],
    "Control" -> controlServer["LocalAddress"],
    "WolframVersion" -> $Version,
    "SystemID" -> $SystemID,
    "ProcessorCount" -> $ProcessorCount,
    "TCPNoDelay" -> True
|>, "RawJSON"];


RenameFile[readyFile <> ".tmp", readyFile];


Print["BENCHMARK_READY"];


result = CheckAbort[
    CSocketHandle[{
        tcpServer -> tcpHandler,
        udpServer -> udpHandler,
        controlServer -> controlHandler
    }],
    benchmarkFailed = True;
    $Aborted
];


closeBenchmarkSockets[];


If[benchmarkFailed || result =!= Null, Exit[1]];


Print["BENCHMARK_STOPPED"];
