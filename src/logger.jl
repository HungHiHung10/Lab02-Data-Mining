"""
Module chứa Logger hướng đối tượng (OOP) dùng cho Evaluation.
"""

struct EvaluationLogger
end

function log_info(l::EvaluationLogger, msg...)
    printstyled("[info] ", color=:cyan, bold=true)
    println(msg...)
end

function log_warning(l::EvaluationLogger, msg...)
    printstyled("[warning] ", color=:yellow, bold=true)
    println(msg...)
end

function log_success(l::EvaluationLogger, msg...)
    printstyled("[success] ", color=:green, bold=true)
    println(msg...)
end

function log_fail(l::EvaluationLogger, msg...)
    printstyled("[fail] ", color=:red, bold=true)
    println(msg...)
end

function log_process(l::EvaluationLogger, msg...)
    printstyled("[process] ", color=:blue, bold=true)
    println(msg...)
end

function log_metric(l::EvaluationLogger, msg...)
    print("   ")
    printstyled("[metric] ", color=:magenta, bold=true)
    println(msg...)
end

function log_phase(l::EvaluationLogger, title)
    println("\n", "_"^50)
    printstyled("[phase] ", color=:white, bold=true)
    printstyled(" ", title, "\n", color=:white, bold=true)
    println("_"^50)
end
