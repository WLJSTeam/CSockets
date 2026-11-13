Needs["MUnit`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];


TestReport[{
    VerificationTest[
        With[{
            address = AddressStorage[WLJS`CSockets`Private`socketAddressStorageCreate[
                "192.0.2.42", "54321", 0, 2, 17, ""
            ]]
        },
            {address["Host"], address["Port"], address["Family"]}
        ],
        {"192.0.2.42", 54321, "IPv4"},
        TestID -> "ipv4-storage-properties"
    ],
    VerificationTest[
        With[{
            address = AddressStorage[WLJS`CSockets`Private`socketAddressStorageCreate[
                "::1", "54321", 0, 2, 17, ""
            ]]
        },
            {address["Host"], address["Port"], address["Family"]}
        ],
        {"::1", 54321, "IPv6"},
        TestID -> "ipv6-storage-properties"
    ],
    VerificationTest[
        With[{
            address = AddressStorage[WLJS`CSockets`Private`socketAddressStorageCreate[
                "fe80::1%3", "8080", 0, 2, 17, ""
            ]]
        },
            {address["Host"], address["Port"], address["Family"]}
        ],
        {"fe80::1", 8080, "IPv6"},
        TestID -> "scoped-ipv6-host-and-port"
    ],
    VerificationTest[
        Quiet[{AddressStorage[ByteArray[{1}]]["Host"], AddressStorage[ByteArray[{1}]]["Port"]}],
        {$Failed, $Failed},
        TestID -> "short-storage-rejected"
    ],
    VerificationTest[
        Quiet[AddressStorage[ByteArray[ConstantArray[0, 128]]]["Family"]],
        $Failed,
        TestID -> "unsupported-address-family-rejected"
    ]
}]
