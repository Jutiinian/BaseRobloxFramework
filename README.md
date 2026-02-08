# Setup & Team Workflow Checklist

### Environment

- [ ] Make sure you can run `.sh` scripts and Node.js scripts  
      (macOS/Linux terminal, Git Bash, WSL, etc.)  
- [ ] OPTIONALLY, you can just run Node.js scripts using the Node wrapper.

---

### Tools

- [ ] Installed via Rokit (don’t install manually):  
  - rojo  
  - wally  
  - wally-package-types  

- [ ] Install Rokit if you haven’t already:  
  👉 https://github.com/rojo-rbx/rokit

- [ ] From the project root:  
  ```
  rokit install
  ```

---

### First-time setup

You can run either the `.sh` scripts or the Node wrapper (`run-sh.js`).

- [ ] Install packages and generate types:  
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

### Normal workflow (after pulling changes)

- [ ] Pull latest changes:  
  ```
  git pull
  ```

- [ ] Reinstall/update packages if needed:  
  ```
  rokit install
  ```

- [ ] Run setup scripts (packages/tree/remotes) via `.sh` or Node wrapper:  
  ```
  sh scripts/install-packages.sh
  sh scripts/process-tree.sh
  sh scripts/process-remotes.sh --verbose
  ```  
  Or:  
  ```
  node scripts/run-sh.js scripts/install-packages.sh
  node scripts/run-sh.js scripts/process-tree.sh
  node scripts/run-sh.js scripts/process-remotes.sh --verbose
  ```

- [ ] Start Rojo and connect Studio:  
  ```
  rojo serve
  ```

---

### Working in branches

- [ ] Make a new branch for your feature:  
  ```
  git checkout -b feature/your-feature-name
  ```

- [ ] After making changes, run scripts again to update everything:  
  ```
  sh scripts/process-tree.sh
  sh scripts/process-remotes.sh
  ```  
  Or Node wrapper:  
  ```
  node scripts/run-sh.js scripts/process-tree.sh
  node scripts/run-sh.js scripts/process-remotes.sh
  ```

- [ ] Test in Studio, commit, and push:  
  ```
  git add .
  git commit -m "Describe your changes"
  git push origin feature/your-feature-name
  ```

- [ ] Merge with main after pulling latest changes:  
  ```
  git checkout main
  git pull
  git checkout feature/your-feature-name
  git merge main
  ```

- [ ] Resolve conflicts if needed, rerun scripts, test, then push.

---

### Help / Useful flags

- [ ] Show help for scripts:  
  ```
  sh scripts/install-packages.sh --help
  sh scripts/process-tree.sh --help
  sh scripts/process-remotes.sh --help
  ```  
  Or Node wrapper:  
  ```
  node scripts/run-sh.js scripts/install-packages.sh --help
  node scripts/run-sh.js scripts/process-tree.sh --help
  node scripts/run-sh.js scripts/process-remotes.sh --help
  ```

- [ ] Clean install packages:  
  ```
  sh scripts/install-packages.sh --clean
  node scripts/run-sh.js scripts/install-packages.sh --clean
  ```

- [ ] Dry run remotes:  
  ```
  sh scripts/process-remotes.sh --dry-run
  node scripts/run-sh.js scripts/process-remotes.sh --dry-run
  ```

- [ ] Watch remotes:  
  ```
  sh scripts/process-remotes.sh --watch
  node scripts/run-sh.js scripts/process-remotes.sh --watch
  ```

---

### Notes

- The Node wrapper (`run-sh.js`) is fully optional — you can run `.sh` scripts directly.  
- Any flags/arguments you pass to `.sh` scripts also work via the Node wrapper.  
- Always run scripts from the project root.  
- This workflow keeps things **cross-platform** (Windows/macOS/Linux) and ensures everyone on the team is in sync.