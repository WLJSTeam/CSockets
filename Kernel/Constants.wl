BeginPackage["KirillBelov`CSockets`Constants`"];

(* Protocol levels *)
SOCKET`IPPROTOIP::usage = "IPPROTO_IP - IPv4 protocol level";
SOCKET`IPPROTOIP = 0;


SOCKET`IPPROTOTCP::usage = "IPPROTO_TCP - TCP protocol level";
SOCKET`IPPROTOTCP = 6;


SOCKET`IPPROTOUDP::usage = "IPPROTO_UDP - UDP protocol level";
SOCKET`IPPROTOUDP = 17;


SOCKET`IPPROTOIPV6::usage = "IPPROTO_IPV6 - IPv6 protocol level";
SOCKET`IPPROTOIPV6 = If[$OperatingSystem === "Windows", 41, 16^^0029];


(* Socket level - platform dependent *)
SOCKET`SOL::usage = "SOL_SOCKET - socket-level options";
SOCKET`SOL = If[$OperatingSystem === "Windows", 16^^FFFF, 1];


(* Socket options (SOL_SOCKET level) *)
SOCKET`SOKEEPALIVE::usage = "SO_KEEPALIVE - enable keep-alive packets";
SOCKET`SOKEEPALIVE = 16^^0008;


SOCKET`SORCVBUF::usage = "SO_RCVBUF - receive buffer size";
SOCKET`SORCVBUF = 16^^1002;


SOCKET`SOSNDBUF::usage = "SO_SNDBUF - send buffer size";
SOCKET`SOSNDBUF = 16^^1001;


SOCKET`SOLINGER::usage = "SO_LINGER - linger on close";
SOCKET`SOLINGER = 16^^0080;


SOCKET`SOBROADCAST::usage = "SO_BROADCAST - permit broadcast messages";
SOCKET`SOBROADCAST = 16^^0020;


SOCKET`SOERROR::usage = "SO_ERROR - get pending socket error";
SOCKET`SOERROR = 16^^1007;


SOCKET`SOMAXCONN::usage = "SOMAXCONN - maximum backlog for listen()";
SOCKET`SOMAXCONN = 16^^7FFFFFFF;


SOCKET`SOTYPE::usage = "SO_TYPE - get socket type (STREAM/DGRAM)";
SOCKET`SOTYPE = 16^^1008;


SOCKET`SOACCEPTCONN::usage = "SO_ACCEPTCONN - non-zero if socket is listening";
SOCKET`SOACCEPTCONN = 16^^0002;


SOCKET`SOREUSEADDR::usage = "SO_REUSEADDR - reuse local address";
SOCKET`SOREUSEADDR = If[$OperatingSystem === "Windows", 4, 16^^0002];


(* TCP options (IPPROTO_TCP level) *)
SOCKET`TCPNODELAY::usage = "TCP_NODELAY - disable Nagle algorithm";
SOCKET`TCPNODELAY = 16^^0001;


SOCKET`TCPKEEPIDLE::usage = "TCP_KEEPIDLE - idle time before keep-alive probes";
SOCKET`TCPKEEPIDLE = If[$OperatingSystem === "MacOSX", 16^^0010, 16^^0004];

SOCKET`TCPKEEPINTVL::usage = "TCP_KEEPINTVL - interval between keep-alive probes";
SOCKET`TCPKEEPINTVL = If[$OperatingSystem === "MacOSX", 16^^0011, 16^^0005];

SOCKET`TCPKEEPCNT::usage = "TCP_KEEPCNT - number of keep-alive probes before drop";
SOCKET`TCPKEEPCNT = If[$OperatingSystem === "MacOSX", 16^^0012, 16^^0006];


(* IPv4 options (IPPROTO_IP level) *)
SOCKET`IPTTL::usage = "IP_TTL - time-to-live for packets";
SOCKET`IPTTL = 16^^0004;


SOCKET`IPTOS::usage = "IP_TOS - type of service / DSCP";
SOCKET`IPTOS = 16^^0001;


SOCKET`IPMTUDISCOVER::usage = "IP_MTU_DISCOVER - path MTU discovery";
SOCKET`IPMTUDISCOVER = 16^^000A;


(* IPv6 options (IPPROTO_IPV6 level) *)
SOCKET`IPV6V6ONLY::usage = "IPV6_V6ONLY - restrict socket to IPv6 only";
SOCKET`IPV6V6ONLY = If[$OperatingSystem === "Windows", 27, 16^^001A];


(* Address families *)
SOCKET`AFINET::usage = "AF_INET - IPv4 address family";
SOCKET`AFINET = 16^^0002;


SOCKET`AFINET6::usage = "AF_INET6 - IPv6 address family";
SOCKET`AFINET6 = 16^^000A;


(* Socket types *)
SOCKET`SOCKSTREAM::usage = "SOCK_STREAM - reliable stream socket (TCP)";
SOCKET`SOCKSTREAM = 16^^0001;


SOCKET`SOCKDGRAM::usage = "SOCK_DGRAM - datagram socket (UDP)";
SOCKET`SOCKDGRAM = 16^^0002;


(* Windows-specific *)
SOCKET`SOEXCLUSIVEADDRUSE::usage = "SO_EXCLUSIVEADDRUSE - exclusive address binding (Windows only)";
SOCKET`SOEXCLUSIVEADDRUSE = If[$OperatingSystem === "Windows", 16^^0001, -5];


EndPackage[];