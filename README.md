# BaseRobloxFramework

A framework I'm slowly building on to perfection (in my opinion).

## Goal
- Make something I enjoy using  
- Keep it easy to work with  
- Make it easy to add systems/services without getting overwhelmed  
- Keep it clean, organized, and performant  
- Avoid having to redo it like I’ve done many times before

## Some notes
- Services are like a singleton that handles specific aspects of the game
    - Usually has a server version and sometimes client for syncing
    - Has public API functions other scripts can call
    - Stays independent from each other mostly

## Terminal Commands
- sh scripts/process-tree.sh
- sh scripts/process-remotes.sh
- wally install
- wally-package-types --sourcemap sourcemap.json Packages/