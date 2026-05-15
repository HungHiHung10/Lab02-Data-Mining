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
function eval_correctness(config, logger; algo=FPGrowth.fpgrowth)
    phase(logger, "CORRECTNESS")
    info(logger, "Verify accuracy at the threshold MinSup=", config["Minimum Support"] * 100, "%")
    
    transactions = FPGrowth.read_spmf(config["dataset_path"])
    total_txs = length(transactions)
    min_sup_abs = ceil(Int, config["Minimum Support"] * total_txs)
    
    # 1. Chạy Julia
    process(logger, "Executing Julia From Scratch (Proposed)...")
    julia_result = algo(transactions, min_sup_abs)
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
function eval_performance(config, logger; algo=FPGrowth.fpgrowth)
    process(logger, "Warming up JIT Compiler...")
    algo([[1,2], [1,3], [1,2,3]], 1)
    phase(logger, "PERFORMANCE")
    transactions = FPGrowth.read_spmf(config["dataset_path"])
    total_txs = length(transactions)
    info(logger, "Transactions: ", total_txs)
    
    N_RUNS = get(config, "n_executes", 5)
    results_df = DataFrame(MinSup=Float64[], Itemsets=Int[], JuliaTime=Float64[], JuliaMemory=Float64[], SPMFTime=Float64[], SPMFMemory=Float64[])

    @showprogress "Benchmarking... " for min_sup_ratio in config["min_sups"]
        process(logger, "Executing with min_sup = ", min_sup_ratio * 100, "% in ", N_RUNS, " times...")
        min_sup_abs = ceil(Int, min_sup_ratio * total_txs)
        
        julia_times = Float64[]
        julia_memories  = Float64[] 
        itemset_count = 0
        for _ in 1:N_RUNS
            GC.gc() 
            local frequent_itemsets
            mem_bytes = @allocated begin
                t0 = time_ns()
                frequent_itemsets = algo(transactions, min_sup_abs)
                t1 = time_ns()
            end
            itemset_count = length(frequent_itemsets)
            push!(julia_times, (t1 - t0) / 1e9)
            push!(julia_memories,  mem_bytes / (1024^2))
        end
        julia_time   = median(julia_times)
        julia_memory = median(julia_memories)
        
        spmf_time, spmf_memory = Utils.execute_spmf(config, config["dataset_path"], config["baseline_result"], min_sup_ratio)
        
        metric(logger, "Julia From Scratch (Proposed)  → Time: ", round(julia_time, digits=3), "s | Memory: ", round(julia_memory, digits=2), " MB | Itemsets: ", itemset_count)
        metric(logger, "SPMF Built-in (Baseline)  → Time: ", round(spmf_time, digits=3), "s | Memory: ", round(spmf_memory, digits=2), " MB")
        
        push!(results_df, (min_sup_ratio, itemset_count, julia_time, julia_memory, spmf_time, spmf_memory))
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

function vis_minSupNFI(df::DataFrame, logger)
    phase(logger, "visualize output size")
    df_sorted = sort(df, :MinSup)
    x_vals = df_sorted.MinSup .* 100
    
    # Sử dụng thang đo log cho trục Y vì số lượng tập phổ biến thường tăng bùng nổ (exponential)
    p = plot(x_vals, df_sorted.Itemsets, 
             label="Number of Itemsets", 
             marker=:circle, 
             linewidth=2, 
             color=:orange,
             title="Relationship between MinSup and Output Size", 
             xlabel="MinSup (%)", 
             ylabel="Frequent Itemsets (FI)", 
             yscale=:log10,
             legend=:topright)
    
    display(plot(p, size=(700, 450), bottom_margin=8mm, left_margin=8mm))
end

# ========================
# SCALABILITY
# ========================
function eval_scalability(config, logger; algo=FPGrowth.fpgrowth)
    process(logger, "Warming up JIT Compiler...")
    algo([[1,2], [1,3], [1,2,3]], 1)
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
        algo(sliced_txs, min_sup_abs)
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

