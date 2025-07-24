# 📁 Project Structure & Architecture

## Directory Tree with Descriptions

```
yet-another-bench-script/
│
├── 📄 yabs.sh                    # Original YABS benchmark script (system/CPU/disk/network)
├── 📄 yabs_extended.sh           # Wrapper that combines YABS + extended network tests
├── 📄 README.md                  # Main documentation (user-facing)
├── 📄 LICENSE                    # Project license
├── 📄 .gitignore                 # Git ignore rules
│
├── 📁 scripts/                   # All executable scripts organized by function
│   ├── 📁 core/                  # Main test scripts (the workhorses)
│   │   ├── 📄 network_performance_test.sh   # Ping, traceroute, iperf3 tests
│   │   ├── 📄 dns_performance_test.sh       # DNS query performance testing
│   │   ├── 📄 data_transfer_test.sh         # File transfer speed tests
│   │   └── 📄 performance_test_suite.sh     # Master orchestrator script
│   │
│   ├── 📁 setup/                 # Installation and setup scripts
│   │   ├── 📄 README.md          # Setup overview and guide
│   │   ├── 📁 client/            # For machines running tests
│   │   │   ├── 📄 README.md      
│   │   │   ├── 📄 setup_client.sh          # Cross-platform client setup
│   │   │   └── 📄 setup_macos_local.sh     # macOS-specific optimizations
│   │   ├── 📁 server/            # For test target machines
│   │   │   ├── 📄 README.md
│   │   │   ├── 📄 setup_server.sh          # General server setup (iperf3, nginx)
│   │   │   └── 📄 setup_ssh_zorin.sh       # Zorin/Ubuntu VM specific
│   │   └── 📁 environment/       # Complete environment setup
│   │       ├── 📄 README.md
│   │       └── 📄 setup_environment.sh     # All-in-one setup script
│   │
│   ├── 📁 utils/                 # Utility and helper scripts
│   │   ├── 📄 check_dependencies.sh        # Verify all tools installed
│   │   ├── 📄 quick_test.sh                # Quick environment verification
│   │   ├── 📄 cleanup_and_verify.sh        # Clean old results, verify setup
│   │   ├── 📄 sync_to_zorin.sh             # Sync files to test server
│   │   ├── 📄 process_results.py           # Parse and compare test results
│   │   └── 📄 visualize_results.py         # Create charts from results
│   │
│   └── 📄 healthcheck.sh         # System health monitoring
│
├── 📁 configs/                   # Configuration files
│   ├── 📄 test_config_template.conf        # Template configuration
│   └── 📄 test_config.conf                 # Active configuration (gitignored)
│
├── 📁 lib/                       # Shared libraries
│   └── 📄 common_functions.sh              # Shared bash functions (colors, validation, etc.)
│
├── 📁 docs/                      # Detailed documentation
│   ├── 📄 PROJECT_STRUCTURE.md   # This file
│   ├── 📄 CLAUDE.md              # Development notes and objectives
│   ├── 📄 README.md              # Original detailed user guide
│   ├── 📄 README_INTEGRATION.md  # YABS integration details
│   └── 📄 INSTALL.md             # Installation guide
│
├── 📁 systemd/                   # Linux service files
│   ├── 📄 yabs-healthcheck.service
│   ├── 📄 yabs-healthcheck.timer
│   ├── 📄 yabs-monitor.service
│   └── 📄 yabs-monitor.timer
│
└── 📁 results/                   # Test results (gitignored)
    ├── 📁 test_results_*/        # Complete test suite results
    ├── 📁 benchmark_results_*/   # YABS extended results
    ├── 📁 network_test_results/  # Network test outputs
    ├── 📁 dns_test_results/      # DNS test outputs
    └── 📁 data_transfer_results/ # Transfer test outputs
```

## 🔄 Process Flow Diagram

### Main Test Flow
```
┌─────────────────────┐
│   User Runs Test    │
│ (yabs_extended.sh)  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Parse Arguments    │
│  -Y, -N, -D, -T     │
└──────────┬──────────┘
           │
    ┌──────┴──────┬──────────┬────────────┐
    ▼             ▼          ▼            ▼
┌────────┐  ┌──────────┐ ┌────────┐ ┌──────────┐
│  YABS  │  │ Network  │ │  DNS   │ │ Transfer │
│  Test  │  │  Tests   │ │ Tests  │ │  Tests   │
└────┬───┘  └────┬─────┘ └────┬───┘ └────┬─────┘
     │           │             │           │
     └───────────┴─────────────┴───────────┘
                        │
                        ▼
              ┌─────────────────┐
              │ Collect Results │
              │   (JSON/TXT)    │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │ Generate Report │
              │   (summary.txt) │
              └─────────────────┘
```

