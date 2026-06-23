#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PID_PATH "/run/case5/bettercap.pid"
#define BPFTRACE_LOG_PATH "/run/case5/bpftrace.log"

#define CASE5_FLAG "f64c7159d13fa2c81d2510c37e522a64"

static int read_bettercap_pid(void) {
    FILE *f = fopen(PID_PATH, "r");
    if (f == NULL) {
        return -1;
    }

    int pid = -1;

    if (fscanf(f, "%d", &pid) != 1) {
        fclose(f);
        return -1;
    }

    fclose(f);
    return pid;
}

static int has_successful_vxagent_kill(int bettercap_pid) {
    FILE *f = fopen(BPFTRACE_LOG_PATH, "r");
    if (f == NULL) {
        return 0;
    }

    char line[1024];
    char target_pid_pattern[64];

    snprintf(target_pid_pattern, sizeof(target_pid_pattern), "target_pid=%d", bettercap_pid);

    while (fgets(line, sizeof(line), f) != NULL) {
        if (strstr(line, "sender=vxagent") == NULL) {
            continue;
        }

        if (strstr(line, target_pid_pattern) == NULL) {
            continue;
        }

        if (strstr(line, "result=0") == NULL) {
            continue;
        }

        if (strstr(line, "sig=9") != NULL || strstr(line, "sig=15") != NULL) {
            fclose(f);
            return 1;
        }
    }

    fclose(f);
    return 0;
}

int main(void) {
    int bettercap_pid = read_bettercap_pid();

    if (bettercap_pid <= 0) {
        fprintf(stderr, "ERROR: bettercap PID was not found\n");
        return 1;
    }

    if (!has_successful_vxagent_kill(bettercap_pid)) {
        fprintf(stderr, "ERROR: vxagent kill event was not found for PID %d\n", bettercap_pid);
        return 1;
    }

    printf("%s\n", CASE5_FLAG);
    return 0;
}
