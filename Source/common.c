#include "common.h"

Mutex globalMutex = MUTEX_INITIALIZER;

char* getCurrentTime() {
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

void* getFuncByName(const char *funcName) {
    #ifdef _WIN32
        HMODULE hModule = GetModuleHandle(NULL);
        return (void*)GetProcAddress(hModule, funcName);
    #else
        void* handle = RTLD_DEFAULT;
        return dlsym(handle, funcName);
    #endif
}

void initGlobalMutex() {
    #if defined(_WIN32)
        globalMutex = CreateMutex(NULL, FALSE, NULL);
    #else
        pthread_mutex_init(&globalMutex, NULL);
    #endif
}

void closeGlobalMutex() {
    #if defined(_WIN32)
    CloseHandle(globalMutex);
    #else
    pthread_mutex_destroy(&globalMutex);
    #endif
}

void lockGlobalMutex() {
    #if defined(_WIN32)
        WaitForSingleObject(globalMutex, INFINITE);
    #else
        pthread_mutex_lock(&globalMutex);
    #endif
}

void unlockGlobalMutex() {
    #if defined(_WIN32) || defined(_WIN64)
        ReleaseMutex(globalMutex);
    #else
        pthread_mutex_unlock(&globalMutex);
    #endif
}

void initWSA() {
    #ifdef _WIN32
    int iResult;
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2,2), &wsaData);
    #endif
}

void cleanupWSA() {
    #ifdef _WIN32
    WSACleanup();
    #else
    sleep(1);
    #endif
}

int setBlockingMode(SOCKET socketId, bool blockingMode) {
    #ifdef _WIN32
    u_long mode = blockingMode ? 0 : 1; // 0 for blocking, 1 for non-blocking
    return ioctlsocket(socketId, FIONBIO, &mode);
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    if (blockingMode) {
        return fcntl(socketId, F_SETFL, flags & ~O_NONBLOCK);
    } else {
        return fcntl(socketId, F_SETFL, flags | O_NONBLOCK);
    }
    #endif
}

bool blockingModeQ(SOCKET socketId) {
    #ifdef _WIN32
    u_long mode;
    ioctlsocket(socketId, FIONBIO, &mode);
    return (mode == 0); // 0 - blocking, 1 - non blocking
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    return !(flags & O_NONBLOCK);
    #endif
}

bool socketValidQ(SOCKET socketId) {
    if (socketId == INVALID_SOCKET) {
        return false;
    }

    #ifdef _WIN32
    int opt = 0;
    int len = sizeof(opt);
    int result = getsockopt(socketId, SOL_SOCKET, SO_TYPE, (char*)&opt, &len);

    if (result == 0) {
        return true;
    }

    int err = WSAGetLastError();
    return err != WSAENOTSOCK;

    #else
    int result = fcntl(socketId, F_GETFL);
    return result >= 0 || errno != EBADF;
    #endif
}

struct timeval new_tv(long long usec) {
    struct timeval tv = {
        .tv_sec = usec / USEC_PER_SEC,
        .tv_usec = usec % USEC_PER_SEC
    };
    return tv;
}

size_t filterFdsetToArray(fd_set *set, SOCKET *input, SOCKET *result, size_t length) {
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

size_t filterFdsetToTensor(WolframLibraryData libData, fd_set *set, SOCKET *input, MTensor *result, size_t length) {
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

SOCKET fillFdsetFromArray(fd_set *set, SOCKET *sockets, size_t length, SOCKET initmaxfd) {
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

void copyTensorToSocketArray(WolframLibraryData libData, MTensor tensor, SOCKET *result, size_t length) {
    mint *data = libData->MTensor_getIntegerData(tensor);
    for (size_t i = 0; i < length; i++) {
        result[i] = (SOCKET)data[i];
    }
}