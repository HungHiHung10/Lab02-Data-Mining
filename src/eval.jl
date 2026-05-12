"""
Các hàm đánh giá (Evaluation) cho FPGrowth.
Bao gồm: eval_correctness, vis_correctness, eval_performance, vis_performance,
          eval_scalability, vis_scalability.

Các hàm này phụ thuộc vào:
  - FPGrowth module (cần include trước)
  - Utils module (cần include trước)
  - Logger (cần include logger.jl trước)
  - CSV, DataFrames, Plots, Plots.PlotMeasures, ProgressMeter, Statistics
"""

using CSV
using DataFrames
using Plots
using Plots.PlotMeasures
using ProgressMeter
using Statistics

# ========================
# CORRECTNESS
# ========================
function eval_correctness(config, logger)
    phase(logger, "CORRECTNESS")
    info(logger, "Verify accuracy at the threshold MinSup=", config["Minimum Support"] * 100, "%")
    
    transactions = FPGrowth.read_spmf(config["dataset_path"])
    total_txs = length(transactions)
    min_sup_abs = ceil(Int, config["Minimum Support"] * total_txs)
    
    # 1. Chạy Julia
    process(logger, "Executing Julia From Scratch (Proposed)...")
    julia_result = FPGrowth.fpgrowth(transactions, min_sup_abs)
    FPGrowth.write_spmf(config["proposed_result"], julia_result)
    
    # 2. Chạy SPMF
    process(logger, "Executing SPMF Built-in (Baseline)...")
    Utils.execute_spmf(config, config["dataset_path"], config["baseline_result"], config["Minimum Support"])
    
    # 3. So khớp
    info(logger, "Comparing results...")
    my_res = Utils.parse_output(config["proposed_result"])
    spmf_res = Utils.parse_output(config["baseline_result"])
    
    missing_in_mine = length(setdiff(spmf_res, my_res))
    missing_in_spmf = length(setdiff(my_res, spmf_res))
    
    return Dict(
        "Julia_Count" => length(my_res),
        "SPMF_Count" => length(spmf_res),
        "Missing_in_Julia" => missing_in_mine,
        "Missing_in_SPMF" => missing_in_spmf
    )
end

function vis_correctness(res::Dict, logger)
    phase(logger, "Visualize")
    if res["Missing_in_Julia"] == 0 && res["Missing_in_SPMF"] == 0
        success(logger, "Correct (", res["Julia_Count"], " frequent itemsets)")
    else
        fail(logger, "Incorrect: Missing in Julia: ", res["Missing_in_Julia"], " | Missing in SPMF: ", res["Missing_in_SPMF"])
    end
    
    # Vẽ biểu đồ Cột
    categories = ["Julia From Scratch", "SPMF Built-in"]
    counts = [res["Julia_Count"], res["SPMF_Count"]]
    
    p = bar(categories, counts, 
            title="Correctness evaluation",
            ylabel="Itemsets", 
            legend=false, 
            color=[:blue, :green], 
            bar_width=0.4)
    display(plot(p, bottom_margin=5mm))
end

# ========================
# PERFORMANCE
# ========================
function eval_performance(config, logger)
    process(logger, "Warming up JIT Compiler...")
    FPGrowth.fpgrowth([[1,2], [1,3], [1,2,3]], 1)
    phase(logger, "PERFORMANCE")
    transactions = FPGrowth.read_spmf(config["dataset_path"])
    total_txs = length(transactions)
    info(logger, "Transactions: ", total_txs)
    
    N_RUNS = get(config, "n_executes", 5)
    results_df = DataFrame(MinSup=Float64[], JuliaTime=Float64[], JuliaMemory=Float64[], SPMFTime=Float64[], SPMFMemory=Float64[])

    @showprogress "Benchmarking... " for min_sup_ratio in config["min_sups"]
        process(logger, "Executing with min_sup = ", min_sup_ratio * 100, "% in ", N_RUNS, " times...")
        min_sup_abs = ceil(Int, min_sup_ratio * total_txs)
        
        julia_times = Float64[]
        julia_memories  = Float64[] 
        for _ in 1:N_RUNS
            GC.gc() 
            mem_bytes = @allocated begin
                t0 = time_ns()
                FPGrowth.fpgrowth(transactions, min_sup_abs)
                t1 = time_ns()
            end
            push!(julia_times, (t1 - t0) / 1e9)
            push!(julia_memories,  mem_bytes / (1024^2))
        end
        julia_time   = median(julia_times)
        julia_memory = median(julia_memories)
        
        spmf_time, spmf_memory = Utils.execute_spmf(config, config["dataset_path"], config["baseline_result"], min_sup_ratio)
        
        metric(logger, "Julia From Scratch (Proposed)  → Time: ", round(julia_time, digits=3), "s | Memory: ", round(julia_memory, digits=2), " MB  (median of ", N_RUNS, " runs)")
        metric(logger, "SPMF Built-in (Baseline)  → Time: ", round(spmf_time, digits=3), "s | Memory: ", round(spmf_memory, digits=2), " MB")
        
        push!(results_df, (min_sup_ratio, julia_time, julia_memory, spmf_time, spmf_memory))
    end
    
    CSV.write(config["performance_result"], results_df)
    success(logger, "Saved at ", config["performance_result"])
    return results_df
