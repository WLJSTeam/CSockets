#include "address.h"

/*socketAddressInfoCreate["host", "port", family, socktype, protocol] -> addressInfoPtr*/
DLLEXPORT int socketAddressInfoCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    char *host = MArgument_getUTF8String(Args[0]); // localhost by default
    char *port = MArgument_getUTF8String(Args[1]); // positive integer as string

    int ai_family = (int)MArgument_getInteger(Args[2]); // AF_UNSPEC == 0 | AF_INET == 2 | AF_INET6 == 23/10 | ..
    int ai_socktype = (int)MArgument_getInteger(Args[3]); // SOCK_STREAM == 1 | SOCK_DGRAM == 2 | SOCK_RAW == 3 | ..
    int ai_protocol = (int)MArgument_getInteger(Args[4]); // 0 | IPPROTO_TCP == 6 | IPPROTO_UDP == 17 | IPPROTO_SCTP == 132 | IPPROTO_ICMP == 1 | ..

    int result;
    struct addrinfo *address = NULL;
    struct addrinfo hints;

    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = ai_family;
    hints.ai_socktype = ai_socktype;
    hints.ai_protocol = ai_protocol;

    result = getaddrinfo(host, port, &hints, &address);
    if (result != 0) {
        libData->UTF8String_disown(host);
        libData->UTF8String_disown(port);
        return LIBRARY_FUNCTION_ERROR;
    }

    libData->UTF8String_disown(host);
    libData->UTF8String_disown(port);

    uintptr_t addressPtr = (uintptr_t)address;
    MArgument_setInteger(Res, (mint)addressPtr);
    return LIBRARY_NO_ERROR;
}

/*socketAddressInfoRemove[addressPtr] -> successStatus*/
DLLEXPORT int socketAddressInfoRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    uintptr_t addressPtr = (uintptr_t)MArgument_getInteger(Args[0]); // address pointer as integer
    struct addrinfo *address = (struct addrinfo*)addressPtr;

    if (address == NULL) {
        MArgument_setInteger(Res, 1); // failure
        return LIBRARY_FUNCTION_ERROR;
    }

    freeaddrinfo(address);
    MArgument_setInteger(Res, 0); // success
    return LIBRARY_NO_ERROR;
}

/*socketAddressCreate[addressType] -> addressPtr*/
DLLEXPORT int socketAddressCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    mint addressType = MArgument_getInteger(Args[0]); // 4=IPv4, 6=IPv6, 1=Unix, 0=Unspec

    void *address = NULL;
    size_t size = 0;

    switch(addressType) {
        case 4: // IPv4
            size = sizeof(struct sockaddr_in);
            address = malloc(size);
            if (address) {
                struct sockaddr_in *addr = (struct sockaddr_in*)address;
                addr->sin_family = AF_INET;
                addr->sin_port = 0; // port will set after
                addr->sin_addr.s_addr = INADDR_ANY;
            }
            else {
                return LIBRARY_FUNCTION_ERROR;
            }
            break;

        case 6: // IPv6
            size = sizeof(struct sockaddr_in6);
            address = malloc(size);
            if (address) {
                struct sockaddr_in6 *addr = (struct sockaddr_in6*)address;
                addr->sin6_family = AF_INET6;
                addr->sin6_port = 0;
                addr->sin6_addr = in6addr_any;
            }
            else {
                return LIBRARY_FUNCTION_ERROR;
            }
            break;

        default:
            return LIBRARY_FUNCTION_ERROR;
    }

    if (!address) return LIBRARY_FUNCTION_ERROR;

    memset(address, 0, size);

    uintptr_t ptr = (uintptr_t)address;
    MArgument_setInteger(Res, (mint)ptr);
    return LIBRARY_NO_ERROR;
}

/*socketAddressRemove[addressPtr] -> successStatus*/
DLLEXPORT int socketAddressRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    uintptr_t ptr = (uintptr_t)MArgument_getInteger(Args[0]);
    struct sockaddr_in *address = (struct sockaddr_in *)ptr;

    free(address);
    MArgument_setInteger(Res, 0);
    return LIBRARY_NO_ERROR;
}