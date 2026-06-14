using Pkg
Pkg.instantiate()

using ArgParse

include("src/FPGrowth.jl")
using .FPGrowth
include("src/logger.jl")
include("src/utils.jl")
using .Utils

function parse_commandline()
    s = ArgParseSettings(description="FP-Growth Algorithm Implementation")

    @add_arg_table! s begin
        "--input", "-i"
            help = "Path to input data file (SPMF format)"
            arg_type = String
            required = true
        "--minsup", "-s"
            help = "Minimum support threshold (ratio 0.0 < s <= 1.0 or absolute integer)"
            arg_type = Float64
            required = true
        "--output", "-o"
            help = "Path to output result file"
            arg_type = String
            default = "results/output.txt"
        "--algorithm", "-a"
            help = "FP-Growth implementation to run: base or opt"
            arg_type = String
            default = "base"
            range_tester = x -> x in ("base", "opt")
    end

    return parse_args(s)
end

function main()
    args = parse_commandline()
    logger = Logger()

    input_file = args["input"]
    minsup = args["minsup"]
    output_file = args["output"]
    algorithm = args["algorithm"]

    phase(logger, "FP-GROWTH STARTING")
    
    if !isfile(input_file)
        fail(logger, "Input file not found: ", input_file)
        return
    end

    process(logger, "Reading data from: ", input_file)
    
    try
        transactions = FPGrowth.read_spmf(input_file)
        total_txs = length(transactions)
        success(logger, "Successfully loaded ", total_txs, " transactions.")
        
        # Determine absolute minsup
        min_sup_abs = minsup > 1.0 ? round(Int, minsup) : ceil(Int, minsup * total_txs)
        metric(logger, "Minimum support threshold applied: ", minsup, " (Absolute: ", min_sup_abs, ")")
        
        process(logger, "Executing FP-Growth (", algorithm, ")...")
        
        # Dọn rác bộ nhớ trước khi đo
        GC.gc()
        time_before = time_ns()
        frequent_itemsets = algorithm == "opt" ?
            FPGrowth.fpgrowth_opt(transactions, min_sup_abs) :
            FPGrowth.fpgrowth(transactions, min_sup_abs)
        time_after = time_ns()
        
        exec_time = (time_after - time_before) / 1e9
        success(logger, "Mined ", length(frequent_itemsets), " frequent itemsets in ", round(exec_time, digits=4), " seconds.")
        
        process(logger, "Writing results to: ", output_file)
        # Tạo thư mục nếu chưa có
        out_directory = dirname(output_file)
        if !isempty(out_directory) && !isdir(out_directory)
            mkpath(out_directory)
        end
        
        FPGrowth.write_spmf(output_file, frequent_itemsets)
        # success(logger, "Results written successfully!")
        
    catch e
        fail(logger, "Error: ", e)
        showerror(stdout, e)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