end

function vis_performance(df::DataFrame, logger)
    phase(logger, "visualize")
    df_sorted = sort(df, :MinSup, rev=true)
    x_vals = df_sorted.MinSup .* 100
    
    p_time = plot(x_vals, df_sorted.JuliaTime, label="Julia", marker=:circle, linewidth=2, color=:blue,
                  title="Execution time", xlabel="MinSup (%)", ylabel="Second (s)", legend=:topright)
    plot!(p_time, x_vals, df_sorted.SPMFTime, label="SPMF", marker=:square, linewidth=2, color=:green)
    
    p_memory = plot(x_vals, df_sorted.JuliaMemory, label="Julia", marker=:circle, linewidth=2, color=:blue,
                 title="Memory consumption", xlabel="MinSup (%)", ylabel="Megabytes (MB)", legend=:topright)
    plot!(p_memory, x_vals, df_sorted.SPMFMemory, label="SPMF", marker=:square, linewidth=2, color=:green)
    
    display(plot(p_time, p_memory, layout=(1,2), size=(900, 400), bottom_margin=8mm, left_margin=5mm))
end

# ========================
# SCALABILITY
# ========================
function eval_scalability(config, logger)
    process(logger, "Warming up JIT Compiler...")
    FPGrowth.fpgrowth([[1,2], [1,3], [1,2,3]], 1)
    phase(logger, "SCALABILITY")
    transactions = FPGrowth.read_spmf(config["dataset_path"])
    total_txs = length(transactions)
    fixed_minsup = config["Minimum Support"]
    info(logger, "Minimum Support=", fixed_minsup * 100, "%")
    
    results_df = DataFrame(DataRatio=Float64[], NumTransactions=Int[], JuliaTime=Float64[], SPMFTime=Float64[])
    
    @showprogress "Benchmarking... " for ratio in config["data_ratios"]
        num_tx = ceil(Int, total_txs * ratio)
        process(logger, "Data Ratio = ", ratio * 100, "% (", num_tx, " giao dịch) ...")
        
        sliced_txs = transactions[1:num_tx]
        temp_data_path = "../results/temp_chess_$(ratio).dat"
        open(temp_data_path, "w") do f
            for tx in sliced_txs
                println(f, join(tx, " "))
            end
        end
        
        min_sup_abs = ceil(Int, fixed_minsup * num_tx)
        
        # Julia
        GC.gc() 
        time_before = time_ns()
        FPGrowth.fpgrowth(sliced_txs, min_sup_abs)
        time_after = time_ns()
        julia_time = (time_after - time_before) / 1e9
        
        # SPMF
        spmf_time, _ = Utils.execute_spmf(config, temp_data_path, config["baseline_result"], fixed_minsup)
        
        metric(logger, "Julia From Scratch (Proposed) Time: ", round(julia_time, digits=3), "s | SPMF Built-in (Baseline) Time: ", round(spmf_time, digits=3), "s")
        push!(results_df, (ratio, num_tx, julia_time, spmf_time))
        
        rm(temp_data_path, force=true)
    end
    
    CSV.write(config["scalability_result"], results_df)
    success(logger, "Saved at ", config["scalability_result"])
    return results_df
end

function vis_scalability(df::DataFrame, logger)
    phase(logger, "visualize")
    x_vals = df.DataRatio .* 100
    
    p_scale = plot(x_vals, df.JuliaTime, label="Julia", marker=:circle, linewidth=2, color=:blue,
                   title="Scalability evaluation",
                   xlabel="Data ratio (%)", ylabel="Execution time (s)", legend=:topleft)
    plot!(p_scale, x_vals, df.SPMFTime, label="SPMF", marker=:square, linewidth=2, color=:green)
    
    display(plot(p_scale, bottom_margin=8mm, left_margin=5mm))
end
