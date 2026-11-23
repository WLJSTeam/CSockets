#include "common.h"


/* Constructors copy input data. NULL indicates invalid input or allocation failure. */
MNumericArray MNumericArrayFromByte(WolframLibraryData libData, const BYTE *bytes, size_t length)
{
    if (length > (size_t)(SIZE_MAX >> 1) || (length > 0 && !bytes)) {
        return NULL;
    }

    mint dimension = (mint)length;
    MNumericArray array = NULL;
    int status = libData->numericarrayLibraryFunctions->MNumericArray_new(
        MNumericArray_Type_UBit8, 1, &dimension, &array);

    if (status != LIBRARY_NO_ERROR) {
        return NULL;
    }

    if (length > 0) {
        void *data = libData->numericarrayLibraryFunctions->MNumericArray_getData(array);
        memcpy(data, bytes, length);
    }

    return array;
}


/* Borrowed storage: valid until the array is freed/disowned; never free this pointer. */
BYTE *ByteFromMNumericArray(WolframLibraryData libData, MNumericArray array, size_t *length)
{
    *length = 0;

    if (!array) {
        return NULL;
    }

    numericarray_data_t type = libData->numericarrayLibraryFunctions->MNumericArray_getType(array);
    mint rank = libData->numericarrayLibraryFunctions->MNumericArray_getRank(array);

    if (type != MNumericArray_Type_UBit8 || rank != 1) {
        return NULL;
    }

    *length = (size_t)libData->numericarrayLibraryFunctions->MNumericArray_getFlattenedLength(array);
    return libData->numericarrayLibraryFunctions->MNumericArray_getData(array);
}


MTensor MTensorFromSocket(WolframLibraryData libData, const SOCKET *sockets, size_t length)
{
    if (length > (size_t)(SIZE_MAX >> 1) || (length > 0 && !sockets)) {
        return NULL;
    }

    mint dimension = (mint)length;
    MTensor tensor = NULL;
    int status = libData->MTensor_new(MType_Integer, 1, &dimension, &tensor);

    if (status != LIBRARY_NO_ERROR) {
        return NULL;
    }

    mint *data = libData->MTensor_getIntegerData(tensor);

    for (size_t i = 0; i < length; i++) {
        data[i] = (mint)sockets[i];
    }

    return tensor;
}


/* Copies descriptors, converting element widths; caller must free the result. */
SOCKET *SocketFromMTensor(WolframLibraryData libData, MTensor tensor, size_t *length)
{
    *length = 0;

    if (!tensor) {
        return NULL;
    }

    mint type = libData->MTensor_getType(tensor);
    mint rank = libData->MTensor_getRank(tensor);
    mint count = libData->MTensor_getFlattenedLength(tensor);

    if (type != MType_Integer || rank != 1 || count < 0 || (size_t)count > SIZE_MAX / sizeof(SOCKET)) {
        return NULL;
    }

    SOCKET *sockets = malloc(count > 0 ? (size_t)count * sizeof(SOCKET) : sizeof(SOCKET));

    if (!sockets) {
        return NULL;
    }

    const mint *data = libData->MTensor_getIntegerData(tensor);

    for (mint i = 0; i < count; i++) {
        sockets[i] = (SOCKET)data[i];
    }

    *length = (size_t)count;
    return sockets;
}


char *format(const char *fmt, ...)
{
    static char buffer[32];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buffer, sizeof(buffer), fmt, args);
    va_end(args);
    return buffer;
}


void print(const char* format, ...)
{
    #ifdef _DEBUG
    fprintf(stderr, "[%s] ", get_current_time());
    va_list args;
    va_start(args, format);

    vprintf(format, args);
    printf("\n");

    va_end(args);
    #endif
}


char* get_current_time()
{
    static char time_buffer[64];
    time_t rawtime;
    struct tm timeinfo;

    time(&rawtime);
#ifdef _WIN32
    localtime_s(&timeinfo, &rawtime);
#else
    localtime_r(&rawtime, &timeinfo);
#endif

    strftime(time_buffer, sizeof(time_buffer), "%Y-%m-%d %H:%M:%S", &timeinfo);

    #ifdef _WIN32
    SYSTEMTIME st;
    GetSystemTime(&st);
    snprintf(time_buffer + strlen(time_buffer),
             sizeof(time_buffer) - strlen(time_buffer),
             ".%03d", st.wMilliseconds);
    #else
    struct timeval tv;
    gettimeofday(&tv, NULL);
    snprintf(time_buffer + strlen(time_buffer),
             sizeof(time_buffer) - strlen(time_buffer),
             ".%06ld", (long)(tv.tv_usec));
    #endif

    return time_buffer;
}


