#!/bin/bash

# SelFlow Complete System Launcher
# This script launches the complete SelFlow system with all components

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[SelFlow]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SelFlow]${NC} ✅ $1"
}

print_warning() {
    echo -e "${YELLOW}[SelFlow]${NC} ⚠️  $1"
}

print_error() {
    echo -e "${RED}[SelFlow]${NC} ❌ $1"
}

print_header() {
    echo -e "${PURPLE}"
    echo "🎭 ======================================================== 🎭"
    echo "                 SelFlow System Launcher"
    echo "🎭 ======================================================== 🎭"
    echo -e "${NC}"
}

# Function to check if virtual environment exists
check_venv() {
    if [ ! -d "selflow_env" ]; then
        print_error "Virtual environment 'selflow_env' not found!"
        print_status "Please create it with: python3 -m venv selflow_env"
        exit 1
    fi
    print_success "Virtual environment found"
}

# Function to activate virtual environment
activate_venv() {
    print_status "Activating virtual environment..."
    source selflow_env/bin/activate
    print_success "Virtual environment activated"
}

# Function to kill existing processes
cleanup_processes() {
    print_status "Cleaning up existing SelFlow processes..."
    pkill -f "selflow|SelFlow|run_selflow|launch_tray" 2>/dev/null || true
    sleep 2
    print_success "Cleanup complete"
}

# Function to check system status
check_system() {
    print_status "Checking system status..."
    
    # Check database
    if [ -f "data/events.db" ]; then
        DB_SIZE=$(du -h data/events.db | cut -f1)
        print_success "Database found: $DB_SIZE"
    else
        print_warning "No database found - will be created"
    fi
    
    # Check if we have agents
    if [ -f "check_agents.py" ]; then
        AGENT_COUNT=$(python3 check_agents.py 2>/dev/null | grep "Agents Born:" | cut -d: -f2 | tr -d ' ' || echo "0")
        if [ "$AGENT_COUNT" != "0" ]; then
            print_success "Found $AGENT_COUNT existing agents"
        else
            print_status "No existing agents - system will birth new ones"
        fi
    fi
}

# Function to start the main system
start_main_system() {
    print_status "Starting main SelFlow system..."
    
    # Create log directory
    mkdir -p logs
    
    # Start main system in background with logging using virtual environment
    nohup bash -c "source selflow_env/bin/activate && python run_selflow_live.py" > logs/selflow_main.log 2>&1 &
    MAIN_PID=$!
    
    print_success "Main system started (PID: $MAIN_PID)"
    
    # Wait a moment for initialization
    sleep 3
    
    # Check if it's still running
    if kill -0 $MAIN_PID 2>/dev/null; then
        print_success "Main system running successfully"
        echo $MAIN_PID > logs/selflow_main.pid
    else
        print_error "Main system failed to start"
        return 1
    fi
}

# Function to start the system tray
start_tray() {
    print_status "Starting system tray..."
    
    # Start tray in background using virtual environment with correct Python path
    nohup bash -c "source selflow_env/bin/activate && PYTHONPATH=$(pwd) python launch_tray.py" > logs/selflow_tray.log 2>&1 &
    TRAY_PID=$!
    
    print_success "System tray started (PID: $TRAY_PID)"
    echo $TRAY_PID > logs/selflow_tray.pid
    
    # Wait a moment
    sleep 2
    
    # Check if it's running
    if kill -0 $TRAY_PID 2>/dev/null; then
        print_success "System tray running - check your menu bar!"
    else
        print_warning "System tray may have failed (check logs/selflow_tray.log)"
    fi
}

