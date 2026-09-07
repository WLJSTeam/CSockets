#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


socket = CSocketConnect[8000];


data = ByteArray[RandomInteger[{0, 255}, 1024 * 1024]];


Echo[AbsoluteTiming[Do[BinaryWrite[socket, data], {1000}]]];