void init_wsa()
 {
    #ifdef _WIN32
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2,2), &wsaData);
    #endif
}


void cleanup_wsa()
{
    #ifdef _WIN32
    WSACleanup();
    #else
    sleep(1);
    #endif
}


void set_blocking_mode(SOCKET socketId)
{
    #ifdef _WIN32
    u_long mode = 0;
    ioctlsocket(socketId, FIONBIO, &mode);
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    fcntl(socketId, F_SETFL, flags & ~O_NONBLOCK);
    #endif
}


void set_nonblocking_mode(SOCKET socketId)
{
    #ifdef _WIN32
    u_long mode = 1;
    ioctlsocket(socketId, FIONBIO, &mode);
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    fcntl(socketId, F_SETFL, flags | O_NONBLOCK);
    #endif
}


bool is_would_block_err(int err)
{
    #ifdef _WIN32
    return err == WSAEWOULDBLOCK;
    #else
    return err == EAGAIN || err == EWOULDBLOCK;
    #endif
}


bool is_connect_pending_err(int err)
{
    #ifdef _WIN32
    return err == WSAEWOULDBLOCK || err == WSAEINPROGRESS || err == WSAEALREADY;
    #else
    return err == EINPROGRESS || err == EALREADY;
    #endif
}


// Wrapper for poll/WSAPoll to handle timeout conversion and platform differences
// timeout_us: -1 for infinite, 0 for non-blocking, >0 for timeout in microseconds
// returns: number of fds with events, 0 for timeout, -1 for error
int sockets_poll(POLL_FD *fds, mint length, mint timeout_us)
{
    if (length < 0 || length > INT_MAX || timeout_us < -1) return -1;
    mint milliseconds = timeout_us < 0 ? -1 : timeout_us / 1000 + (timeout_us % 1000 != 0);
    int timeout_ms = milliseconds > INT_MAX ? INT_MAX : (int)milliseconds;
    if (length == 0) {
#ifdef _WIN32
        Sleep(timeout_ms < 0 ? INFINITE : (DWORD)timeout_ms);
        return 0;
#else
        return poll(NULL, 0, timeout_ms);
#endif
    }

    #ifdef _WIN32
        int result = WSAPoll(fds, (int)length, timeout_ms);
    #else
        int result = poll(fds, (nfds_t)length, timeout_ms);
    #endif

    return result;
}


int convert_wl_to_native_events(mint wl_events)
{
    int native = 0;

    #ifdef _WIN32
        if (wl_events & WL_POLLIN)   native |= POLLRDNORM;
        if (wl_events & WL_POLLOUT)  native |= POLLWRNORM;
        if (wl_events & WL_POLLERR)  native |= POLLERR;
        if (wl_events & WL_POLLHUP)  native |= POLLHUP;
        if (wl_events & WL_POLLNVAL) native |= POLLNVAL;
    #else
        if (wl_events & WL_POLLIN)   native |= POLLIN;
        if (wl_events & WL_POLLOUT)  native |= POLLOUT;
        if (wl_events & WL_POLLERR)  native |= POLLERR;
        if (wl_events & WL_POLLHUP)  native |= POLLHUP;
        if (wl_events & WL_POLLNVAL) native |= POLLNVAL;
    #endif

    return native;
}


mint convert_native_to_wl_events(int native_revents)
{
    mint wl = 0;

    #ifdef _WIN32
        if (native_revents & POLLRDNORM) wl |= WL_POLLIN;
        if (native_revents & POLLWRNORM) wl |= WL_POLLOUT;
        if (native_revents & POLLERR)    wl |= WL_POLLERR;
        if (native_revents & POLLHUP)    wl |= WL_POLLHUP;
        if (native_revents & POLLNVAL)   wl |= WL_POLLNVAL;
    #else
        if (native_revents & POLLIN)     wl |= WL_POLLIN;
        if (native_revents & POLLOUT)    wl |= WL_POLLOUT;
        if (native_revents & POLLERR)    wl |= WL_POLLERR;
        if (native_revents & POLLHUP)    wl |= WL_POLLHUP;
        if (native_revents & POLLNVAL)   wl |= WL_POLLNVAL;
    #endif

    return wl;
}


