#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


log = <||>;


serve[assoc_Association?AssociationQ] /; KeyExistsQ[assoc, "DataByteArray"] :=
log[AbsoluteTime[assoc["Timestamp"]]] = Length[assoc["DataByteArray"]];


SocketListen[CSocketOpen[8000], serve];


While[True, Pause[0.1];
    If[Length[log] > 1,
        Echo[ToString[UnitConvert[Quantity[N @ Total[log] / ((#[[-1]] - #[[1]])&)[Keys[log]], "Bytes"], "Gigabytes"]]];
        log = <||>;
    ]
];