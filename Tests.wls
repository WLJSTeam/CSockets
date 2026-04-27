#!/usr/bin/env wolframscript

Get["WLJS`CSockets`"];


addressInfo = WLJS`CSockets`Library`socketAddressInfoCreate[
    "localhost", 
    "8080",
    SOCKET`AFINET,
    SOCKET`SOCKSTREAM,
    SOCKET`IPPROTOAUTO, 
    ""
]


Echo[addressInfo]


socketId = WLJS`CSockets`Library`socketCreate[
    SOCKET`AFINET,
    SOCKET`SOCKSTREAM,
    SOCKET`IPPROTOAUTO
]


Echo[socketId]


Echo @ CSocketOpen[8000]