int socket_address_from_host(const char *host, unsigned short port, struct sockaddr_storage *address, socklen_t *addressLength)
{
    memset(address, 0, sizeof(*address));

    struct sockaddr_in *ipv4 = (struct sockaddr_in *)address;
    if (inet_pton(AF_INET, host, &ipv4->sin_addr) == 1)
    {
        ipv4->sin_family = AF_INET;
        ipv4->sin_port = htons(port);
        *addressLength = sizeof(*ipv4);
        return 1;
    }

    struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)address;
    if (inet_pton(AF_INET6, host, &ipv6->sin6_addr) == 1)
    {
        ipv6->sin6_family = AF_INET6;
        ipv6->sin6_port = htons(port);
        *addressLength = sizeof(*ipv6);
        return 1;
    }

    return 0;
}


int socket_address_to_host(const struct sockaddr_storage *address, char *host, size_t hostLength, unsigned short *port)
{
    switch (address->ss_family)
    {
        case AF_INET:
        {
            const struct sockaddr_in *ipv4 =
                (const struct sockaddr_in *)address;

            if (inet_ntop(
                    AF_INET,
                    &ipv4->sin_addr,
                    host,
                    (socklen_t)hostLength) == NULL)
            {
                return 0;
            }

            *port = ntohs(ipv4->sin_port);
            return 1;
        }

        case AF_INET6:
        {
            const struct sockaddr_in6 *ipv6 =
                (const struct sockaddr_in6 *)address;

            if (inet_ntop(
                    AF_INET6,
                    &ipv6->sin6_addr,
                    host,
                    (socklen_t)hostLength) == NULL)
            {
                return 0;
            }

            *port = ntohs(ipv6->sin6_port);
            return 1;
        }

        default:
            return 0;
    }
}


DLLEXPORT mint WolframLibrary_getVersion()
{
    return WolframLibraryVersion;
}

DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData)
{
    init_wsa();
    return LIBRARY_NO_ERROR;
}

DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData)
{
    cleanup_wsa();
    (void)libData;
}


struct sockaddr_storage create_sockaddr_storage(const char *numerichost, const char *port)
{
    struct sockaddr_storage storage = {0};
    struct addrinfo *address = NULL;
    struct addrinfo hints;
    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = 0;
    hints.ai_protocol = 0;
    hints.ai_flags = AI_NUMERICHOST | AI_NUMERICSERV;

    if (!numerichost || !numerichost[0] || !port || !port[0]) return storage;
    int result = getaddrinfo(numerichost, port, &hints, &address);
    if (result == 0 && address && address->ai_addr && address->ai_addrlen <= sizeof(storage) &&
        (address->ai_family == AF_INET || address->ai_family == AF_INET6)) {
        memcpy(&storage, address->ai_addr, address->ai_addrlen);
    }
    if (address) freeaddrinfo(address);
    return storage;
}


char *sockaddr_storage_to_string(struct sockaddr_storage address)
{
    #ifdef _WIN32
    static __declspec(thread) char endpoint[INET6_ADDRSTRLEN + 32];
    #else
    static _Thread_local char endpoint[INET6_ADDRSTRLEN + 32];
    #endif
    char host[INET6_ADDRSTRLEN];
    unsigned short port;
    if (!socket_address_to_host(&address, host, sizeof(host), &port)) return NULL;

    int length;
    if (address.ss_family == AF_INET6) {
        const struct sockaddr_in6 *ipv6 = (const struct sockaddr_in6 *)&address;
        if (ipv6->sin6_scope_id != 0) {
            length = snprintf(endpoint, sizeof(endpoint), "[%s%%%lu]:%u", host,
                (unsigned long)ipv6->sin6_scope_id, (unsigned int)port);
        } else {
            length = snprintf(endpoint, sizeof(endpoint), "[%s]:%u", host, (unsigned int)port);
        }
    } else {
        length = snprintf(endpoint, sizeof(endpoint), "%s:%u", host, (unsigned int)port);
    }
    if (length < 0 || (size_t)length >= sizeof(endpoint)) return NULL;
    return endpoint;
}
