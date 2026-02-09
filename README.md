# Setup & Team Workflow Checklist

### Important Links

Zap: https://zap.redblox.dev
Rokit: https://github.com/rojo-rbx/rokit
Wally Packages: https://wally.run/

### Environment

- [ ] Make sure you can run `.sh` scripts and Node.js scripts (macOS/Linux terminal, Git Bash, WSL, etc.)  
- [ ] Optionally, you can just use the Node wrapper (`run-sh.js`) instead of `.sh` scripts.

---

### Tools

- [ ] Installed via Rokit (don’t install manually):  
  - rojo  
  - wally  
  - wally-package-types  

- [ ] Install Rokit if needed:  
  👉 https://github.com/rojo-rbx/rokit

- [ ] From project root:  
  ```
  rokit install
  ```

---

### First-time setup

Run either `.sh` scripts or Node wrapper:

- [ ] Install packages and types:  
  ```
  sh scripts/install-packages.sh
  ```  
  Or:  
  ```
  node scripts/run-sh.js scripts/install-packages.sh
  ```

- [ ] Generate Rojo tree and sourcemap:  
  ```
  sh scripts/process-tree.sh
  ```  
  Or:  
  ```
  node scripts/run-sh.js scripts/process-tree.sh
  ```

- [ ] Process remotes:  
  ```
  sh scripts/process-remotes.sh
  ```  
  Or:  
  ```
  node scripts/run-sh.js scripts/process-remotes.sh
  ```

---

### Running the project

- [ ] Start Rojo server:  
  ```
  rojo serve
  ```  
- [ ] Connect in Roblox Studio using the Rojo plugin

---

### Multi-Developer Workflow

- [ ] Each person must work in their **own Studio `.rbxl` file**.  
      - Do **not edit the main generated `.rbxl` directly**; Rojo will overwrite it.  
      - Everyone edits their copy while using `rojo serve` locally.

- [ ] Pull latest changes from Git before starting:  
  ```
  git checkout main
  git pull
  ```

- [ ] Run setup scripts to update your local Rojo tree, remotes, and types:  
  ```
  sh scripts/install-packages.sh
  sh scripts/process-tree.sh
  sh scripts/process-remotes.sh
  ```  
  Or via Node wrapper.

- [ ] After making changes in `src/`, commit & push your branch:  
  ```
  git add .
  git commit -m "Describe your changes"
  git push origin feature/my-feature
  ```

- [ ] Other teammates pull your changes and rerun the scripts before testing.  

> Rule of thumb: Treat the `.rbxl` in Studio as temporary; `src/` is the source of truth.

---

### Normal workflow (after pulling changes)

- [ ] Pull latest changes:  
  ```
  git pull
  ```

- [ ] Reinstall/update packages:  
  ```
  rokit install
  ```

- [ ] Run setup scripts:  
  ```
  sh scripts/install-packages.sh
  sh scripts/process-tree.sh
  sh scripts/process-remotes.sh --verbose
  ```  
  Or Node wrapper.

- [ ] Start Rojo and connect Studio

---

### Working in branches

- [ ] Make a new branch for each feature/bugfix:  
  ```
  git checkout -b feature/my-feature
  ```

- [ ] Test scripts after changes:  
  ```
  sh scripts/process-tree.sh
  sh scripts/process-remotes.sh
  ```  
  Or Node wrapper

- [ ] Commit & push:  
  ```
  git add .
  git commit -m "Describe changes"
  git push origin feature/my-feature
  ```

- [ ] Merge with main after pulling latest:  
  ```
  git checkout main
  git pull
  git checkout feature/my-feature
  git merge main
  ```

---

### Help

- [ ] Show help for scripts:  
  ```
  sh scripts/install-packages.sh --help
  sh scripts/process-tree.sh --help
  sh scripts/process-remotes.sh --help
  ```  
  Or Node wrapper

---

### Notes

- Node wrapper is optional — flags work the same as `.sh` scripts.  
- Always run scripts from the project root.

---

# Git Branch Cheat Sheet

### ✅ Branch for:
- Features, bug fixes, scripts, `.zap` files, assets, project structure  
- Example naming:  
  ```
  feature/<short-description>
  bugfix/<short-description>
  script/<short-description>
  ```

### ❌ Don’t branch for:
- Personal configs, running scripts locally, minor README tweaks

### 📝 Basic workflow:
1. Pull latest `main`  
2. Create branch  
3. Make changes, test, run scripts  
4. Commit & push  
5. Open pull request to `main`  

> Rule of thumb: If it affects the project, other teammates, or game logic — branch for it.