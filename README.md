# zig-lang-racketimplementation

## Requirements

- Zig 0.15.2 — install with `brew install zig`

## Project Structure

```
ziginterpreter/
├── src/
│   ├── ast.zig       
│   ├── value.zig     
│   ├── env.zig       
│   ├── interp.zig    
│   └── examples.zig  
├── tests/
│   └── tests.zig     
└── build.zig         
```

## Running Tests

From the project root:

```bash
zig build test --summary all
```

## Build Configuration

The `build.zig` file wires up module dependencies so that each file can
import the others correctly. If you add a new file to `src/` that imports
another module, you need to add a corresponding `addImport` call in `build.zig`.