### Performance Test Suite Flow
```
┌──────────────────────────┐
│ performance_test_suite.sh │
└────────────┬─────────────┘
             │
             ▼
      ┌──────────────┐
      │ Load Config  │
      │   (if any)   │
      └──────┬───────┘
             │
      ┌──────▼───────┐
      │ Check Phase  │
      │ (pre/post)   │
      └──────┬───────┘
             │
    ┌────────┴────────┐
    │ Create Results  │
    │   Directory     │
    └────────┬────────┘
             │
    ┌────────▼────────┬────────────┬─────────────┐
    ▼                 ▼            ▼             ▼
┌────────┐     ┌──────────┐  ┌─────────┐  ┌──────────┐
│  YABS  │     │ Network  │  │   DNS   │  │ Transfer │
│  -j    │     │ -t all   │  │ -s 8.8  │  │ -t wget  │
└────┬───┘     └────┬─────┘  └────┬────┘  └────┬─────┘
     │              │              │             │
     └──────────────┴──────────────┴─────────────┘
                           │
                    ┌──────▼──────┐
                    │   Summary   │
                    │   Report    │
                    └─────────────┘
```

### Setup Process Flow
```
┌─────────────────┐
│  New User/Dev   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ Need to run     │     │ Need test       │
│ tests?          │     │ server?         │
└────────┬────────┘     └────────┬────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│ Client Setup    │     │ Server Setup    │
│ scripts/setup/  │     │ scripts/setup/  │
│ client/         │     │ server/         │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     │
                     ▼
            ┌─────────────────┐
            │ Run Tests       │
            │ scripts/core/*  │
            └────────┬────────┘
                     │
                     ▼
            ┌─────────────────┐
            │ Analyze Results │
            │ scripts/utils/* │
            └─────────────────┘
```

## 🎯 Quick Reference: What to Modify

### Want to add a new test type?
1. Create new script in `scripts/core/`
2. Update `yabs_extended.sh` to call it
3. Update `performance_test_suite.sh` to include it

### Want to change test parameters?
1. Edit `configs/test_config_template.conf`
2. Or modify defaults in individual test scripts

### Want to add new setup steps?
1. Add to appropriate script in `scripts/setup/`
2. Update `check_dependencies.sh` if new tools needed

### Want to customize output format?
1. Modify JSON generation in test scripts
2. Update `process_results.py` to parse new format

### Want to add new analysis?
1. Create new script in `scripts/utils/`
2. Or extend `visualize_results.py`

## 📊 Data Flow

```
Test Scripts → JSON/TXT files → results/* directories
                                    ↓
                              process_results.py
                                    ↓
                              comparison CSV
                                    ↓
                              visualize_results.py
                                    ↓
                              Charts/Graphs
```

## 🔧 Key Variables & Paths

All scripts use these common variables:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"  # Adjust based on depth

# Common paths:
$PROJECT_ROOT/lib/common_functions.sh    # Shared functions
$PROJECT_ROOT/results/                   # All test outputs
$PROJECT_ROOT/configs/                   # Configuration files
$PROJECT_ROOT/scripts/core/              # Main test scripts
```

## 🚀 Common Tasks

### Run a complete test
```bash
./scripts/core/performance_test_suite.sh -p pre
```

### Run only network tests
```bash
./yabs_extended.sh -Y    # Skip YABS
```

### Quick environment check
```bash
./scripts/utils/quick_test.sh
```

### Check what's missing
```bash
./scripts/utils/check_dependencies.sh
```

### Clean old results
```bash
rm -rf results/test_results_*
```

## 📝 Notes for Developers

1. **Always source common_functions.sh** for consistent output formatting
2. **Use PROJECT_ROOT** for reliable path resolution
3. **Output JSON** for automated processing
4. **Check dependencies** before using tools
5. **Use proper exit codes** (0 for success, non-zero for errors)
6. **Follow naming convention**: `{phase}_{test}_{target}_{timestamp}.{ext}`

---

This structure is designed for clarity, modularity, and easy extension. Each component has a single responsibility and clear interfaces with other components.