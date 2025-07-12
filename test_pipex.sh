#!/bin/bash
# filepath: /home/mcampita/Downloads/tmp/test_pipex.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0

# Function to print test results
print_result() {
    local test_name="$1"
    local result="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
    fi
}

# Function to compare files
compare_files() {
    local file1="$1"
    local file2="$2"
    
    if [ -f "$file1" ] && [ -f "$file2" ]; then
        if diff -q "$file1" "$file2" > /dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    elif [ ! -f "$file1" ] && [ ! -f "$file2" ]; then
        return 0
    else
        return 1
    fi
}

# Function to test pipex vs shell behavior
test_pipex() {
    local test_name="$1"
    local file1="$2"
    local cmd1="$3"
    local cmd2="$4"
    local outfile="pipex_out"
    local expected="shell_out"
    
    echo -e "\n${BLUE}Testing:${NC} $test_name"
    echo -e "${YELLOW}Command:${NC} ./pipex $file1 \"$cmd1\" \"$cmd2\" $outfile"
    
    # Clean previous outputs
    rm -f "$outfile" "$expected" pipex_err shell_err
    
    # Run pipex
    ./pipex "$file1" "$cmd1" "$cmd2" "$outfile" 2> pipex_err
    pipex_exit=$?
    
    # Run equivalent shell command
    if [ -f "$file1" ]; then
        bash -c "< \"$file1\" $cmd1 | $cmd2 > \"$expected\"" 2> shell_err
    else
        bash -c "< \"$file1\" $cmd1 | $cmd2 > \"$expected\"" 2> shell_err
    fi
    shell_exit=$?
    
    # Compare outputs
    if compare_files "$outfile" "$expected"; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
        echo -e "  ${RED}Output differs${NC}"
        if [ -f "$outfile" ]; then
            echo "  Pipex output: $(cat "$outfile" 2>/dev/null | head -1)"
        else
            echo "  Pipex output: (no file created)"
        fi
        if [ -f "$expected" ]; then
            echo "  Expected output: $(cat "$expected" 2>/dev/null | head -1)"
        else
            echo "  Expected output: (no file created)"
        fi
    fi
    
    # Clean up
    rm -f "$outfile" "$expected" pipex_err shell_err
}

# Setup test files
setup_tests() {
    echo -e "${BLUE}Setting up test files...${NC}"
    
    # Create test input files
    echo -e "line1\nline2\nline3\napple\nbanana\ncherry" > infile
    echo "hello world" > simple.txt
    touch empty.txt
    echo -e "a1 test\nb2 data\na1 more\nc3 info" > grep_test.txt
    
    # Create a file with no read permissions
    echo "secret content" > no_read.txt
    chmod 000 no_read.txt
    
    # Create a file with no write permissions
    echo "readonly content" > readonly.txt
    chmod 444 readonly.txt
    
    echo -e "${GREEN}Test files created${NC}"
}

# Cleanup function
cleanup() {
    echo -e "\n${BLUE}Cleaning up...${NC}"
    rm -f infile simple.txt empty.txt grep_test.txt no_read.txt readonly.txt
    rm -f pipex_out shell_out pipex_err shell_err largefile
    rm -f outfile expected test_out
    rm -f "file with spaces" "out file" "file'quote"
}

# Check if pipex executable exists
check_pipex() {
    if [ ! -f "./pipex" ]; then
        echo -e "${RED}Error: ./pipex executable not found${NC}"
        echo "Please compile your pipex program first"
        exit 1
    fi
    
    if [ ! -x "./pipex" ]; then
        echo -e "${RED}Error: ./pipex is not executable${NC}"
        chmod +x ./pipex
    fi
}

