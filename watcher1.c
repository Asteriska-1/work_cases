#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#define CASE5_DIR "/run/case5"
#define PID_PATH  "/run/case5/bettercap.pid"
#define INFO_PATH "/run/case5/bettercap.info"

#define EXPECTED_EXE "/usr/bin/bettercap"

static int is_number(const char *s) {
    if (s == NULL || *s == '\0') {
        return 0;
    }

    while (*s) {
        if (!isdigit((unsigned char)*s)) {
            return 0;
        }
        s++;
    }

    return 1;
}

static int read_cmdline(pid_t pid, char *buf, size_t buf_size) {
    char path[PATH_MAX];

    snprintf(path, sizeof(path), "/proc/%d/cmdline", pid);

    FILE *f = fopen(path, "rb");
    if (f == NULL) {
        return -1;
    }

    size_t n = fread(buf, 1, buf_size - 1, f);
    fclose(f);

    if (n == 0) {
        return -1;
    }

    buf[n] = '\0';

    for (size_t i = 0; i < n; i++) {
        if (buf[i] == '\0') {
            buf[i] = ' ';
        }
    }

    return 0;
}

static int read_exe(pid_t pid, char *buf, size_t buf_size) {
    char path[PATH_MAX];

    snprintf(path, sizeof(path), "/proc/%d/exe", pid);

    ssize_t n = readlink(path, buf, buf_size - 1);
    if (n < 0) {
        return -1;
    }

    buf[n] = '\0';
    return 0;
}

static int is_target_bettercap(pid_t pid, char *out_cmdline, size_t out_cmdline_size) {
    char exe[PATH_MAX];
    char cmdline[4096];

    if (read_exe(pid, exe, sizeof(exe)) != 0) {
        return 0;
    }

    if (strcmp(exe, EXPECTED_EXE) != 0) {
        return 0;
    }

    if (read_cmdline(pid, cmdline, sizeof(cmdline)) != 0) {
        return 0;
    }

    if (strstr(cmdline, "bettercap") == NULL) {
        return 0;
    }

    if (strstr(cmdline, "-iface") == NULL) {
        return 0;
    }

    if (strstr(cmdline, "lo") == NULL) {
        return 0;
    }

    snprintf(out_cmdline, out_cmdline_size, "%s", cmdline);
    return 1;
}

static int write_result(pid_t pid, const char *cmdline) {
    mkdir(CASE5_DIR, 0755);

    FILE *pid_file = fopen(PID_PATH, "w");
    if (pid_file == NULL) {
        return -1;
    }

    fprintf(pid_file, "%d\n", pid);
    fclose(pid_file);

    FILE *info_file = fopen(INFO_PATH, "w");
    if (info_file == NULL) {
        return -1;
    }

    fprintf(info_file, "pid=%d\n", pid);
    fprintf(info_file, "exe=%s\n", EXPECTED_EXE);
    fprintf(info_file, "cmdline=%s\n", cmdline);
    fclose(info_file);

    return 0;
}

int main(void) {
    while (1) {
        DIR *proc = opendir("/proc");
        if (proc == NULL) {
            perror("opendir /proc");
            return 1;
        }

        struct dirent *entry;
        while ((entry = readdir(proc)) != NULL) {
            if (!is_number(entry->d_name)) {
                continue;
            }

            pid_t pid = (pid_t)atoi(entry->d_name);
            char cmdline[4096];

            if (is_target_bettercap(pid, cmdline, sizeof(cmdline))) {
                closedir(proc);

                if (write_result(pid, cmdline) != 0) {
                    perror("write result");
                    return 1;
                }

                return 0;
            }
        }

        closedir(proc);
        usleep(200 * 1000);
    }
}
