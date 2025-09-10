# Copilot Instructions for FixUpdateRadar Plugin

## Repository Overview

This repository contains the **FixUpdateRadar** SourcePawn plugin for SourceMod, which fixes issues with the UpdateRadar usermessage on large Source engine game servers. The plugin addresses message size limitations by intelligently splitting large radar updates into smaller, manageable chunks.

### Key Plugin Functionality
- **Problem Solved**: Large servers experience issues with UpdateRadar usermessages exceeding size limits
- **Solution**: Intercepts large UpdateRadar messages, splits them into chunks, and queues them for transmission
- **Target Games**: Source engine games (CS:GO, CS2, TF2, etc.)
- **Server Impact**: Minimal performance overhead, fixes radar display issues on servers with many players

## Technical Environment

### Core Technologies
- **Language**: SourcePawn (.sp files)
- **Platform**: SourceMod 1.11.0+ (currently using 1.11.0-git6917)
- **Build System**: SourceKnight (modern SourcePawn build tool)
- **Compiler**: SourcePawn compiler via SourceKnight
- **CI/CD**: GitHub Actions with automated building and releases

### Build System (SourceKnight)
This project uses **SourceKnight** instead of traditional spcomp compilation:
- Configuration: `sourceknight.yaml` in repository root
- Build command: SourceKnight automatically handles dependencies and compilation
- Output: Compiled .smx files in `/addons/sourcemod/plugins`
- Dependencies: Automatically downloads SourceMod version specified in config

### Project Structure
```
/
├── .github/
│   ├── workflows/ci.yml        # GitHub Actions CI/CD pipeline
│   └── copilot-instructions.md # This file
├── addons/sourcemod/scripting/
│   └── FixUpdateRadar.sp       # Main plugin source code
├── sourceknight.yaml          # Build configuration
└── .gitignore                  # Git ignore rules
```

## SourcePawn Coding Standards

### Code Style (Enforced in this repository)
- **Indentation**: Use tabs (4 spaces equivalent)
- **Variable Naming**:
  - Local variables & parameters: `camelCase` (e.g., `playerCount`, `messageIndex`)
  - Function names: `PascalCase` (e.g., `SendQueuedMsg`, `GetOpenQueue`)
  - Global variables: `g_` prefix + `camelCase` (e.g., `g_bQueued`, `g_iBits`)
  - Constants: `UPPER_CASE` with underscores (e.g., `QUEUE_SIZE`, `MAXPLAYERS`)

### Required Pragmas
```sourcepawn
#pragma semicolon 1        // Enforce semicolons
#pragma newdecls required  // Enforce new declaration syntax
```

### Memory Management Best Practices
- Use `delete` directly without null checks (SourceMod handles null gracefully)
- Prefer `StringMap`/`ArrayList` over arrays for dynamic data
- Always use `delete` instead of `.Clear()` for StringMap/ArrayList to prevent memory leaks
- Implement proper cleanup in `OnPluginEnd()` if needed

### Plugin Structure Standards
```sourcepawn
// 1. Includes and pragmas
#pragma semicolon 1
#include <sourcemod>
#pragma newdecls required

// 2. Constants and defines
#define QUEUE_SIZE 24

// 3. Global variables (with g_ prefix)
bool g_bConnected[MAXPLAYERS+1];

// 4. Plugin info
public Plugin myinfo = {
    name = "Plugin Name",
    author = "Author",
    description = "Description", 
    version = "1.0.0",
    url = "URL"
};

// 5. Core functions (OnPluginStart, etc.)
// 6. Event handlers and callbacks
// 7. Helper functions
```

## Development Workflow

### Building the Plugin
```bash
# Using SourceKnight (automatic via CI/CD)
sourceknight build

# Manual compilation (if needed for development)
# SourceKnight handles this automatically
```

### Testing Procedure
1. **Local Development**: Test on a local SourceMod server
2. **CI Validation**: GitHub Actions automatically builds on push/PR
3. **Manual Testing**: Deploy to test server and verify radar functionality with multiple players
4. **Performance Testing**: Monitor server performance with plugin enabled

### CI/CD Pipeline
- **Trigger**: Push to any branch, PRs, manual dispatch
- **Build**: Uses `maxime1907/action-sourceknight@v1` action
- **Testing**: Compilation validation (no runtime tests currently)
- **Release**: Automatic releases on main/master branch and tags
- **Artifacts**: Creates `.tar.gz` packages with compiled plugins

## Plugin-Specific Context

### Core Algorithm Understanding
The FixUpdateRadar plugin uses a sophisticated queuing system:

1. **Message Interception**: Hooks `UpdateRadar` usermessage
2. **Size Check**: If message exceeds 253 bytes, splits into chunks
3. **Bit-by-Bit Processing**: Reads boolean values from the message buffer
4. **Chunk Management**: Splits at 2016 bits (252 bytes) per chunk
5. **Queue System**: Uses a fixed-size queue (24 slots) to manage chunks
6. **Deferred Transmission**: Sends queued chunks on next game frame

### Key Variables and Their Purpose
- `g_bQueued[QUEUE_SIZE]`: Tracks which queue slots contain pending messages
- `g_iBits[QUEUE_SIZE][2048]`: Stores message bits, -1 indicates end of message
- `g_iPlayers[QUEUE_SIZE][MAXPLAYERS+1]`: Recipient lists for each queued message
- `g_iPlayersNum[QUEUE_SIZE]`: Number of recipients per queued message
- `g_bConnected[MAXPLAYERS+1]`: Tracks client connection state

### Critical Functions
- `Hook_UpdateRadar()`: Main message interceptor and splitter
- `SendQueuedMsg()`: Transmits individual message chunks
- `GetOpenQueue()`: Finds available queue slot (with fallback)
- `OnGameFrame()`: Processes and sends all queued messages

### Performance Considerations
- **Queue Size**: Limited to 24 slots to prevent memory issues
- **Frame-Based Processing**: Processes queue once per game frame to avoid lag
- **Connection Validation**: Removes disconnected players before transmission
- **Fallback Logic**: Overwrites oldest queue slot if no free slots available

## Common Development Tasks

### Adding New Features
1. Follow existing code patterns and naming conventions
2. Add new global variables with `g_` prefix
3. Use proper error handling for all SourceMod API calls
4. Test thoroughly on servers with varying player counts

### Debugging Issues
1. **Build Errors**: Check SourceKnight configuration and SourceMod version compatibility
2. **Runtime Issues**: Add logging with `LogMessage()` or `PrintToServer()`
3. **Memory Issues**: Verify proper cleanup and queue management
4. **Performance Issues**: Profile using SourceMod's built-in profiler

### Version Management
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Update version in plugin info block
- Tag releases appropriately for automatic CI/CD deployment
- Maintain compatibility with minimum SourceMod version (1.11.0+)

## Security and Performance Notes

### Security Considerations
- Plugin processes user messages - ensure no buffer overflows
- Validate all array access with proper bounds checking
- Handle edge cases gracefully (empty messages, disconnected players)

### Performance Guidelines
- Minimize operations in `OnGameFrame()` as it runs every server tick
- Avoid unnecessary string operations in frequently called functions
- Cache expensive calculations where possible
- Monitor queue usage to prevent overflow scenarios

### Compatibility Requirements
- **Minimum SourceMod**: 1.11.0
- **Game Compatibility**: All Source engine games with radar functionality
- **Server Requirements**: No additional dependencies beyond SourceMod

This plugin is critical for large servers and should be thoroughly tested before deployment to production environments.