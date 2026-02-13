# GitHub Beginner's Guide

A friendly walkthrough for Git and GitHub basics, tailored for the Axiom project.

## What is Git and GitHub?

**Git** is a version control system that tracks changes to your files. Think of it as a super-powered "undo" button that remembers every version of your work.

**GitHub** is a website that hosts Git repositories online, making it easy to:
- Backup your code in the cloud
- Collaborate with others
- Track changes and history
- Manage versions and releases

## Initial Setup (One-Time)

### 1. Install Git

**Windows:**
Download from [git-scm.com](https://git-scm.com/download/win)

**Mac:**
```bash
brew install git
```

**Linux:**
```bash
sudo apt-get install git
```

### 2. Configure Git

Tell Git who you are (this shows up in your commits):

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 3. Set Up SSH Keys (Recommended)

SSH keys let you connect to GitHub without typing your password every time.

```bash
# Generate a new SSH key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Press Enter to accept default location
# Press Enter twice for no passphrase (or set one for extra security)

# Display your public key
cat ~/.ssh/id_ed25519.pub
```

Copy the output and add it to GitHub:
1. Go to GitHub.com → Settings → SSH and GPG keys
2. Click "New SSH key"
3. Paste your public key
4. Click "Add SSH key"

## Getting Started with Axiom

### Clone the Repository

```bash
# Clone using HTTPS
git clone https://github.com/w071278-hash/0.git

# Or clone using SSH (if you set up SSH keys)
git clone git@github.com:w071278-hash/0.git

# Navigate into the directory
cd 0
```

### Check Repository Status

See what files have changed:
```bash
git status
```

### View Recent Changes

See what's different since your last commit:
```bash
git diff
```

See what's different in a specific file:
```bash
git diff modules/00-config.sh
```

## Making Changes

### The Basic Workflow

1. **Make your changes** - Edit files in your favorite editor

2. **Check what changed**
   ```bash
   git status
   git diff
   ```

3. **Stage your changes** - Tell Git which files to include
   ```bash
   # Stage a specific file
   git add modules/00-config.sh
   
   # Stage all changed files
   git add .
   ```

4. **Commit your changes** - Save a snapshot with a message
   ```bash
   git commit -m "Update Agent Zero password in config"
   ```

5. **Push to GitHub** - Upload your changes
   ```bash
   git push
   ```

### Example: Updating Configuration

```bash
# Edit the config file
nano modules/00-config.sh

# Check what you changed
git diff modules/00-config.sh

# Stage the file
git add modules/00-config.sh

# Commit with a descriptive message
git commit -m "Change Agent Zero RFC password"

# Push to GitHub
git push
```

## Keeping Up to Date

### Pull Latest Changes

Before making changes, get the latest version from GitHub:

```bash
git pull
```

This is important when:
- Someone else (or another computer) made changes
- The Axiom deployment script created updates
- You're resuming work after a break

### Check for Updates Without Pulling

```bash
# See what's new on GitHub without downloading
git fetch

# Compare your version to GitHub's
git status
```

## Branches (Advanced)

Branches let you work on features without affecting the main code.

### Create a Branch

```bash
# Create and switch to a new branch
git checkout -b my-feature

# Make your changes, commit them
git add .
git commit -m "Add new feature"

# Push your branch to GitHub
git push -u origin my-feature
```

### Switch Between Branches

```bash
# Switch to main branch
git checkout main

# Switch to your feature branch
git checkout my-feature

# List all branches
git branch
```

### Merge a Branch

Once your feature is ready:

```bash
# Switch to main
git checkout main

# Merge your feature branch
git merge my-feature

# Push the merged result
git push

# Delete the feature branch (optional)
git branch -d my-feature
```

## Common Scenarios

### Scenario 1: I Made a Mistake in My Last Commit

```bash
# Undo the last commit but keep your changes
git reset --soft HEAD~1

# Make your fixes, then commit again
git add .
git commit -m "Fixed commit message"
```

### Scenario 2: I Want to Discard All My Changes

```bash
# Discard all uncommitted changes (careful!)
git reset --hard HEAD

# Or discard changes to a specific file
git checkout -- modules/00-config.sh
```

### Scenario 3: I Have Merge Conflicts

When Git can't automatically merge changes:

```bash
# Pull and see the conflict
git pull

# Git will tell you which files have conflicts
# Open them in an editor - look for:
<<<<<<< HEAD
Your changes
=======
Changes from GitHub
>>>>>>> branch-name

# Edit the file to resolve the conflict
# Remove the conflict markers
# Keep the version you want (or combine them)

# Stage the resolved file
git add modules/00-config.sh

# Complete the merge
git commit -m "Resolve merge conflict"

# Push the result
git push
```

### Scenario 4: I Want to See What Changed in a Previous Commit

```bash
# View commit history
git log

# View a specific commit
git show abc1234

# View changes to a specific file
git log -p modules/00-config.sh
```

## Best Practices

### Write Good Commit Messages

**Bad:**
```bash
git commit -m "fixed stuff"
git commit -m "update"
git commit -m "asdf"
```

**Good:**
```bash
git commit -m "Fix Agent Zero port conflict"
git commit -m "Add Postgres service to deployment"
git commit -m "Update documentation with SSH troubleshooting"
```

Tips for good messages:
- Use the imperative mood ("Add feature" not "Added feature")
- Be specific about what changed
- Keep the first line under 50 characters
- Add details in a second paragraph if needed

### Commit Often

Small, frequent commits are better than huge commits:
- Easier to understand what changed
- Easier to undo if something breaks
- Better history for debugging

### Pull Before You Push

Always pull before starting work:
```bash
git pull
# Make changes
git add .
git commit -m "Your message"
git push
```

### Don't Commit Sensitive Data

Never commit:
- Passwords or API keys
- SSH private keys (only public keys are safe)
- Credentials JSON files
- Personal data

The `.gitignore` file prevents this:
```bash
# View ignored patterns
cat .gitignore
```

## Quick Reference

```bash
# Get status
git status

# See changes
git diff

# Stage all changes
git add .

# Commit with message
git commit -m "Your message"

# Push to GitHub
git push

# Pull from GitHub
git pull

# View history
git log

# Discard changes to a file
git checkout -- filename

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Create new branch
git checkout -b branch-name

# Switch branches
git checkout branch-name
```

## Getting Help

### In the Terminal
```bash
# Get help on any command
git help <command>
git help commit
git help branch

# Quick reference
git <command> --help
```

### Online Resources
- [GitHub's Git Handbook](https://guides.github.com/introduction/git-handbook/)
- [Git Documentation](https://git-scm.com/doc)
- [Oh Shit, Git!?!](https://ohshitgit.com/) - Fixing common mistakes

### For Axiom Specifically
- Check the main README.md
- Review the deployment logs: `/var/log/axiom-deploy.log`
- Look at commit history for examples: `git log`

## Troubleshooting

### "Permission denied (publickey)"
Your SSH key isn't set up. Either:
- Set up SSH keys (see above)
- Use HTTPS instead: `git remote set-url origin https://github.com/w071278-hash/0.git`

### "refusing to merge unrelated histories"
```bash
git pull --allow-unrelated-histories
```

### "Your branch is behind 'origin/main'"
```bash
git pull
```

### "Your branch is ahead of 'origin/main'"
```bash
git push
```

### "fatal: not a git repository"
You're not in the repository directory:
```bash
cd path/to/0
```

---

Remember: Git is a tool to make your life easier. Don't be afraid to experiment - it's very hard to permanently lose work with Git!
