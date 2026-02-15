BeginPackage["KirillBelov`CSockets`Constatns`"];


(* Cross-platform socket constants association *)
(* Format: "CONST_NAME" -> value  (16^^ for hex, decimal for raw numbers) *)
(* Verified against POSIX/Windows headers *)

$socketConstants = <|
    (* Protocol levels *)
    "IPPROTO_IP"   :> 0,               (* IPv4 protocol - standard value *)
    "IPPROTO_TCP"  :> 6,               (* TCP protocol - common value *)
    "IPPROTO_UDP"  :> 17,              (* UDP protocol - standard value *)
    "IPPROTO_IPV6" :> 16^^0029,        (* IPv6 protocol - POSIX hex value *)
    "SOL_SOCKET"   :> 16^^FFFF,        (* Socket-level options - standard hex *)

    (* Socket options (SOL_SOCKET level) *)
    "SO_KEEPALIVE" :> 16^^0008,        (* Enable keep-alive packets *)
    "SO_RCVBUF"    :> 16^^1002,        (* Receive buffer size *)
    "SO_SNDBUF"    :> 16^^1001,        (* Send buffer size *)
    "SO_REUSEADDR" :> 16^^0002,        (* Allow address reuse - POSIX hex *)
    "SO_EXCLUSIVEADDRUSE" :> -5,       (* Windows-specific address protection *)
    "SO_LINGER"    :> 16^^0080,        (* Linger on close *)
    "SO_BROADCAST" :> 16^^0020,        (* Permit broadcast *)
    "SO_ERROR"     :> 16^^1007,        (* Get error status *)
    "SOMAXCONN"    :> 16^^7FFFFFFF,    (* Max available sockets for listen *)
    "SO_TYPE"      :> 16^^1008,        (* Get socket type *)
    "SO_ACCEPTCONN" :> 16^^0002,       (* Check if socket is listening *)

    (* TCP-specific options *)
    "TCP_NODELAY"  :> 16^^0001,        (* Disable Nagle algorithm *)
    "TCP_KEEPIDLE" :> 16^^0004,        (* Start keepalives after idle period *)
    "TCP_KEEPINTVL":> 16^^0005,        (* Interval between keepalives *)
    "TCP_KEEPCNT"  :> 16^^0006,        (* Number of keepalives before drop *)

    (* IP-level options *)
    "IP_TTL"       :> 16^^0004,        (* Time-To-Live for packets *)
    "IP_TOS"       :> 16^^0001,        (* Type Of Service *)
    "IP_MTU_DISCOVER" :> 16^^000A,     (* Path MTU discovery *)

    (* IPv6-specific options *)
    "IPV6_V6ONLY"  :> 16^^001A,        (* Restrict to IPv6 only *)

    (* Address families *)
    "AF_INET"      :> 16^^0002,        (* IPv4 address family *)
    "AF_INET6"     :> 16^^000A,        (* IPv6 address family *)
    "SOCK_STREAM"  :> 16^^0001,        (* Stream socket (TCP) *)
    "SOCK_DGRAM"   :> 16^^0002         (* Datagram socket (UDP) *)
|>;


(* Platform-specific overrides *)
(* Uncomment if targeting specific OS: *)
If[$OperatingSystem === "Windows",
    (* Windows uses different values for some constants *)
    $socketConstants["IPPROTO_IPV6"] := 41;
    $socketConstants["SO_REUSEADDR"] := 4;
    $socketConstants["IPV6_V6ONLY"] := 27;
    $socketConstants["SO_TYPE"] := 3;
];


(* ================================================ *)
(*  Protocol levels for getsockopt / setsockopt     *)
(*  ($socketOptLevels - only "level", not optname)  *)
(* ================================================ *)

$socketOptLevels = <|
    "SOL_SOCKET"    :> 1,           (* Socket-level options - POSIX default *)
    "IPPROTO_IP"    :> 0,           (* IPv4 protocol level *)
    "IPPROTO_TCP"   :> 6,           (* TCP protocol level *)
    "IPPROTO_UDP"   :> 17,          (* UDP protocol level *)
    "IPPROTO_IPV6"  :> 16^^0029     (* IPv6 protocol level - POSIX hex *)
|>;


(* Platform-specific overrides *)
If[$OperatingSystem === "Windows",
    (* Windows uses different values for some levels *)
    $socketOptLevels["SOL_SOCKET"]   := 16^^FFFF;  (* Winsock socket level *)
    $socketOptLevels["IPPROTO_IPV6"] := 41;        (* Decimal 0x29 *)
];


