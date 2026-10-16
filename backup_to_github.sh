#!/usr/bin/env bash
# ==============================================================================
# Trail of the Grandmaster - GitHub Backup Script (Git Bash)
# ==============================================================================

# ANSI Color Codes
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}"
echo "============================================================"
echo "    TRAIL OF THE GRANDMASTER - GITHUB BACKUP UTILITY"
echo "============================================================"
echo -e "${NC}"

# Navigate to script's directory (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || {
    echo -e "${RED}[ERROR] Could not navigate to project directory: $SCRIPT_DIR${NC}"
    read -p "Press Enter to exit..."
    exit 1
}

echo -e "Project Directory: ${BOLD}$SCRIPT_DIR${NC}\n"

# 1. Verify Git installation
if ! command -v git &> /dev/null; then
    echo -e "${RED}[ERROR] 'git' command not found.${NC}"
    echo "Please ensure Git for Windows is installed from: https://git-scm.com/download/win"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

# 2. Initialize Git repository if not present
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}[!] Git repository not initialized. Initializing now...${NC}"
    git init -b main 2>/dev/null || {
        git init
        git branch -M main
    }
    echo -e "${GREEN}[OK] Initialized git repository with default branch 'main'.${NC}\n"
fi

# Ensure branch is main
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
if [ -z "$CURRENT_BRANCH" ]; then
    CURRENT_BRANCH="main"
fi

# 3. Check / Configure Remote Origin
ORIGIN_URL=$(git remote get-url origin 2>/dev/null)

if [ -z "$ORIGIN_URL" ]; then
    echo -e "${YELLOW}------------------------------------------------------------${NC}"
    echo -e "${YELLOW}[!] No GitHub remote 'origin' configured yet.${NC}"
    echo -e "Please create a new repository on GitHub (https://github.com/new)."
    echo -e "Then paste your GitHub repository URL below."
    echo -e "Example: ${CYAN}https://github.com/YOUR_USERNAME/trail-of-the-grandmaster.git${NC}"
    echo -e "${YELLOW}------------------------------------------------------------${NC}"
    
    read -p "GitHub Repository URL (or press Enter to skip remote push): " INPUT_URL
    
    if [ -n "$INPUT_URL" ]; then
        git remote add origin "$INPUT_URL"
        ORIGIN_URL="$INPUT_URL"
        echo -e "${GREEN}[OK] Remote origin set to: $ORIGIN_URL${NC}\n"
    else
        echo -e "${YELLOW}[!] Skipping remote configuration. Changes will be committed locally only.${NC}\n"
    fi
else
    echo -e "GitHub Remote: ${GREEN}$ORIGIN_URL${NC} (Branch: ${GREEN}$CURRENT_BRANCH${NC})\n"
fi

# 4. Check status and stage changes
STATUS_OUTPUT=$(git status --porcelain)

if [ -n "$STATUS_OUTPUT" ]; then
    echo -e "${CYAN}Pending changes detected:${NC}"
    git status -s
    echo ""
    
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    DEFAULT_MSG="Backup: $TIMESTAMP - Trail of the Grandmaster"
    
    read -p "Enter commit message (Press Enter for default: '$DEFAULT_MSG'): " USER_MSG
    
    COMMIT_MSG="${USER_MSG:-$DEFAULT_MSG}"
    
    echo -e "\n${CYAN}[1/2] Staging files...${NC}"
    git add -A
    
    echo -e "${CYAN}[2/2] Committing changes...${NC}"
    git commit -m "$COMMIT_MSG"
    echo -e "${GREEN}[OK] Committed successfully with message:${NC} \"$COMMIT_MSG\"\n"
else
    echo -e "${GREEN}[OK] Working directory is clean. No uncommitted local changes.${NC}\n"
fi

# 5. Push to GitHub if remote exists
if [ -n "$ORIGIN_URL" ]; then
    echo -e "${CYAN}Syncing with GitHub (${ORIGIN_URL})...${NC}"
    
    # Check if upstream branch is set or push with -u
    if git push -u origin "$CURRENT_BRANCH"; then
        echo ""
        echo -e "${GREEN}${BOLD}============================================================${NC}"
        echo -e "${GREEN}${BOLD}    BACKUP COMPLETED SUCCESSFULLY TO GITHUB!${NC}"
        echo -e "${GREEN}${BOLD}============================================================${NC}"
    else
        echo ""
        echo -e "${RED}${BOLD}============================================================${NC}"
        echo -e "${RED}[ERROR] Push to GitHub failed.${NC}"
        echo -e "${RED}${BOLD}============================================================${NC}"
        echo -e "${YELLOW}Common reasons and solutions:${NC}"
        echo " 1. GitHub Authentication: If using HTTPS, ensure you have authenticated or use a GitHub Personal Access Token."
        echo " 2. Remote repository has new commits: Try running 'git pull --rebase origin $CURRENT_BRANCH' first."
        echo " 3. Empty GitHub repo with README: If the remote was created with a README, run 'git pull origin $CURRENT_BRANCH --allow-unrelated-histories' before pushing."
        echo " 4. Wrong URL: Check with 'git remote -v' or update with 'git remote set-url origin <NEW_URL>'."
    fi
else
    echo -e "${YELLOW}[NOTE] No remote origin configured. To push later, run:${NC}"
    echo -e "  git remote add origin https://github.com/YOUR_USERNAME/trail-of-the-grandmaster.git"
    echo -e "  git push -u origin $CURRENT_BRANCH"
fi

echo ""
read -p "Press Enter to exit..."
