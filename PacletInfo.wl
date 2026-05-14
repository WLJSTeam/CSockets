(* ::Package:: *)

PacletObject[
  <|
    "Name" -> "WLJS/CSockets",
    "Description" -> "Sockets powered by pure C",
    "Creator" -> "Kirill",
    "License" -> "MIT",
    "PublisherID" -> "WLJS",
    "Version" -> "1.0.26",
    "WolframVersion" -> "13.3+",
    "PrimaryContext" -> "WLJS`CSockets`",
    "Extensions" -> {
      {
        "Kernel",
        "Root" -> "Kernel",
        "Context" -> {
          {"WLJS`CSockets`", "CSockets.wl"},
          {"WLJS`CSockets`Constants`", "Constants.wl"},
          {"WLJS`CSockets`Library`", "Library.wl"},
          {"WLJS`CSockets`Handler`", "Handler.wl"}
        },
        "Symbols" -> {}
      },
      {"Documentation", "Language" -> "English"},
      {"LibraryLink", "Root" -> "LibraryResources"},
      {
        "Asset",
        "Assets" -> {
          {"License", "./LICENSE"},
          {"ReadMe", "./README.md"},
          {"Source", "./Source"},
          {"Images", "./Images"}
        }
      }
    }
  |>
]
