Needs["MUnit`"];


$testFile = Last[$ScriptCommandLine];


$testReport = Get[$testFile];


If[!MatchQ[$testReport, _TestReportObject],
    Print["FAIL: test file did not return a TestReportObject: ", $testFile];
    Exit[1]
];


Print[
    "RESULT: ",
    $testReport["TestsSucceededCount"],
    " passed; ",
    $testReport["TestsFailedCount"],
    " failed"
];


If[$testReport["TestsFailedCount"] > 0,
    Print[
        $testReport["TestsFailed"]
    ];
    Exit[1]
];
