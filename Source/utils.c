#include "header.h"

const char* getCurrentTime()
{
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
             ".%06ld", tv.tv_usec);
    #endif

    return time_buffer;
}

Mutex mutexCreate()
{
    #if defined(_WIN32) || defined(_WIN64)
        return CreateMutex(NULL, FALSE, NULL);
    #else
        pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
        return mutex;
    #endif
}

void mutexClose(Mutex mutex)
{
    #if defined(_WIN32) || defined(_WIN64)
        CloseHandle(mutex);
    #else
        pthread_mutex_destroy(&mutex);
    #endif
}

void mutexLock(Mutex mutex)
{
    #if defined(_WIN32) || defined(_WIN64)
        WaitForSingleObject(mutex, INFINITE);
    #else
        pthread_mutex_lock(&mutex);
    #endif
}

void mutexUnlock(Mutex mutex)
{
    #if defined(_WIN32) || defined(_WIN64)
        ReleaseMutex(mutex);
    #else
        pthread_mutex_unlock(&mutex);
    #endif
}

const void setBlocking(SOCKET socket, bool blocking)
{
    #ifdef _WIN32
    u_long mode = blocking ? 0 : 1; // 0 for blocking, 1 for non-blocking
    ioctlsocket(socket, FIONBIO, &mode);
    #else
    int flags = fcntl(socket, F_GETFL, 0);
    if (blocking) {
        fcntl(socket, F_SETFL, flags & ~O_NONBLOCK);
    } else {
        fcntl(socket, F_SETFL, flags | O_NONBLOCK);
    }
    #endif
}

const bool blockingModeQ(SOCKET socketId)
{
    #ifdef _WIN32
    u_long mode;
    ioctlsocket(socketId, FIONBIO, &mode);
    return (mode == 0);
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    return !(flags & O_NONBLOCK);
    #endif
}