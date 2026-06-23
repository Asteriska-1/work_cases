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

static std::string galf() {
    VMProtectBeginUltra("galf");

    std::string value = make_string(
        VMProtectDecryptStringA("f64c7159d13fa2c81d2510c37e522a64")
    );

    VMProtectEnd();
    return value;
}

static bool line_contains_all_required_markers(const std::string &line) {
    VMProtectBeginUltra("line_contains_all_required_markers");

    const std::string marker_process_tree = make_string(
        VMProtectDecryptStringA("pt_kill_object_process_tree_by_name_and_id input config")
    );

    const std::string marker_process_name = make_string(
        VMProtectDecryptStringA("name - bettercap")
    );

    const std::string marker_module_name = make_string(
        VMProtectDecryptStringA("module_name=proc_terminator")
    );

    bool result = line.find(marker_process_tree) != std::string::npos
        && line.find(marker_process_name) != std::string::npos
        && line.find(marker_module_name) != std::string::npos;

    VMProtectEnd();
    return result;
}

static bool bettercap_was_terminated_by_edr() {
    VMProtectBeginUltra("bettercap_was_terminated_by_edr");

    const std::string path = agent_log_path();
    std::ifstream log_file(path);

    if (!log_file.is_open()) {
        std::cerr
            << make_string(VMProtectDecryptStringA("ERROR: cannot open "))
            << path
            << std::endl;

        VMProtectEnd();
        return false;
    }

    std::string line;

    while (std::getline(log_file, line)) {
        if (line_contains_all_required_markers(line)) {
            VMProtectEnd();
            return true;
        }
    }

    VMProtectEnd();
    return false;
}

int main() {
    VMProtectBeginUltra("main");

    if (!bettercap_was_terminated_by_edr()) {
        std::cerr
            << make_string(VMProtectDecryptStringA("ERROR: EDR response event for bettercap was not found"))
            << std::endl;

        VMProtectEnd();
        return 1;
    }

    std::cout << galf() << std::endl;

    VMProtectEnd();
    return 0;
}