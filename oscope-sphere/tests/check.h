#pragma once
#include <cstdio>

inline int g_checks = 0;
inline int g_fails  = 0;

#define CHECK(cond)                                                       \
    do {                                                                  \
        ++g_checks;                                                       \
        if (!(cond)) {                                                    \
            ++g_fails;                                                    \
            std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);    \
        }                                                                 \
    } while (0)

#define REPORT()                                                          \
    do {                                                                  \
        std::printf("%d/%d checks passed\n", g_checks - g_fails, g_checks);\
        return g_fails ? 1 : 0;                                           \
    } while (0)
