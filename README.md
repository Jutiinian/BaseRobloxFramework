# 🎮 Setup & Workflow Guide

![kpop-haerin-kang-BQUaRQJ0RyVmo4dWaY](https://media0.giphy.com/media/BQUaRQJ0RyVmo4dWaY/giphy.gif)

---

## 🔗 Quick Links

**Zap:** https://zap.redblox.dev  
**Rokit:** https://github.com/rojo-rbx/rokit  
**Wally Packages:** https://wally.run/

---

## 🚀 Getting Started

### What You Need

Make sure you have these installed:

- **Node.js** - Download from https://nodejs.org (get the LTS version)
- **Git** - Should already be installed if you cloned this repo
- **Shell environment** - Git Bash or WSL for Windows, built-in terminal for Mac/Linux

Once you have Node.js, you can run scripts on any platform.

### You can run scripts two ways:

**Option 1: Just run the shell script**

```bash
sh scripts/install-packages.sh
```

**Option 2: Use the Node wrapper if shell scripts aren't working**

```bash
node scripts/run-sh.js scripts/install-packages.sh
```

Basically the Node wrapper just replaces `sh` with `node scripts/run-sh.js` - pick whatever works on your system.

---

## 🛠️ Installing Tools

### The Tools We Use

Everything's managed by Rokit, so don't install stuff manually or you'll have version conflicts.

**What gets installed:**
- `rojo`
- `wally`
- `wally-package-types`

### Setting Up Rokit

If you don't have Rokit yet:

**1.** Go to https://github.com/rojo-rbx/rokit and follow their install instructions

**2.** (OPTIONAL) Once it's installed, run this from the project root:

```bash
rokit install
```

That's it. Rokit will handle everything else.\
**Note:** `install-packages` script already runs `rokit install`

---

## 📦 First Time Setup

Run these in order from the project root. Don't skip steps or things will break.

### Step 1: Install packages and types

```bash
sh scripts/install-packages.sh
```

### Step 2: Generate Rojo tree and sourcemap

```bash
sh scripts/process-tree.sh
```

### Step 3: Process remotes

```bash
sh scripts/process-remotes.sh
```

> **💡 Note:** If you're using the Node wrapper, just add `node scripts/run-sh.js` before each command.

---

## ▶️ Actually Running the Project

### Start the Rojo server

```bash
rojo serve
```

### Then in Roblox Studio

Just connect using the Rojo plugin. Pretty straightforward.

---

## 👥 Working with Multiple People

### ⚠️ Important: Don't Mess This Up

**Everyone needs their own Studio `.rbxl` file.** Seriously, don't edit the main place file directly - Rojo will just overwrite it and you'll lose your work.

Here's how it works:
- Everyone has their own `.rbxl` copy for testing
- We all edit code in `src/` (this is the actual source code)
- Rojo syncs the code to your Studio file
- The `.rbxl` file is basically temporary - `src/` is what matters

### Before You Start Working Each Day

**Pull the latest stuff:**

```bash
git checkout main
git pull
```

**Update your local setup:**

```bash
sh scripts/install-packages.sh
sh scripts/process-tree.sh
sh scripts/process-remotes.sh
```

### After You Made Changes

**Commit and push:**

```bash
git add .
git commit -m "what you actually changed"
git push origin feature/whatever-youre-working-on
```

**Other people will:**
- Pull your changes
- Rerun the setup scripts
- Test your stuff

Just keep each other in the loop so we don't break things.

---

## 🔄 Normal Workflow (When You Pull Updates)

Whenever someone else pushes changes and you pull them:

### Step 1: Pull

```bash
git pull
```

### Step 2: Run the setup scripts

```bash
sh scripts/install-packages.sh
sh scripts/process-tree.sh
sh scripts/process-remotes.sh --verbose
```

### Step 3: Start Rojo and connect Studio

```bash
rojo serve
```

That's it. Don't skip step 3 or weird stuff might happen.

---

## 🌿 Using Branches

### Making a New Branch

For each feature or bug fix, make a new branch:

```bash
git checkout -b feature/whatever-youre-doing
```

### Testing Your Changes

After you edit stuff, test the scripts:

```bash
sh scripts/process-tree.sh
sh scripts/process-remotes.sh
```

### Committing and Pushing

```bash
git add .
git commit -m "explain what you did"
git push origin feature/whatever-youre-doing
```

### Merging Back to Main

Before merging, sync with main first:

```bash
git checkout main
git pull
git checkout feature/whatever-youre-doing
git merge main
```

Fix any merge conflicts, test everything works, then make a pull request.

---

## ❓ Getting Help

All the scripts have a `--help` flag if you forget what they do:

```bash
sh scripts/install-packages.sh --help
sh scripts/process-tree.sh --help
sh scripts/process-remotes.sh --help
```

---

## 📝 Quick Notes

- Node wrapper is totally optional - use whatever works
- Always run scripts from the project root (don't cd into scripts/)
- Remember: Studio files are temporary, `src/` is the real code
- Don't commit your personal `.rbxl` files, only commit stuff in `src/`

---

# 🌳 Git Branching - When and Why

---

## ✅ When to Make a Branch

Make a branch if you're changing:

- **Features** - new gameplay stuff, systems, anything functional
- **Bug fixes** - fixing broken things
- **Scripts** - build scripts, tools, automation
- **Assets** - `.zap` files, models, configs
- **Project structure** - reorganizing folders, file layouts

### Branch Names

Keep them simple and descriptive:

```bash
feature/inventory-system
bugfix/collision-bug
script/auto-deploy
asset/new-characters
```

---

## ❌ When NOT to Branch

Skip branching for:

- Personal config files (your IDE settings, etc.)
- Just running scripts locally to test stuff
- Tiny README fixes (unless you're rewriting a bunch)

---

## 📋 Basic Git Flow

### Step 1: Pull Latest

```bash
git checkout main
git pull
```

### Step 2: Make Your Branch

```bash
git checkout -b feature/short-name
```

### Step 3: Do Your Work

- Edit code in `src/`
- Run the scripts
- Test in Studio
- Make sure it actually works

### Step 4: Commit and Push

```bash
git add .
git commit -m "actually explain what you changed"
git push origin feature/short-name
```

### Step 5: Make a Pull Request

- Open a pull request to `main`
- Get someone to review it
- Fix any issues they find
- Merge when it's approved

---

## 🎯 Simple Rule

**If it affects the project, other people, or the game - make a branch.**

When in doubt, just make a branch. Better safe than sorry.

---

## 💡 Tips for Not Breaking Things

- **Talk to each other** - let people know what you're working on
- **Commit often** - small commits are easier to debug than huge ones
- **Pull regularly** - don't go days without pulling, you'll get merge hell
- **Review each other's code** - catch bugs before they make it to main
- **Test before pull request** - seriously, test your changes before pushing

---

That's pretty much it. Use `--help` on scripts if you forget commands.

![a woman wearing a hat and a blue shirt gives a thumbs up](https://media.tenor.com/D0AYhhoU2y8AAAAC/haerin-newjeans.gif)

YAY!