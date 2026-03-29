(* ::Package:: *)

BeginPackage["WLJS`CSockets`Library`List`", {
    "WLJS`CSockets`Library`Common`",
    "CCompilerDriver`",
    "LibraryLink`"
}];


socketAddressInfoListCreate::usage =
"socketAddressInfoListCreate[addressInfoList, length] creates internal array of address infos.";


socketAddressInfoListRemove::usage =
"socketAddressInfoListRemove[addressInfoListPtr] free memory.";


Begin["`Private`"];


End[];


EndPackage[];