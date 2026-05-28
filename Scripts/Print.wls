#!/usr/bin/env wolframscript

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]];


Get["WLJS`CSockets`"];


SocketListen[CSocketOpen[8080], (Print[#]; Close[#SourceSocket]; Delete[#SocketList, #SourceSocket]; DeleteMissing[#SocketList])&];


While[True, Pause[1]];