BeginPackage["KirillBelov`CSockets`Constatns`"];


optLevel::usage = "optLevel[name] returns the socket option's level.";


optValue::usage = "optValue[name] returns {level value, option value}.";


Begin["`Private`"];


(* ============================== *)
(*         Constants              *)
(* ============================== *)


$socketConstants = <|
  "SOMAXCONN"   :> 16^^7FFFFFFF,
  "AF_INET"     :> 16^^0002,
  "AF_INET6"    :> 16^^000A,
  "SOCK_STREAM" :> 16^^0001,
  "SOCK_DGRAM"  :> 16^^0002
|>;


$socketOpts = <|
  "SOL_SOCKET" :> <|
    "Value" :> If[$OperatingSystem === "Windows", 16^^FFFF, 1],
    "Options" :> <|
      "SO_KEEPALIVE"        :> 16^^0008,
      "SO_RCVBUF"           :> 16^^1002,
      "SO_SNDBUF"           :> 16^^1001,
      "SO_REUSEADDR"        :> If[$OperatingSystem === "Windows", 4, 16^^0002],
      "SO_EXCLUSIVEADDRUSE" :> -5,
      "SO_LINGER"           :> 16^^0080,
      "SO_BROADCAST"        :> 16^^0020,
      "SO_ERROR"            :> 16^^1007,
      "SO_TYPE"             :> If[$OperatingSystem === "Windows", 3, 16^^1008],
      "SO_ACCEPTCONN"       :> 16^^0002
    |>
  |>,
  "IPPROTO_TCP" :> <|
    "Value" :> 6,
    "Options" :> <|
      "TCP_NODELAY"   :> 16^^0001,
      "TCP_KEEPIDLE"  :> 16^^0004,
      "TCP_KEEPINTVL" :> 16^^0005,
      "TCP_KEEPCNT"   :> 16^^0006
    |>
  |>,
  "IPPROTO_IP" :> <|
    "Value" :> 0,
    "Options" :> <|
      "IP_TTL"          :> 16^^0004,
      "IP_TOS"          :> 16^^0001,
      "IP_MTU_DISCOVER" :> 16^^000A
    |>
  |>,
  "IPPROTO_IPV6" :> <|
    "Value" :> If[$OperatingSystem === "Windows", 41, 16^^0029],
    "Options" :> <|
      "IPV6_V6ONLY" :> If[$OperatingSystem === "Windows", 27, 16^^001A]
    |>
  |>
|>;


(* ============================== *)
(*     Option Access Helpers     *)
(* ============================== *)


optLevel[name_String] :=
  KeySelect[$socketOpts,
    Function[level,
      KeyExistsQ[$socketOpts[level]["Options"], name]
    ]
  ] // Keys // First;


optValue[name_String] := Module[{lvl},
  lvl = optLevel[name];
  {
    $socketOpts[lvl]["Value"],
    $socketOpts[lvl]["Options"][name]
  }
];


$socketOptionNames = 
Keys @ Apply[Join] @ Values @ Query[All, "Options"] @ $socketOpts;

(*
addCompletion := FE`Evaluate[FEPrivate`AddSpecialArgCompletion[#]]&;


addCompletion["optLevel" -> $socketOptionNames]; 


addCompletion["optValue" -> $socketOptionNames];
*)

End[]; (* `Private` *)


EndPackage[];
