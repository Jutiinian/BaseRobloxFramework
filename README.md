# Setup Checklist

### Environment

- [ ] Make sure you can run `.sh` scripts and Node.js scripts  
      (macOS/Linux terminal, Git Bash, WSL, etc.)
- [ ] OPTIONALLY, you just need to be able to run Node.js scripts

---

### Tools

- [ ] Make sure the following are installed (via Rokit, don’t install manually):  
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

You can either run the `.sh` scripts **or** the Node wrapper (`run-sh.js`) — both work.

- [ ] Install packages and generate types:  
  ```
  sh scripts/install-packages.sh
  ```  
  Or via Node:  
  ```
  node scripts/run-sh.js scripts/install-packages.sh
  ```

- [ ] Generate Rojo tree and sourcemap:  
  ```
  sh scripts/process-tree.sh
  ```  
  Or via Node:  
  ```
  node scripts/run-sh.js scripts/process-tree.sh
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

You can run commands either via `.sh` scripts or the Node wrapper.

- [ ] Reinstall tools/packages:  
  ```
  rokit install
  ```

- [ ] Install packages:  
  ```
  sh scripts/install-packages.sh
  ```  
  Or:  
  ```
  node scripts/run-sh.js scripts/install-packages.sh
  ```

- [ ] Generate project tree:  
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
  node scripts/run-sh.js scripts/process-remotes.sh --verbose
  ```

---

### Useful commands / flags

- [ ] Show help for scripts:  
  ```
  sh scripts/install-packages.sh --help
  sh scripts/process-tree.sh --help
  sh scripts/process-remotes.sh --help
  ```  
  Or via Node:  
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

- [ ] Watch remotes for changes:  
  ```
  sh scripts/process-remotes.sh --watch
  node scripts/run-sh.js scripts/process-remotes.sh --watch
  ```

---

### Notes

- The Node wrapper (`run-sh.js`) is fully optional — you can always run the `.sh` scripts directly.  
- Any flags/arguments you pass to the `.sh` scripts also work via the Node wrapper.  
- Always run scripts from the project root.  