# Function to show system status
show_status() {
    print_status "System Status:"
    echo ""
    
    # Check main system
    if [ -f "logs/selflow_main.pid" ]; then
        MAIN_PID=$(cat logs/selflow_main.pid)
        if kill -0 $MAIN_PID 2>/dev/null; then
            print_success "Main System: Running (PID: $MAIN_PID)"
        else
            print_error "Main System: Not running"
        fi
    else
        print_error "Main System: Not started"
    fi
    
    # Check tray
    if [ -f "logs/selflow_tray.pid" ]; then
        TRAY_PID=$(cat logs/selflow_tray.pid)
        if kill -0 $TRAY_PID 2>/dev/null; then
            print_success "System Tray: Running (PID: $TRAY_PID)"
        else
            print_warning "System Tray: Not running"
        fi
    else
        print_warning "System Tray: Not started"
    fi
    
    echo ""
}

# Function to monitor logs
monitor_logs() {
    print_status "Monitoring system logs (Ctrl+C to stop)..."
    echo ""
    
    # Show recent logs
    if [ -f "logs/selflow_main.log" ]; then
        echo -e "${CYAN}=== Recent Main System Logs ===${NC}"
        tail -n 10 logs/selflow_main.log
        echo ""
    fi
    
    # Follow logs
    if [ -f "logs/selflow_main.log" ]; then
        print_status "Following main system logs..."
        tail -f logs/selflow_main.log
    else
        print_error "No logs found"
    fi
}

# Function to restart just the tray
restart_tray() {
    print_status "Restarting system tray..."
    
    # Stop tray if running
    if [ -f "logs/selflow_tray.pid" ]; then
        TRAY_PID=$(cat logs/selflow_tray.pid)
        if kill -0 $TRAY_PID 2>/dev/null; then
            kill $TRAY_PID
            print_success "System tray stopped"
        fi
        rm -f logs/selflow_tray.pid
    fi
    
    # Kill any remaining tray processes
    pkill -f "launch_tray|macos_tray" 2>/dev/null || true
    sleep 2
    
    # Start tray again
    start_tray
}

# Function to stop all processes
stop_system() {
    print_status "Stopping SelFlow system..."
    
    # Stop main system
    if [ -f "logs/selflow_main.pid" ]; then
        MAIN_PID=$(cat logs/selflow_main.pid)
        if kill -0 $MAIN_PID 2>/dev/null; then
            kill $MAIN_PID
            print_success "Main system stopped"
        fi
        rm -f logs/selflow_main.pid
    fi
    
    # Stop tray
    if [ -f "logs/selflow_tray.pid" ]; then
        TRAY_PID=$(cat logs/selflow_tray.pid)
        if kill -0 $TRAY_PID 2>/dev/null; then
            kill $TRAY_PID
            print_success "System tray stopped"
        fi
        rm -f logs/selflow_tray.pid
    fi
    
    # Cleanup any remaining processes
    pkill -f "selflow|SelFlow|run_selflow|launch_tray" 2>/dev/null || true
    
    print_success "SelFlow system stopped"
}

# Main script logic
main() {
    print_header
    
    case "${1:-start}" in
        "start")
            check_venv
            activate_venv
            cleanup_processes
            check_system
            start_main_system
            start_tray
            show_status
            echo ""
            print_success "SelFlow system launched successfully!"
            print_status "Use './launch_selflow.sh status' to check status"
            print_status "Use './launch_selflow.sh logs' to monitor logs"
            print_status "Use './launch_selflow.sh stop' to stop the system"
            ;;
        "stop")
            stop_system
            ;;
        "status")
            show_status
            ;;
        "logs")
            monitor_logs
            ;;
        "restart")
            stop_system
            sleep 2
            main start
            ;;
        "tray")
            restart_tray
            show_status
            ;;
        *)
            echo "Usage: $0 {start|stop|status|logs|restart|tray}"
            echo ""
            echo "Commands:"
            echo "  start   - Start the complete SelFlow system"
            echo "  stop    - Stop all SelFlow processes"
            echo "  status  - Show system status"
            echo "  logs    - Monitor system logs"
            echo "  restart - Restart the system"
            echo "  tray    - Restart just the system tray"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 