# Main test function
run_tests() {
    echo -e "${BLUE}=== PIPEX TEST SUITE ===${NC}\n"
    
    check_pipex
    setup_tests
    
    echo -e "\n${BLUE}=== BASIC FUNCTIONALITY TESTS ===${NC}"
    
    # Basic tests
    test_pipex "Basic cat and wc" "infile" "cat" "wc -l"
    test_pipex "Basic ls and wc" "." "ls" "wc -l"
    test_pipex "Grep and wc" "grep_test.txt" "grep a1" "wc -w"
    test_pipex "Cat empty file" "empty.txt" "cat" "wc -l"
    
    echo -e "\n${BLUE}=== FILE ACCESS EDGE CASES ===${NC}"
    
    # File doesn't exist
    test_pipex "Nonexistent input file" "nonexistent.txt" "cat" "wc -l"
    
    # No read permissions
    test_pipex "No read permissions" "no_read.txt" "cat" "wc -l"
    
    echo -e "\n${BLUE}=== COMMAND EDGE CASES ===${NC}"
    
    # Invalid commands
    test_pipex "Invalid first command" "infile" "invalidcommand123" "wc -l"
    test_pipex "Invalid second command" "infile" "cat" "invalidcommand123"
    
    # Commands that fail
    test_pipex "Grep no match" "infile" "grep nonexistent" "wc -l"
    test_pipex "False command" "infile" "false" "cat"
    
    # Complex commands
    test_pipex "Complex grep" "grep_test.txt" "grep 'a1'" "sort"
    test_pipex "Awk command" "infile" "cat" "head -2"
    
    echo -e "\n${BLUE}=== SPECIAL CHARACTER TESTS ===${NC}"
    
    # Files with spaces
    echo "test content" > "file with spaces"
    test_pipex "File with spaces" "file with spaces" "cat" "wc -c"
    rm -f "file with spaces"
    
    echo -e "\n${BLUE}=== ARGUMENT TESTS ===${NC}"
    
    # Wrong number of arguments
    echo -e "\n${YELLOW}Testing wrong number of arguments:${NC}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    ./pipex 2>/dev/null
    if [ $? -ne 0 ]; then
        print_result "No arguments" "PASS"
    else
        print_result "No arguments" "FAIL"
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    ./pipex infile 2>/dev/null
    if [ $? -ne 0 ]; then
        print_result "Too few arguments" "PASS"
    else
        print_result "Too few arguments" "FAIL"
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    ./pipex infile cmd1 cmd2 outfile extra 2>/dev/null
    if [ $? -ne 0 ]; then
        print_result "Too many arguments" "PASS"
    else
        print_result "Too many arguments" "FAIL"
    fi
    
    echo -e "\n${BLUE}=== LARGE FILE TEST ===${NC}"
    
    # Create large file (1MB)
    if command -v dd >/dev/null 2>&1; then
        dd if=/dev/zero of=largefile bs=1024 count=1024 2>/dev/null
        test_pipex "Large file processing" "largefile" "cat" "wc -c"
        rm -f largefile
    else
        echo -e "${YELLOW}Skipping large file test (dd not available)${NC}"
    fi
    
    echo -e "\n${BLUE}=== PATH TESTS ===${NC}"
    
    # Test with full path commands
    test_pipex "Full path commands" "infile" "/bin/cat" "wc -l"
    
    # Print final results
    echo -e "\n${BLUE}=== TEST SUMMARY ===${NC}"
    echo -e "Total tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$((TOTAL_TESTS - PASSED_TESTS))${NC}"
    
    if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
        echo -e "\n${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
    else
        echo -e "\n${RED}Some tests failed. Check your implementation.${NC}"
    fi
    
    cleanup
}

# Bonus tests function
test_bonus() {
    echo -e "\n${BLUE}=== BONUS TESTS ===${NC}"
    
    # Test multiple pipes
    echo -e "\n${YELLOW}Testing multiple pipes (if implemented):${NC}"
    ./pipex infile "cat" "grep line" "wc -l" outfile 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Multiple pipes seems to be implemented${NC}"
    else
        echo -e "${YELLOW}Multiple pipes not implemented or failed${NC}"
    fi
    
    # Test here_doc
    echo -e "\n${YELLOW}Testing here_doc (if implemented):${NC}"
    echo -e "test line 1\ntest line 2\nEOF" | ./pipex here_doc EOF "cat" "wc -l" outfile 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Here_doc seems to be implemented${NC}"
    else
        echo -e "${YELLOW}Here_doc not implemented or failed${NC}"
    fi
}

# Run main tests
run_tests

# Ask user if they want to test bonus
echo -e "\n${YELLOW}Do you want to test bonus features? (y/n):${NC}"
read -r answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    test_bonus
fi

echo -e "\n${BLUE}Test script completed!${NC}"