(* ================================================= *)
(*  Socket / protocol option names (optname only)     *)
(*  Use together with $socketOptLevels for level arg  *)
(* ================================================= *)

$socketOptNames = <|
    (* -------- SOL_SOCKET level -------- *)
    "SO_KEEPALIVE"        :> 16^^0008,     (* Enable keep-alive packets            *)
    "SO_RCVBUF"           :> 16^^1002,     (* Receive buffer size (bytes)          *)
    "SO_SNDBUF"           :> 16^^1001,     (* Send buffer size (bytes)             *)
    "SO_REUSEADDR"        :> 16^^0002,     (* Allow local address reuse            *)
    "SO_EXCLUSIVEADDRUSE" :> -5,           (* Windows-specific: exclusive bind     *)
    "SO_LINGER"           :> 16^^0080,     (* Linger on close                      *)
    "SO_BROADCAST"        :> 16^^0020,     (* Permit datagram broadcasts           *)
    "SO_ERROR"            :> 16^^1007,     (* Get pending error status             *)
    "SOMAXCONN"           :> 16^^7FFFFFFF, (* Maximum backlog for listen()         *)
    "SO_TYPE"             :> 3,            (* Get socket type (STREAM/DGRAM/...)   *)
    "SO_ACCEPTCONN"       :> 16^^0002,     (* Non-zero if socket is in LISTEN      *)

    (* -------- IPPROTO_TCP level -------- *)
    "TCP_NODELAY"         :> 16^^0001,     (* Disable Nagle algorithm              *)
    "TCP_KEEPIDLE"        :> 16^^0004,     (* Idle time before keep-alives (s)     *)
    "TCP_KEEPINTVL"       :> 16^^0005,     (* Interval between keep-alives (s)     *)
    "TCP_KEEPCNT"         :> 16^^0006,     (* Keep-alive probe count before drop   *)

    (* -------- IPPROTO_IP level -------- *)
    "IP_TTL"              :> 16^^0004,     (* Default IPv4 TTL                     *)
    "IP_TOS"              :> 16^^0001,     (* IPv4 Type-of-Service / DSCP          *)
    "IP_MTU_DISCOVER"     :> 16^^000A,     (* Path-MTU discovery setting           *)

    (* -------- IPPROTO_IPV6 level -------- *)
    "IPV6_V6ONLY"         :> 16^^001A      (* Restrict socket to IPv6 only         *)
|>;

(* ---------- Platform-specific overrides ---------- *)
If[$OperatingSystem === "Windows",
    (* Winsock uses different numeric values for some options *)
    $socketOptNames["SO_REUSEADDR"] := 4;       (* 0x0004 on Windows *)
    $socketOptNames["SO_TYPE"]      := 16^1108; (* 0x1008 on Windows *)
];


$socketOptLevelMap = <|
    (* -------- SOL_SOCKET level -------- *)
    "SO_KEEPALIVE"         -> "SOL_SOCKET",
    "SO_RCVBUF"            -> "SOL_SOCKET",
    "SO_SNDBUF"            -> "SOL_SOCKET",
    "SO_REUSEADDR"         -> "SOL_SOCKET",
    "SO_EXCLUSIVEADDRUSE"  -> "SOL_SOCKET",   (* Windows-only *)
    "SO_LINGER"            -> "SOL_SOCKET",
    "SO_BROADCAST"         -> "SOL_SOCKET",
    "SO_ERROR"             -> "SOL_SOCKET",
    "SOMAXCONN"            -> "SOL_SOCKET",
    "SO_TYPE"              -> "SOL_SOCKET",
    "SO_ACCEPTCONN"        -> "SOL_SOCKET",

    (* -------- IPPROTO_TCP level -------- *)
    "TCP_NODELAY"          -> "IPPROTO_TCP",
    "TCP_KEEPIDLE"         -> "IPPROTO_TCP",
    "TCP_KEEPINTVL"        -> "IPPROTO_TCP",
    "TCP_KEEPCNT"          -> "IPPROTO_TCP",

    (* -------- IPPROTO_IP (IPv4) level -------- *)
    "IP_TTL"               -> "IPPROTO_IP",
    "IP_TOS"               -> "IPPROTO_IP",
    "IP_MTU_DISCOVER"      -> "IPPROTO_IP",

    (* -------- IPPROTO_IPV6 level -------- *)
    "IPV6_V6ONLY"          -> "IPPROTO_IPV6"
|>;


EndPackage[];