# ========================
# UNIT TESTS
# ========================
function run_unitTest(config, logger)
    phase(logger, "UNIT TESTING")
    test_files = config["datasets_path"]
    min_sup = config["Minimum Support"]
    results_dir = config["results_path"][1]
    
    info(logger, "Running tests on ", length(test_files), " toy datasets with MinSup=", min_sup*100, "%")
    
    passed = 0
    total = length(test_files)
    
    # We use a local copy for SPMF execution if needed, but here we can just update paths
    test_config = copy(config)
    
    for (i, file) in enumerate(test_files)
        process(logger, "Test ", i, "/", total, ": ", basename(file))
        
        julia_out = joinpath(results_dir, "temp_julia_out.txt")
        spmf_out = joinpath(results_dir, "temp_spmf_out.txt")
        
        test_config["proposed_result"] = julia_out
        test_config["baseline_result"] = spmf_out
        
        try
            transactions = FPGrowth.read_spmf(file)
            total_txs = length(transactions)
            min_sup_abs = ceil(Int, min_sup * total_txs)
            
            # Julia
            julia_result = FPGrowth.fpgrowth(transactions, min_sup_abs)
            FPGrowth.write_spmf(julia_out, julia_result)
            
            # SPMF
            Utils.execute_spmf(test_config, file, spmf_out, min_sup)
            
            # Compare
            julia_res = Utils.parse_output(julia_out)
            spmf_res = Utils.parse_output(spmf_out)
            
            missing_in_julia = length(setdiff(spmf_res, julia_res))
            missing_in_spmf = length(setdiff(julia_res, spmf_res))
            
            if missing_in_julia == 0 && missing_in_spmf == 0
                success(logger, "✓ Test ", i, " Passed (", length(julia_res), " itemsets)")
                passed += 1
            else
                fail(logger, "✗ Test ", i, " Failed! Missing in Julia: ", missing_in_julia, " | Missing in SPMF: ", missing_in_spmf)
            end
        catch e
            fail(logger, "✗ Test ", i, " Error: ", e)
        end
        
        # Cleanup
        rm(julia_out, force=true)
        rm(spmf_out, force=true)
    end
    
    accuracy = (passed / total) * 100
    phase(logger, "UNIT TEST RESULTS")
    if passed == total
        success(logger, "Accuracy Rate: ", round(accuracy, digits=2), "% (Passed ", passed, "/", total, ")")
    else
        fail(logger, "Accuracy Rate: ", round(accuracy, digits=2), "% (Passed ", passed, "/", total, ")")
    end
    
    return accuracy
end

# ========================
# OPTIMIZATION EVALUATION
# ========================
function eval_optimization(config, logger; min_sup=nothing)
    phase(logger, "OPTIMIZATION COMPARISON")
    
    # Lấy đường dẫn file: ưu tiên dataset_path
    path = haskey(config, "dataset_path") ? config["dataset_path"] : config["datasets_path"][1]
    
    # Lấy min_sup: ưu tiên tham số truyền vào, nếu không có thì lấy từ config
    Min_Sup = (min_sup !== nothing) ? min_sup : config["Minimum Support"]
    
    transactions = FPGrowth.read_spmf(path)
    total_txs = length(transactions)
    min_sup_abs = ceil(Int, Min_Sup * total_txs)
    
    info(logger, "Comparing Basic vs Optimized version on: ", basename(path))
    info(logger, "Threshold MinSup=", Min_Sup * 100, "%")
    
    # 1. Basic Version
    process(logger, "Running Basic FPGrowth...")
    GC.gc()
    T = eltype(eltype(transactions)) # Xác định kiểu của item (ví dụ Int64)
    res_basic = Dict{Vector{T}, Int}()
    t_basic = @elapsed res_basic = FPGrowth.fpgrowth(transactions, min_sup_abs)
    
    # 2. Optimized Version
    process(logger, "Running Optimized FPGrowth (Single Path Pruning + BitArray)...")
    GC.gc()
    res_opt = Dict{Vector{T}, Int}()
    t_opt = @elapsed res_opt = FPGrowth.fpgrowth_opt(transactions, min_sup_abs)
    
    # === KIỂM TRA TÍNH ĐÚNG ĐẮN (CORRECTNESS CHECK) ===
    is_correct = (res_basic == res_opt)
    if is_correct
        success(logger, "✓ Internal Consistency: Basic and Optimized versions match (", length(res_basic), " itemsets)")
    else
        fail(logger, "✗ Internal Discrepancy: Basic and Optimized results differ!")
        info(logger, "Basic count: ", length(res_basic), " | Optimized count: ", length(res_opt))
    end
    
    # === ĐỐI CHIẾU VỚI SPMF (NẾU CÓ CẤU HÌNH) ===
    if haskey(config, "spmf_path") && isfile(config["spmf_path"])
        process(logger, "Verifying results against SPMF Java baseline...")
        spmf_out = joinpath("..", "results", "spmf_bench_temp.txt") # Đảm bảo đường dẫn đúng
        Utils.execute_spmf(config, path, spmf_out, Min_Sup)
        res_spmf = Utils.parse_output(spmf_out)
        
        # Chuyển đổi res_opt (Dict) sang Set{String} để so sánh với kết quả từ SPMF
        res_opt_set = Set{String}()
        for (itemset, sup) in res_opt
            push!(res_opt_set, join(itemset, " ") * " - " * string(sup))
        end
        
        if res_opt_set == res_spmf
            success(logger, "✓ SPMF Verified: Julia results are identical to SPMF Java.")
        else
            fail(logger, "✗ SPMF Discrepancy! Julia results differ from SPMF Java.")
            info(logger, "Julia count: ", length(res_opt), " | SPMF count: ", length(res_spmf))
            
            # Debug: In ra một vài phần tử khác biệt nếu cần
            diff = setdiff(res_spmf, res_opt_set)
            if !isempty(diff)
                info(logger, "Sample missing in Julia: ", first(diff))
            end
        end
    end
    
    improvement = ((t_basic - t_opt) / t_basic) * 100
    metric(logger, "Basic Time: ", round(t_basic, digits=4), "s")
    metric(logger, "Optimized Time: ", round(t_opt, digits=4), "s")
    
    if improvement > 0
        success(logger, "Improvement: ", round(improvement, digits=2), "% faster")
    else
        info(logger, "No significant speedup observed for this dataset/minsup.")
    end
    
    return DataFrame(Version=["Basic", "Optimized"], ExecutionTime=[t_basic, t_opt])
