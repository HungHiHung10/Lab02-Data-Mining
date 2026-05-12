"""
Module chứa Logger
"""

struct Logger
end

function info(l::Logger, msg...)
    printstyled("[info] ", color=:cyan, bold=true)
    println(msg...)
end

function warning(l::Logger, msg...)
    printstyled("[warning] ", color=:yellow, bold=true)
    println(msg...)
end

function success(l::Logger, msg...)
    printstyled("[success] ", color=:green, bold=true)
    println(msg...)
end

function fail(l::Logger, msg...)
    printstyled("[fail] ", color=:red, bold=true)
    println(msg...)
end

function process(l::Logger, msg...)
    printstyled("[process] ", color=:blue, bold=true)
    println(msg...)
end

function metric(l::Logger, msg...)
    print("   ")
    printstyled("[metric] ", color=:magenta, bold=true)
    println(msg...)
end

function phase(l::Logger, title)
    println("\n", "_"^50)
    printstyled("[phase] ", color=:white, bold=true)
    printstyled(" ", title, "\n", color=:white, bold=true)
    println("_"^50)
end
