const std = @import("std");
const ast = @import("ast.zig");
const value = @import("value.zig");
const env_mod = @import("env.zig");

const Expr = ast.Expr;
const Value = value.Value;
const Env = value.Env;
const PrimOp = value.PrimOp;

pub const InterpError = error{
    UnboundIdentifier,
    ArityMismatch,
    TypeError,
    DivisionByZero,
    NotAFunction,
    OutOfMemory,
};

/// Evaluates an expression in the given environment and returns its value.
/// @params `allocator` is used for allocating argument arrays during function application.
/// `expr` - expression to evaluate
/// `env` - environment 
pub fn interp(allocator: std.mem.Allocator, expr: *const Expr, env: *const Env) InterpError!Value {
    switch (expr.*) {

        // wraps the raw number or string in a Value and returns it.
        .num => |n| return Value{ .num = n },
        .str => |s| return Value{ .str = s },

        // Fails with UnboundIdentifier if the name is not in scope.
        .id => |name| {
            return env_mod.lookup(env, name) catch return error.UnboundIdentifier;
        },

        // e.g. {fun (x) => x} -> closureV([x], body, env)
        .fun_expr => |f| {
            return Value{ .closure = .{
                .params = f.params,
                .body = f.body,
                .env = env,
            } };
        },

        // e.g. {if true 1 2} -> 1
        .if_expr => |i| {
            const test_val = try interp(allocator, i.test_expr, env);
            switch (test_val) {
                .boolean => |b| {
                    if (b) {
                        return interp(allocator, i.then_expr, env);
                    } else {
                        return interp(allocator, i.else_expr, env);
                    }
                },
                else => return error.TypeError,
            }
        },

        // e.g. {+ 1 2} -> evaluates +, evaluates 1, evaluates 2, then applies
        .app => |a| {
            const func_val = try interp(allocator, a.func, env);

            // Allocate an array and fill it with the evaluated argument values.
            var arg_vals = try allocator.alloc(Value, a.args.len);
            for (a.args, 0..) |arg_expr, i| {
                arg_vals[i] = try interp(allocator, arg_expr, env);
            }

            return applyValue(allocator, func_val, arg_vals);
        },
    }
}

/// Applies a function value to a list of already-evaluated argument values.
/// Handles two cases: user-defined closures and built-in primitive operators.
/// Anything else (numbers, strings, booleans) is not callable and returns NotAFunction.
fn applyValue(allocator: std.mem.Allocator, func: Value, args: []const Value) InterpError!Value {
    switch (func) {
        .closure => |c| {
            // Checks number of arguments
            if (c.params.len != args.len) return error.ArityMismatch;

            // Bind each parameter to its argument in the closure's environment,
            // then evaluate the body in that new environment.
            const new_env = env_mod.extendMulti(allocator, c.env, c.params, args) catch
                return error.OutOfMemory;
            return interp(allocator, c.body, new_env);
        },
        // Dispatch built-in operators to their handler.
        .primop => |op| return applyPrimop(op, args),
        // Numbers, strings, booleans are not functions.
        else => return error.NotAFunction,
    }
}

/// Handles the built-in primitive operations.
fn applyPrimop(op: PrimOp, args: []const Value) InterpError!Value {
    switch (op) {
        
        .plus => {
            if (args.len != 2) return error.ArityMismatch;
            const a = switch (args[0]) { .num => |n| n, else => return error.TypeError };
            const b = switch (args[1]) { .num => |n| n, else => return error.TypeError };
            return Value{ .num = a + b };
        },

        .minus => {
            if (args.len != 2) return error.ArityMismatch;
            const a = switch (args[0]) { .num => |n| n, else => return error.TypeError };
            const b = switch (args[1]) { .num => |n| n, else => return error.TypeError };
            return Value{ .num = a - b };
        },

        .times => {
            if (args.len != 2) return error.ArityMismatch;
            const a = switch (args[0]) { .num => |n| n, else => return error.TypeError };
            const b = switch (args[1]) { .num => |n| n, else => return error.TypeError };
            return Value{ .num = a * b };
        },

        // Returns DivisionByZero if the second argument is 0.
        .div => {
            if (args.len != 2) return error.ArityMismatch;
            const a = switch (args[0]) { .num => |n| n, else => return error.TypeError };
            const b = switch (args[1]) { .num => |n| n, else => return error.TypeError };
            if (b == 0) return error.DivisionByZero;
            return Value{ .num = a / b };
        },

        // Not Implemented yet: <=, substring, strlen, equal?, error
        .leq => return error.NotAFunction,
        .strlen => return error.NotAFunction,
        .substring => return error.NotAFunction,
        .equal_huh => return error.NotAFunction,
        .error_fn => return error.NotAFunction,
    }
}
pub fn topInterp(allocator: std.mem.Allocator, expr: *const Expr) ![]const u8 {
    const top_env = try env_mod.makeTopEnv(allocator);
    const result = try interp(allocator, expr, top_env);
    return value.serialize(allocator, result);
}