end

function vis_optimization(df::DataFrame, logger)
    phase(logger, "visualize")
    p = bar(df.Version, df.ExecutionTime, 
            title="Basic vs Optimized FP-Growth",
            ylabel="Execution Time (s)",
            legend=false,
            color=[:gray, :blue],
            bar_width=0.5)
    display(plot(p, bottom_margin=5mm))
end

# ========================
# AVG TRANSACTION LENGTH
# ========================
function eval_tx_length(config, logger; algo=FPGrowth.fpgrowth)
    phase(logger, "TRANSACTION LENGTH")
    
    # Parameters
    num_tx = get(config, "num_transactions", 5000)
    universe_size = get(config, "universe_size", 500)
    lengths = get(config, "avg_lengths", [10, 20, 30, 40, 50])
    min_sup = get(config, "Minimum Support", 0.1)
    
    results_df = DataFrame(AvgLength=Float64[], JuliaTime=Float64[], JuliaMemory=Float64[], SPMFTime=Float64[], SPMFMemory=Float64[])
    
    @showprogress "Benchmarking Lengths... " for avg_len in lengths
        process(logger, "Average Length = ", avg_len, " items ...")
        
        temp_data_path = "../results/temp_len_$(avg_len).dat"
        Utils.generate_synthetic_data(num_tx, Float64(avg_len), universe_size, temp_data_path)
        
        transactions = Utils.read_spmf(temp_data_path)
        min_sup_abs = ceil(Int, min_sup * num_tx)
        
        # Julia
        GC.gc()
        mem_bytes = @allocated begin
            t0 = time_ns()
            algo(transactions, min_sup_abs)
            t1 = time_ns()
        end
        julia_time = (t1 - t0) / 1e9
        julia_mem = mem_bytes / (1024^2) # MB
        
        # SPMF
        spmf_time, spmf_mem = Utils.execute_spmf(config, temp_data_path, config["baseline_result"], min_sup)
        
        metric(logger, "AvgLen: $avg_len | Julia: $(round(julia_time, digits=3))s, $(round(julia_mem, digits=2))MB | SPMF: $(round(spmf_time, digits=3))s, $(round(spmf_mem, digits=2))MB")
        push!(results_df, (avg_len, julia_time, julia_mem, spmf_time, spmf_mem))
        
        rm(temp_data_path, force=true)
    end
    
    return results_df
end

function vis_tx_length(df::DataFrame, logger)
    phase(logger, "visualize")
    
    # Biểu đồ thời gian
    p_time = plot(df.AvgLength, df.JuliaTime, label="Julia", marker=:circle, color=:blue,
                  title="Execution Time vs Avg Length",
                  xlabel="Average Length", ylabel="Time (s)", legend=:topleft)
    plot!(p_time, df.AvgLength, df.SPMFTime, label="SPMF", marker=:square, color=:green)
    
    # Biểu đồ bộ nhớ
    p_mem = plot(df.AvgLength, df.JuliaMemory, label="Julia", marker=:circle, color=:blue,
                 title="Memory vs Avg Length",
                 xlabel="Average Length", ylabel="Memory (MB)", legend=:topleft)
    plot!(p_mem, df.AvgLength, df.SPMFMemory, label="SPMF", marker=:square, color=:green)
    
    display(plot(p_time, p_mem, layout=(1,2), size=(900, 400), bottom_margin=8mm, left_margin=5mm))
end
