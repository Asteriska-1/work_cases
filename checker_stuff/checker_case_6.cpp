#include <fstream>
#include <iostream>
#include <string>

#ifdef USE_VMP
#include "VMProtectSDK.h"
#else
#define VMProtectBeginUltra(x)
#define VMProtectEnd()
static const char *VMProtectDecryptStringA(const char *value) { return value; }
static bool VMProtectFreeString(const void *) { return true; }
#endif

struct CheckResult {
    bool yara_payload_event_found;
    bool reverse_shell_termination_found;
};

static std::string make_string(const char *value) {
    std::string result = value ? value : "";
    VMProtectFreeString(value);
    return result;
}

static std::string agent_log_path() {
    VMProtectBeginUltra("agent_log_path");

    std::string value = make_string(
        VMProtectDecryptStringA("/opt/vxagent/logs/agent.log")
    );

    VMProtectEnd();
    return value;
}

static std::string success_token() {
    VMProtectBeginUltra("success_token");

    std::string value = make_string(
        VMProtectDecryptStringA("9b00fe9b1b30be61594219b4c83bc4b8")
    );

    VMProtectEnd();
    return value;
}

static bool line_contains_yara_payload_event(const std::string &line) {
    VMProtectBeginUltra("line_contains_yara_payload_event");

    const std::string marker_payload = make_string(
        VMProtectDecryptStringA("payload")
    );

    const std::string marker_module_name = make_string(
        VMProtectDecryptStringA("module_name=yara_scanner")
    );

    bool result = line.find(marker_payload) != std::string::npos
        && line.find(marker_module_name) != std::string::npos;

    VMProtectEnd();
    return result;
}

static bool line_contains_reverse_shell_termination_event(const std::string &line) {
    VMProtectBeginUltra("line_contains_reverse_shell_termination_event");

    const std::string marker_action = make_string(
        VMProtectDecryptStringA("pt_kill_object_process_tree_by_name_and_id input config")
    );

    const std::string marker_process_name = make_string(
        VMProtectDecryptStringA("name - bash")
    );

    const std::string marker_module_name = make_string(
        VMProtectDecryptStringA("module_name=proc_terminator")
    );

    bool result = line.find(marker_action) != std::string::npos
        && line.find(marker_process_name) != std::string::npos
        && line.find(marker_module_name) != std::string::npos;

    VMProtectEnd();
    return result;
}

static CheckResult scan_agent_log() {
    VMProtectBeginUltra("scan_agent_log");

    CheckResult result{};
    result.yara_payload_event_found = false;
    result.reverse_shell_termination_found = false;

    const std::string path = agent_log_path();
    std::ifstream log_file(path);

    if (!log_file.is_open()) {
        std::cerr
            << make_string(VMProtectDecryptStringA("ERROR: cannot open "))
            << path
            << std::endl;

        VMProtectEnd();
        return result;
    }

    std::string line;

    while (std::getline(log_file, line)) {
        if (!result.yara_payload_event_found
            && line_contains_yara_payload_event(line)) {
            result.yara_payload_event_found = true;
        }

        if (!result.reverse_shell_termination_found
            && line_contains_reverse_shell_termination_event(line)) {
            result.reverse_shell_termination_found = true;
        }

        if (result.yara_payload_event_found
            && result.reverse_shell_termination_found) {
            break;
        }
    }

    VMProtectEnd();
    return result;
}

int main() {
    VMProtectBeginUltra("main");

    CheckResult result = scan_agent_log();

    if (!result.yara_payload_event_found) {
        std::cerr
            << make_string(VMProtectDecryptStringA("ERROR: YARA payload event was not found"))
            << std::endl;

        VMProtectEnd();
        return 1;
    }

    if (!result.reverse_shell_termination_found) {
        std::cerr
            << make_string(VMProtectDecryptStringA("ERROR: reverse shell termination event was not found"))
            << std::endl;

        VMProtectEnd();
        return 1;
    }

    std::cout << success_token() << std::endl;

    VMProtectEnd();
    return 0;
}