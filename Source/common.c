#include "common.h"


void print(const char* format, ...)
{
    #ifdef _DEBUG
    fprintf(stderr, "[%s] ", get_current_time());
    va_list args;
    va_start(args, format);

    vprintf(format, args);
    vprintf("\n", args);

    va_end(args);
    #endif
}


char* get_current_time() {
    static char time_buffer[64];
    time_t rawtime;
    struct tm* timeinfo;

    time(&rawtime);
    timeinfo = localtime(&rawtime);

    strftime(time_buffer, sizeof(time_buffer), "%Y-%m-%d %H:%M:%S", timeinfo);

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


void init_wsa() {
    #ifdef _WIN32
    int iResult;
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2,2), &wsaData);
    #endif
}


void cleanup_wsa() {
    #ifdef _WIN32
    WSACleanup();
    #else
    sleep(1);
    #endif
}


void set_blocking_mode(SOCKET socketId) {
    #ifdef _WIN32
    u_long mode = 0;
    ioctlsocket(socketId, FIONBIO, &mode);
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    fcntl(socketId, F_SETFL, flags & ~O_NONBLOCK);
    #endif
}


void set_non_blocking_mode(SOCKET socketId) {
    #ifdef _WIN32
    u_long mode = 1;
    ioctlsocket(socketId, FIONBIO, &mode);
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    fcntl(socketId, F_SETFL, flags | O_NONBLOCK);
    #endif
}


bool is_non_blocking_mode(SOCKET socketId) {
    #ifdef _WIN32
    u_long mode;
    ioctlsocket(socketId, FIONBIO, &mode);
    return mode; // True - blocking, False - non blocking
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    return (flags & O_NONBLOCK);
    #endif
}


bool is_valid_socket(SOCKET socketId) {
    if (socketId == INVALID_SOCKET) {
        return false;
    }

    #ifdef _WIN32
    int opt = 0;
    socklen_t len = sizeof(opt);
    int result = getsockopt(socketId, SOL_SOCKET, SO_TYPE, (char*)&opt, &len);

    if (result == 0) {
        int error = 0;
        len = sizeof(error);
        if (getsockopt(socketId, SOL_SOCKET, SO_ERROR, (char*)&error, &len) == 0) {
            return error == 0;
        }
        return true;
    }

    int err = WSAGetLastError();
    return err != WSAENOTSOCK;

    #else
    int flags = fcntl(socketId, F_GETFL);
    if (flags >= 0) {
        int error = 0;
        socklen_t len = sizeof(error);
        if (getsockopt(socketId, SOL_SOCKET, SO_ERROR, (char*)&error, &len) == 0) {
            return error == 0;
        }
        return true;
    }

    return errno != EBADF;
    #endif
}


struct timeval new_tv(long long usec) {
    struct timeval tv = {
        .tv_sec = usec / USEC_PER_SEC,
        .tv_usec = usec % USEC_PER_SEC
    };
    return tv;
}


size_t filter_fd_set_to_array(fd_set *set, SOCKET *input, SOCKET *result, size_t length) {
    SOCKET socketId;
    size_t j = 0;
    for (size_t i = 0; i < length; i++) {
        socketId = input[i];
        if (FD_ISSET(socketId, set)) {
            result[j] = socketId;
            j++;
        }
    }
    return j;
}


size_t filter_fd_set_to_tensor(WolframLibraryData libData, fd_set *set, SOCKET *input, MTensor result, size_t length) {
    mint *data = libData->MTensor_getIntegerData(result);
    SOCKET socketId;
    size_t j = 0;
    for (size_t i = 0; i < length; i++) {
        socketId = input[i];
        if (FD_ISSET(socketId, set)) {
            data[j] = (mint)socketId;
            j++;
        }
    }
    return j;
}


SOCKET fill_fd_set_from_array(fd_set *set, SOCKET *sockets, size_t length, SOCKET initmaxfd) {
    SOCKET maxfd = initmaxfd;
    SOCKET socketId;

    for (size_t i = 0; i < length; i++) {
        socketId = sockets[i];
        FD_SET(socketId, set);
        if (maxfd < socketId) {
            maxfd = socketId;
        }
    }

    return maxfd;
}


void copy_tensor_to_socket_array(WolframLibraryData libData, MTensor tensor, SOCKET *result, size_t length) {
    mint *data = libData->MTensor_getIntegerData(tensor);
    for (size_t i = 0; i < length; i++) {
        result[i] = (SOCKET)data[i];
    }
}


// Wrapper for poll/WSAPoll to handle timeout conversion and platform differences
// timeout_us: -1 for infinite, 0 for non-blocking, >0 for timeout in microseconds
// returns: number of fds with events, 0 for timeout, -1 for error
int sockets_poll(POLL_FD *fds, mint length, mint timeout_us) {
    int timeout_ms;
    if (timeout_us == -1) {
        timeout_ms = -1;
    } else {
        timeout_ms = (int)(timeout_us / 1000);
        if (timeout_us > 0 && timeout_ms == 0) {
            timeout_ms = 1;  // 1 is min for poll
        }
    }

    #ifdef _WIN32
        int result = WSAPoll(fds, (int)length, timeout_ms);
    #else
        int result = poll(fds, (nfds_t)length, timeout_ms);
    #endif

    return result;
}


int convert_wl_to_native_events(mint wl_events) {
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


mint convert_native_to_wl_events(int native_revents) {
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


DLLEXPORT mint WolframLibrary_getVersion() {
    return WolframLibraryVersion;
}

DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData) {
    init_wsa();
    return LIBRARY_NO_ERROR;
}

DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData) {
    cleanup_wsa();
    (void)libData;
}