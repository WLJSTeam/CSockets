Needs["MUnit`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];


TestReport[{
    VerificationTest[
        Block[{
            calls = {},
            WLJS`CSockets`Private`socketSend = Function[{row, bytes, length},
                AppendTo[calls, Normal[bytes]];
                Min[2, length]
            ]
        },
            {BinaryWrite[CSocketObject[{42, 6, 1, 2, 1, 0}], ByteArray[{1, 2, 3, 4, 5}]], calls}
        ],
        {5, {{1, 2, 3, 4, 5}, {3, 4, 5}, {5}}},
        TestID -> "binary-write-recursively-sends-remainder"
    ],
    VerificationTest[
        Block[{
            calls = {},
            WLJS`CSockets`Private`socketSend = Function[{row, bytes, length},
                AppendTo[calls, Normal[bytes]];
                Min[1, length]
            ]
        },
            {WriteString[CSocketObject[{42, 6, 1, 2, 1, 0}], FromCharacterCode[233]], calls}
        ],
        {2, {{195, 169}, {169}}},
        TestID -> "write-string-resumes-inside-utf8-character"
    ],
    VerificationTest[
        Block[{
            calls = {},
            WLJS`CSockets`Private`socketSend = Function[{row, bytes, length},
                AppendTo[calls, Normal[bytes]];
                length
            ]
        },
            {WriteString[CSocketObject[{42, 6, 1, 2, 1, 0}], FromCharacterCode[{97, 0, 98}]], calls}
        ],
        {3, {{97, 0, 98}}},
        TestID -> "write-string-preserves-embedded-null"
    ],
    VerificationTest[
        Table[
            Block[{
                calls = 0,
                WLJS`CSockets`Private`socketSend = Function[{row, bytes, length},
                    calls++;
                    If[calls === 1, 1, failure]
                ]
            },
                {BinaryWrite[CSocketObject[{42, 6, 1, 2, 1, 0}], ByteArray[{1, 2, 3}]], calls}
            ],
            {failure, {0, LibraryFunctionError["send", 6]}}
        ],
        {{$Failed, 2}, {LibraryFunctionError["send", 6], 2}},
        TestID -> "send-stops-on-zero-progress-or-error"
    ],
    VerificationTest[
        Block[{
            calls = {},
            WLJS`CSockets`Private`socketSendToAddressStorage = Function[{row, address, bytes},
                AppendTo[calls, {address, Normal[bytes]}];
                Min[2, Length[bytes]]
            ]
        },
            {BinaryWrite[
                CSocketObject[{42, 17, 2, 1, 1, 0}],
                AddressStorage[ByteArray[{9}]], ByteArray[{1, 2, 3}]
            ], calls}
        ],
        {3, {{ByteArray[{9}], {1, 2, 3}}, {ByteArray[{9}], {3}}}},
        TestID -> "udp-binary-write-resends-remainder-to-same-address"
    ],
    VerificationTest[
        Block[{
            calls = {},
            WLJS`CSockets`Private`socketSendToAddressStorage = Function[{row, address, bytes},
                AppendTo[calls, {address, Normal[bytes]}];
                Min[1, Length[bytes]]
            ]
        },
            {WriteString[
                CSocketObject[{42, 17, 2, 1, 1, 0}],
                AddressStorage[ByteArray[{9}]], FromCharacterCode[233]
            ], calls}
        ],
        {2, {{ByteArray[{9}], {195, 169}}, {ByteArray[{9}], {169}}}},
        TestID -> "udp-write-string-converts-utf8-and-resends-remainder"
    ],
    VerificationTest[
        Block[{WLJS`CSockets`Private`socketSend = Function[{row, bytes, length}, length]},
            BinaryWrite[CSocketObject[{42, 6, 1, 2, 1, 0}], ByteArray[{}]]
        ],
        0,
        TestID -> "empty-send-completes-with-zero"
    ]
}]
