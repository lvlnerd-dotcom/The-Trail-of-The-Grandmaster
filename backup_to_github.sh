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

# Helper function to sanitize URLs (strips escape sequences, arrow key artifacts, spaces)
sanitize_url() {
    local raw="$1"
    # Remove ANSI escape codes, terminal bracketed paste or arrow artifacts like [A, [B, whitespace
    echo "$raw" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g' | tr -d '\r\n\t ' | sed -E 's/^[^a-zA-Z0-9]*(https?:\/\/|git@)/\1/'
}

# 1. Verify Git installation
if ! command -v git &> /dev/null; then
    echo -e "${RED}[ERROR] 'git' command not found.${NC}"
    echo "Please ensure Git for Windows is installed from: https://git-scm.com/download/win"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

# 2. Check / configure Git User Identity
USER_NAME=$(git config user.name 2>/dev/null)
USER_EMAIL=$(git config user.email 2>/dev/null)

if [ -z "$USER_NAME" ] || [ -z "$USER_EMAIL" ]; then
    echo -e "${YELLOW}[!] Git author identity is not yet configured on this machine.${NC}"
    if [ -z "$USER_NAME" ]; then
        read -p "Enter your Name / GitHub Username [default: lvlnerd-dotcom]: " INPUT_NAME
        USER_NAME="${INPUT_NAME:-lvlnerd-dotcom}"
        git config --global user.name "$USER_NAME"
    fi
    if [ -z "$USER_EMAIL" ]; then
        read -p "Enter your Email [default: lvlnerd-dotcom@users.noreply.github.com]: " INPUT_EMAIL
        USER_EMAIL="${INPUT_EMAIL:-lvlnerd-dotcom@users.noreply.github.com}"
        git config --global user.email "$USER_EMAIL"
    fi
    echo -e "${GREEN}[OK] Git identity configured as: $USER_NAME <$USER_EMAIL>${NC}\n"
fi

# 3. Initialize Git repository if not present
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

# 4. Check / Clean Remote Origin
ORIGIN_URL=$(git remote get-url origin 2>/dev/null)
CLEANED_URL=$(sanitize_url "$ORIGIN_URL")

# Auto-repair URL if it had corrupted escape characters
if [ -n "$ORIGIN_URL" ] && [ "$ORIGIN_URL" != "$CLEANED_URL" ]; then
    echo -e "${YELLOW}[!] Sanitizing malformed remote URL...${NC}"
    git remote set-url origin "$CLEANED_URL"
    ORIGIN_URL="$CLEANED_URL"
fi

if [ -z "$ORIGIN_URL" ]; then
    echo -e "${YELLOW}------------------------------------------------------------${NC}"
    echo -e "${YELLOW}[!] No GitHub remote 'origin' configured yet.${NC}"
    echo -e "Paste your GitHub repository URL below."
    echo -e "Example: ${CYAN}https://github.com/lvlnerd-dotcom/The-Trail-of-The-Grandmaster.git${NC}"
    echo -e "${YELLOW}------------------------------------------------------------${NC}"
    
    read -p "GitHub Repository URL: " INPUT_URL
    CLEAN_INPUT=$(sanitize_url "$INPUT_URL")
    
    if [ -n "$CLEAN_INPUT" ]; then
        git remote add origin "$CLEAN_INPUT"
        ORIGIN_URL="$CLEAN_INPUT"
        echo -e "${GREEN}[OK] Remote origin set to: $ORIGIN_URL${NC}\n"
    else
        echo -e "${YELLOW}[!] Skipping remote configuration. Changes will be committed locally only.${NC}\n"
    fi
else
    echo -e "GitHub Remote: ${GREEN}$ORIGIN_URL${NC} (Branch: ${GREEN}$CURRENT_BRANCH${NC})\n"
fi

# 5. Check status and stage changes
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
    if git commit -m "$COMMIT_MSG"; then
        echo -e "${GREEN}[OK] Committed successfully with message:${NC} \"$COMMIT_MSG\"\n"
    else
        echo -e "${RED}[ERROR] Commit failed. Please check error details above.${NC}\n"
    fi
else
    echo -e "${GREEN}[OK] Working directory is clean. No uncommitted local changes.${NC}\n"
fi

# 6. Verify that at least one commit exists
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] No commits exist on branch '$CURRENT_BRANCH' yet. Cannot push.${NC}"
    read -p "Press Enter to exit..."
    exit 1
fi

# 7. Push to GitHub if remote exists
if [ -n "$ORIGIN_URL" ]; then
    echo -e "${CYAN}Syncing with GitHub (${ORIGIN_URL})...${NC}"
    
    if git push -u origin "$CURRENT_BRANCH"; then
        echo ""
        echo -e "${GREEN}${BOLD}============================================================${NC}"
        echo -e "${GREEN}${BOLD}    BACKUP COMPLETED SUCCESSFULLY TO GITHUB!${NC}"
        echo -e "${GREEN}${BOLD}============================================================${NC}"
    else
        echo ""
        echo -e "${YELLOW}[!] Push was not completed. Checking if remote has conflicting commits (e.g. README)...${NC}"
        read -p "Would you like to try pulling and rebasing remote changes? (y/n): " RETRY_CHOICE
        if [[ "$RETRY_CHOICE" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Pulling from remote...${NC}"
            if git pull --rebase --allow-unrelated-histories origin "$CURRENT_BRANCH"; then
                echo -e "${CYAN}Retrying push...${NC}"
                git push -u origin "$CURRENT_BRANCH" && {
                    echo ""
                    echo -e "${GREEN}${BOLD}============================================================${NC}"
                    echo -e "${GREEN}${BOLD}    BACKUP COMPLETED SUCCESSFULLY TO GITHUB!${NC}"
                    echo -e "${GREEN}${BOLD}============================================================${NC}"
                }
            fi
        else
            echo ""
            echo -e "${RED}${BOLD}============================================================${NC}"
            echo -e "${RED}[ERROR] Push to GitHub failed.${NC}"
            echo -e "${RED}${BOLD}============================================================${NC}"
            echo -e "${YELLOW}Troubleshooting Tips:${NC}"
            echo " 1. GitHub Login: Git Credential Manager will open a browser window to sign in."
            echo " 2. Permissions: Ensure your GitHub account has write access to $ORIGIN_URL."
            echo " 3. Personal Access Token: If two-factor authentication is required, use a GitHub PAT as your password."
        fi
    fi
else
    echo -e "${YELLOW}[NOTE] No remote origin configured. To push later, run:${NC}"
    echo -e "  git remote add origin https://github.com/lvlnerd-dotcom/The-Trail-of-The-Grandmaster.git"
    echo -e "  git push -u origin $CURRENT_BRANCH"
fi

echo ""
read -p "Press Enter to exit..."
