#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


log = <||>;


serve[assoc_Association?AssociationQ] /; KeyExistsQ[assoc, "DataByteArray"] :=
With[{t = Round[AbsoluteTime[assoc["Timestamp"]]], d = Length[assoc["DataByteArray"]]},
    If[KeyExistsQ[log, t],
        log[t] = log[t] + d,
        log[t] = d
    ];
];


SocketListen[CSocketOpen[8000], serve];


While[True, Pause[0.1];
    If[Length[log] > 1,
        Echo[N @ Mean[Select[log, # > 0&]] / 1000000.];
    ]
];