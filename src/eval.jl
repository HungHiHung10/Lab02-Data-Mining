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
# HELPERS: RUN & PARSE
# ========================
"""
    _run_algo(sym, transactions, min_sup_abs, config, out_path, Min_Sup)

Chạy một trong 3 phương pháp và trả về (Set{String} kết quả, thời gian chạy, bộ nhớ MB).
- sym = :base   → fpgrowth cơ bản
- sym = :opt    → fpgrowth_opt tối ưu
- sym = :spmf   → SPMF Java baseline
"""
function _run_algo(sym::Symbol, transactions, min_sup_abs::Int, config, out_path::String, Min_Sup::Float64)
    GC.gc()
    if sym == :base
        mem = 0; t = 0.0; t0 = time_ns(); t1 = time_ns()
        mem = @allocated begin
            t0 = time_ns()
            res = FPGrowth.fpgrowth(transactions, min_sup_abs)
            t1 = time_ns()
        end
        t = (t1 - t0) / 1e9
        res_set = Set{String}(join(sort(k), " ") * " - " * string(v) for (k, v) in res)
        return res_set, t, mem / (1024^2)
    elseif sym == :opt
        mem = 0; t = 0.0; t0 = time_ns(); t1 = time_ns()
        mem = @allocated begin
            t0 = time_ns()
            res = FPGrowth.fpgrowth_opt(transactions, min_sup_abs)
            t1 = time_ns()
        end
        t = (t1 - t0) / 1e9
        res_set = Set{String}(join(sort(k), " ") * " - " * string(v) for (k, v) in res)
        return res_set, t, mem / (1024^2)
    elseif sym == :spmf
        t, mem_mb = Utils.execute_spmf(config, config["dataset_path"], out_path, Min_Sup)
        res_set = Utils.parse_output(out_path)
        return res_set, t, mem_mb
    else
        error("Unknown algo symbol: $sym. Use :base, :opt, or :spmf")
    end
end

_label(sym::Symbol) = sym == :base ? "FP-Growth Basic" : sym == :opt ? "FP-Growth Optimized" : "SPMF Java"
_color(sym::Symbol) = sym == :base ? :gray : sym == :opt ? :blue : :green

# ========================
# CORRECTNESS
# ========================
"""
    eval_correctness(config, logger; methods=[:base, :spmf], min_sup=nothing)

So sánh tính đúng đắn giữa 2 trong 3 phương pháp:
- `:base`  → FP-Growth cơ bản
- `:opt`   → FP-Growth tối ưu (Single Path Pruning + BitArray)
- `:spmf`  → SPMF Java (Ground Truth)

**Ví dụ:**
```julia
eval_correctness(CONFIG, logger, methods=[:base, :spmf])  # Julia vs SPMF
eval_correctness(CONFIG, logger, methods=[:base, :opt])   # Basic vs Optimized
eval_correctness(CONFIG, logger, methods=[:opt,  :spmf])  # Optimized vs SPMF
```
"""
function eval_correctness(config, logger; methods::Vector{Symbol}=[:base, :spmf], min_sup=nothing, method=nothing, algo=nothing)
    # Backward compatibility: nếu truyền algo= hoặc method= (hàm Julia cũ)
    legacy_algo = algo !== nothing ? algo : method
    if legacy_algo !== nothing
        return _eval_correctness_legacy(config, logger, legacy_algo)
    end

    length(methods) == 2 || error("methods phải có đúng 2 phần tử, ví dụ: [:base, :spmf]")
    sym_a, sym_b = methods[1], methods[2]

    phase(logger, "CORRECTNESS: $(_label(sym_a)) vs $(_label(sym_b))")

    path = haskey(config, "dataset_path") ? config["dataset_path"] : config["datasets_path"][1]
    Min_Sup = (min_sup !== nothing) ? Float64(min_sup) : Float64(config["Minimum Support"])

    transactions = FPGrowth.read_spmf(path)
    min_sup_abs  = ceil(Int, Min_Sup * length(transactions))
    info(logger, "Dataset: ", basename(path), " | MinSup=", Min_Sup * 100, "% | Transactions=", length(transactions))

    spmf_out = joinpath("..", "results", "_tmp_correctness.txt")

    process(logger, "Running $(_label(sym_a))...")
    res_a, _, _ = _run_algo(sym_a, transactions, min_sup_abs, config, spmf_out, Min_Sup)

    process(logger, "Running $(_label(sym_b))...")
    res_b, _, _ = _run_algo(sym_b, transactions, min_sup_abs, config, spmf_out, Min_Sup)

    rm(spmf_out, force=true)

    # So sánh
    missing_in_a = length(setdiff(res_b, res_a))
    missing_in_b = length(setdiff(res_a, res_b))
    match_rate   = length(intersect(res_a, res_b)) / max(length(res_b), 1) * 100

    info(logger, "$(_label(sym_a)) count: ", length(res_a), " | $(_label(sym_b)) count: ", length(res_b))

    if missing_in_a == 0 && missing_in_b == 0
        info(logger, "Matching #SUP for each itemset → TRUE (100% Exact Match)")
    else
        info(logger, "Matching #SUP → FALSE | Match rate: ", round(match_rate, digits=2), "%")
        info(logger, "Missing in $(_label(sym_a)): ", missing_in_a, " | Missing in $(_label(sym_b)): ", missing_in_b)
    end

    # In 5 mẫu khớp nhau
    info(logger, "Support Match Samples (Top 5):")
    count = 0
    for item in intersect(res_a, res_b)
        parts = split(item, " - ")
        length(parts) == 2 || continue
        metric(logger, "Itemset: { ", parts[1], " } | Support: ", parts[2], " => MATCH ✓")
        count += 1
        count >= 5 && break
    end
    println()

    return Dict(
        "$(_label(sym_a))_Count" => length(res_a),
        "$(_label(sym_b))_Count" => length(res_b),
        "Missing_in_A" => missing_in_a,
        "Missing_in_B" => missing_in_b,
        "Match_Rate"   => match_rate,
        "Label_A"      => _label(sym_a),
        "Label_B"      => _label(sym_b)
    )
end

# Backward-compatible legacy version (khi truyền algo= hàm Julia)
function _eval_correctness_legacy(config, logger, algo)
    phase(logger, "CORRECTNESS")
    info(logger, "Verify accuracy at the threshold MinSup=", config["Minimum Support"] * 100, "%")
    transactions = FPGrowth.read_spmf(config["dataset_path"])
    min_sup_abs = ceil(Int, config["Minimum Support"] * length(transactions))
    process(logger, "Executing Julia...")
    julia_result = algo(transactions, min_sup_abs)
    FPGrowth.write_spmf(config["proposed_result"], julia_result)
    process(logger, "Executing SPMF...")
    Utils.execute_spmf(config, config["dataset_path"], config["baseline_result"], config["Minimum Support"])
    my_res   = Utils.parse_output(config["proposed_result"])
    spmf_res = Utils.parse_output(config["baseline_result"])
    missing_in_mine = length(setdiff(spmf_res, my_res))
    missing_in_spmf = length(setdiff(my_res, spmf_res))
    if missing_in_mine == 0 && missing_in_spmf == 0
        info(logger, "Matching #SUP → TRUE (100% Exact Match)")
    else
        info(logger, "Matching #SUP → FALSE | Missing in Julia: ", missing_in_mine, " | Missing in SPMF: ", missing_in_spmf)
    end
    println()
    info(logger, "Support Match Samples (Top 5):")
    count = 0
    for item in intersect(my_res, spmf_res)
        parts = split(item, " - ")
        length(parts) == 2 || continue
        metric(logger, "Itemset: { ", parts[1], " } | Support: ", parts[2], ": Match ✓")
        count += 1; count >= 5 && break
    end
    println()
    return Dict("Julia_Count" => length(my_res), "SPMF_Count" => length(spmf_res),
                "Missing_in_Julia" => missing_in_mine, "Missing_in_SPMF" => missing_in_spmf)
end

function vis_correctness(res::Dict, logger)
    phase(logger, "Visualize")

    # Hỗ trợ cả format mới (Label_A/B) và cũ (Julia_Count/SPMF_Count)
    if haskey(res, "Label_A")
        label_a = res["Label_A"]; label_b = res["Label_B"]
        count_a = res["$(label_a)_Count"]; count_b = res["$(label_b)_Count"]
        if res["Missing_in_A"] == 0 && res["Missing_in_B"] == 0
            success(logger, "Correct (", count_a, " itemsets matched 100%)")
        else
            fail(logger, "Incorrect: Match Rate = ", round(res["Match_Rate"], digits=2), "%")
        end
        categories = [label_a, label_b]
        counts     = [count_a, count_b]
    else
        if res["Missing_in_Julia"] == 0 && res["Missing_in_SPMF"] == 0
            success(logger, "Correct (", res["Julia_Count"], " frequent itemsets)")
        else
            fail(logger, "Incorrect: Missing in Julia: ", res["Missing_in_Julia"], " | Missing in SPMF: ", res["Missing_in_SPMF"])
        end
        categories = ["Julia From Scratch", "SPMF Built-in"]
        counts     = [res["Julia_Count"], res["SPMF_Count"]]
    end

    p = bar(categories, counts, title="Correctness Evaluation", ylabel="Frequent Itemsets",
            legend=false, color=[:blue, :green], bar_width=0.4)
    display(plot(p, bottom_margin=5mm))
end




# ========================
# PERFORMANCE
# ========================
"""
    eval_performance(config, logger; methods=[:base, :spmf], min_sup=nothing)

Đo hiệu năng (thời gian + bộ nhớ) giữa 2 trong 3 phương pháp:
- `:base`  → FP-Growth cơ bản
- `:opt`   → FP-Growth tối ưu (Single Path Pruning + BitArray)
- `:spmf`  → SPMF Java (Ground Truth)

**Ví dụ:**
```julia
eval_performance(CONFIG, logger, methods=[:base, :spmf])  # Cơ bản vs SPMF
eval_performance(CONFIG, logger, methods=[:base, :opt])   # Cơ bản vs Tối ưu
eval_performance(CONFIG, logger, methods=[:opt,  :spmf])  # Tối ưu vs SPMF
```
"""
function eval_performance(config, logger; methods::Vector{Symbol}=[:opt, :spmf], method=nothing, algo=nothing)
    # Backward compatibility: nếu truyền algo= hoặc method= (hàm Julia cũ)
    legacy_algo = algo !== nothing ? algo : method
    if legacy_algo !== nothing
        return _eval_performance_legacy(config, logger, legacy_algo)
    end

    length(methods) == 2 || error("methods phải có đúng 2 phần tử, ví dụ: [:base, :spmf]")
    sym_a, sym_b = methods[1], methods[2]
    
    # Warm up JIT
    process(logger, "Warming up JIT Compiler...")
    FPGrowth.fpgrowth([[1,2],[1,3],[1,2,3]], 1)
    FPGrowth.fpgrowth_opt([[1,2],[1,3],[1,2,3]], 1)
    
    phase(logger, "PERFORMANCE: $(_label(sym_a)) vs $(_label(sym_b))")
    path = haskey(config, "dataset_path") ? config["dataset_path"] : config["datasets_path"][1]
    transactions = FPGrowth.read_spmf(path)
    info(logger, "Dataset: ", basename(path), " | Transactions: ", length(transactions))
    
    N_RUNS = get(config, "n_executes", 5)
    spmf_out = joinpath("..", "results", "_tmp_perf.txt")
    results_df = DataFrame(
        MinSup=Float64[], Itemsets=Int[],
        TimeA=Float64[], MemA=Float64[],
        TimeB=Float64[], MemB=Float64[]
    )

    @showprogress "Benchmarking... " for min_sup_ratio in config["min_sups"]
        Min_Sup = Float64(min_sup_ratio)
        min_sup_abs = ceil(Int, Min_Sup * length(transactions))
        process(logger, "MinSup = ", Min_Sup * 100, "% ...")
        
        # --- Phương pháp A ---
        times_a = Float64[]; mems_a = Float64[]; itemsets_a = 0
        n_runs_a = (sym_a == :spmf) ? 1 : N_RUNS
        for _ in 1:n_runs_a
            res_set, t, mem = _run_algo(sym_a, transactions, min_sup_abs, config, spmf_out, Min_Sup)
            itemsets_a = length(res_set)
            push!(times_a, t); push!(mems_a, mem)
        end
        ta = median(times_a); ma = median(mems_a)
        
        # --- Phương pháp B ---
        times_b = Float64[]; mems_b = Float64[]; itemsets_b = 0
        n_runs_b = (sym_b == :spmf) ? 1 : N_RUNS
        for _ in 1:n_runs_b
            res_set, t, mem = _run_algo(sym_b, transactions, min_sup_abs, config, spmf_out, Min_Sup)
            itemsets_b = length(res_set)
            push!(times_b, t); push!(mems_b, mem)
        end
        tb = median(times_b); mb = median(mems_b)
        
        metric(logger, "$(_label(sym_a)) → Time: ", round(ta,digits=3), "s | Memory: ", round(ma,digits=2), "MB | Itemsets: ", itemsets_a)
        metric(logger, "$(_label(sym_b)) → Time: ", round(tb,digits=3), "s | Memory: ", round(mb,digits=2), "MB | Itemsets: ", itemsets_b)
        
        push!(results_df, (min_sup_ratio, itemsets_a, ta, ma, tb, mb))
    end
    
    rm(spmf_out, force=true)
    # Lưu metadata nhãn vào cột riêng (không rename cột TimeA/MemA để tránh lỗi ký tự đặc biệt)
    results_df[!, :_label_a] .= _label(sym_a)
    results_df[!, :_label_b] .= _label(sym_b)
    if haskey(config, "performance_result")
        CSV.write(config["performance_result"], results_df)
        success(logger, "Saved at ", config["performance_result"])
    end
    return results_df
end

# Backward-compatible legacy version
function _eval_performance_legacy(config, logger, algo)
    process(logger, "Warming up JIT Compiler...")
    algo([[1,2], [1,3], [1,2,3]], 1)
    phase(logger, "PERFORMANCE")
    transactions = FPGrowth.read_spmf(config["dataset_path"])
    total_txs = length(transactions)
    info(logger, "Transactions: ", total_txs)
    N_RUNS = get(config, "n_executes", 5)
    results_df = DataFrame(MinSup=Float64[], Itemsets=Int[], JuliaTime=Float64[], JuliaMemory=Float64[], SPMFTime=Float64[], SPMFMemory=Float64[])
    @showprogress "Benchmarking... " for min_sup_ratio in config["min_sups"]
        min_sup_abs = ceil(Int, min_sup_ratio * total_txs)
        julia_times = Float64[]; julia_memories = Float64[]; itemset_count = 0
        for _ in 1:N_RUNS
            GC.gc()
            mem_bytes = @allocated begin
                t0 = time_ns()
                fi = algo(transactions, min_sup_abs)
                t1 = time_ns()
                itemset_count = length(fi)
            end
            push!(julia_times, (t1-t0)/1e9); push!(julia_memories, mem_bytes/(1024^2))
        end
        spmf_time, spmf_memory = Utils.execute_spmf(config, config["dataset_path"], config["baseline_result"], min_sup_ratio)
        metric(logger, "Julia → Time: ", round(median(julia_times),digits=3), "s | Mem: ", round(median(julia_memories),digits=2), "MB")
        metric(logger, "SPMF  → Time: ", round(spmf_time,digits=3), "s | Mem: ", round(spmf_memory,digits=2), "MB")
        push!(results_df, (min_sup_ratio, itemset_count, median(julia_times), median(julia_memories), spmf_time, spmf_memory))
    end
    CSV.write(config["performance_result"], results_df)
    success(logger, "Saved at ", config["performance_result"])
    return results_df
end

function vis_performance(df::DataFrame, logger)
    phase(logger, "visualize")
    df_sorted = sort(df, :MinSup, rev=true)
    x_vals = df_sorted.MinSup .* 100
    
    # Khai báo các biến dùng chung ngoài khối if
    p_time = nothing
    p_memory = nothing
    p_legend = nothing

    # Phát hiện format: mới (có _label_a) hoặc cũ (có JuliaTime)
    if hasproperty(df_sorted, :_label_a)
        # === Format mới: TimeA/MemA/TimeB/MemB + label metadata ===
        label_a = df_sorted[1, :_label_a]
        label_b = df_sorted[1, :_label_b]
        
        color_a = label_a == "FP-Growth Optimized" ? :blue  :
                  label_a == "SPMF Java"            ? :green : :gray
        color_b = label_b == "FP-Growth Optimized" ? :blue  :
                  label_b == "SPMF Java"            ? :green : :gray
        
        # 1. Vẽ đồ thị Time (không hiện legend)
        p_time = plot(x_vals, df_sorted.TimeA,
                      label="", marker=:circle, linewidth=2.5,
                      color=color_a, linestyle=:dash,
                      title="Execution time", xlabel="MinSup (%)", ylabel="Second (s)", legend=false)
        plot!(p_time, x_vals, df_sorted.TimeB,
              label="", marker=:square, linewidth=2,
              color=color_b, linestyle=:solid)
        
        # 2. Vẽ đồ thị Memory (không hiện legend)
        p_memory = plot(x_vals, df_sorted.MemA,
                        label="", marker=:circle, linewidth=2.5,
                        color=color_a, linestyle=:dash,
                        title="Memory consumption", xlabel="MinSup (%)", ylabel="Megabytes (MB)", legend=false)
        plot!(p_memory, x_vals, df_sorted.MemB,
              label="", marker=:square, linewidth=2,
              color=color_b, linestyle=:solid)

        # 3. Vẽ dummy plot chứa Legend nằm ngang căn giữa (Khớp màu/marker đồ thị chính)
        p_legend = plot([0 0], showaxis=false, grid=false, 
                        label=[label_a label_b], 
                        color=[color_a color_b],
                        marker=[:circle :square],
                        linestyle=[:dash :solid],
                        linewidth=2.5,
                        legend=:top, 
                        legendcolumns=2, 
                        frame=:none,
                        xlims=(2, 3), ylims=(2, 3))
    else
        # === Format cũ: JuliaTime/SPMFTime/JuliaMemory/SPMFMemory ===
        # 1. Vẽ đồ thị Time (không hiện legend)
        p_time = plot(x_vals, df_sorted.JuliaTime,
                      label="", marker=:circle, linewidth=2.5, color=:blue, linestyle=:dash,
                      title="Execution time", xlabel="MinSup (%)", ylabel="Second (s)", legend=false)
        plot!(p_time, x_vals, df_sorted.SPMFTime,
              label="", marker=:square, linewidth=2, color=:green, linestyle=:solid)
        
        # 2. Vẽ đồ thị Memory (không hiện legend)
        p_memory = plot(x_vals, df_sorted.JuliaMemory,
                        label="", marker=:circle, linewidth=2.5, color=:blue, linestyle=:dash,
                        title="Memory consumption", xlabel="MinSup (%)", ylabel="Megabytes (MB)", legend=false)
        plot!(p_memory, x_vals, df_sorted.SPMFMemory,
              label="", marker=:square, linewidth=2, color=:green, linestyle=:solid)

        # 3. Vẽ dummy plot chứa Legend nằm ngang căn giữa
        p_legend = plot([0 0], showaxis=false, grid=false, 
                        label=["Julia" "SPMF"], 
                        color=[:blue :green],
                        marker=[:circle :square],
                        linestyle=[:dash :solid],
                        linewidth=2.5,
                        legend=:top, 
                        legendcolumns=2, 
                        frame=:none,
                        xlims=(2, 3), ylims=(2, 3))
    end
    
    # Tạo layout: Hàng trên là 2 plot, hàng dưới là legend chung căn giữa
    l = @layout [
        [a b]
        c{0.12h}
    ]
    
    display(plot(p_time, p_memory, p_legend, layout=l, size=(900, 450), bottom_margin=5mm, left_margin=5mm))
end




function vis_minSupNFI(df::DataFrame, logger)
    phase(logger, "visualize")
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
    
    info(logger, "Executing tests on ", length(test_files), " datasets with MinSup=", min_sup*100, "% and Evaluate correctness in results with SPMF")
    
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
            # info(logger, "Evaluate Julia result and SPMF result")
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
    phase(logger, "Results")
    if passed == total
        success(logger, "Accuracy Rate: ", round(accuracy, digits=2), "% (Passed ", passed, "/", total, ")")
    else
        fail(logger, "Accuracy Rate: ", round(accuracy, digits=2), "% (Passed ", passed, "/", total, ")")
    end
    
    return accuracy
end

# # ========================
# # OPTIMIZATION EVALUATION
# # ========================
# function eval_optimization(config, logger; min_sup=nothing)
#     phase(logger, "OPTIMIZATION COMPARISON")
    
#     # Lấy đường dẫn file: ưu tiên dataset_path
#     path = haskey(config, "dataset_path") ? config["dataset_path"] : config["datasets_path"][1]
    
#     # Lấy min_sup: ưu tiên tham số truyền vào, nếu không có thì lấy từ config
#     Min_Sup = (min_sup !== nothing) ? min_sup : config["Minimum Support"]
    
#     transactions = FPGrowth.read_spmf(path)
#     total_txs = length(transactions)
#     min_sup_abs = ceil(Int, Min_Sup * total_txs)
    
#     info(logger, "Comparing Basic vs Optimized version on: ", basename(path))
#     info(logger, "Threshold MinSup=", Min_Sup * 100, "%")
    
#     # 1. Basic Version
#     process(logger, "Running Basic FPGrowth...")
#     GC.gc()
#     T = eltype(eltype(transactions)) # Xác định kiểu của item (ví dụ Int64)
#     res_basic = Dict{Vector{T}, Int}()
#     t_basic = @elapsed res_basic = FPGrowth.fpgrowth(transactions, min_sup_abs)
    
#     # 2. Optimized Version
#     process(logger, "Running Optimized FPGrowth (Single Path Pruning + BitArray)...")
#     GC.gc()
#     res_opt = Dict{Vector{T}, Int}()
#     t_opt = @elapsed res_opt = FPGrowth.fpgrowth_opt(transactions, min_sup_abs)
    
#     # === KIỂM TRA TÍNH ĐÚNG ĐẮN (CORRECTNESS CHECK) ===
#     is_correct = (res_basic == res_opt)
#     if is_correct
#         success(logger, "✓ Internal Consistency: Basic and Optimized versions match (", length(res_basic), " itemsets)")
#     else
#         fail(logger, "✗ Internal Discrepancy: Basic and Optimized results differ!")
#         info(logger, "Basic count: ", length(res_basic), " | Optimized count: ", length(res_opt))
#     end
    
#     # === ĐỐI CHIẾU VỚI SPMF (NẾU CÓ CẤU HÌNH) ===
#     if haskey(config, "spmf_path") && isfile(config["spmf_path"])
#         process(logger, "Verifying results against SPMF Java baseline...")
#         spmf_out = joinpath("..", "results", "spmf_bench_temp.txt") # Đảm bảo đường dẫn đúng
#         Utils.execute_spmf(config, path, spmf_out, Min_Sup)
#         res_spmf = Utils.parse_output(spmf_out)
        
#         # Chuyển đổi res_opt (Dict) sang Set{String} để so sánh với kết quả từ SPMF
#         res_opt_set = Set{String}()
#         for (itemset, sup) in res_opt
#             push!(res_opt_set, join(itemset, " ") * " - " * string(sup))
#         end
        
#         if res_opt_set == res_spmf
#             success(logger, "✓ SPMF Verified: Julia results are identical to SPMF Java.")
#         else
#             fail(logger, "✗ SPMF Discrepancy! Julia results differ from SPMF Java.")
#             info(logger, "Julia count: ", length(res_opt), " | SPMF count: ", length(res_spmf))
            
#             # Debug: In ra một vài phần tử khác biệt nếu cần
#             diff = setdiff(res_spmf, res_opt_set)
#             if !isempty(diff)
#                 info(logger, "Sample missing in Julia: ", first(diff))
#             end
#         end
#     end
    
#     improvement = ((t_basic - t_opt) / t_basic) * 100
#     metric(logger, "Basic Time: ", round(t_basic, digits=4), "s")
#     metric(logger, "Optimized Time: ", round(t_opt, digits=4), "s")
    
#     if improvement > 0
#         success(logger, "Improvement: ", round(improvement, digits=2), "% faster")
#     else
#         info(logger, "No significant speedup observed for this dataset/minsup.")
#     end
    
#     return DataFrame(Version=["Basic", "Optimized"], ExecutionTime=[t_basic, t_opt])
# end

# function vis_optimization(df::DataFrame, logger)
#     phase(logger, "visualize")
    
#     if hasproperty(df, :Version) && hasproperty(df, :ExecutionTime)
#         # === Format cũ: từ eval_optimization() ===
#         p = bar(df.Version, df.ExecutionTime,
#                 title="Basic vs Optimized FP-Growth",
#                 ylabel="Execution Time (s)",
#                 legend=false,
#                 color=[:gray, :blue],
#                 bar_width=0.5)
#         display(plot(p, bottom_margin=5mm))
        
#     elseif hasproperty(df, :_label_a)
#         # === Format mới: từ eval_performance(algos=[:base, :opt]) ===
#         # Gọi vis_performance để vẽ biểu đồ đường (line chart) đầy đủ hơn
#         vis_performance(df, logger)
        
#     else
#         @warn "vis_optimization: Không nhận ra định dạng DataFrame. Hãy dùng vis_performance() cho kết quả từ eval_performance()."
#     end
# end


# ========================
# AVG TRANSACTION LENGTH
# ========================
function eval_transaction_length(config, logger; algo=FPGrowth.fpgrowth)
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

function vis_transaction_length(df::DataFrame, logger)
    phase(logger, "visualize")
    
    # 1. Biểu đồ thời gian (không hiện legend)
    p_time = plot(df.AvgLength, df.JuliaTime, label="", marker=:circle, linewidth=2.5, color=:blue, linestyle=:dash,
                  title="Execution Time vs Avg Length",
                  xlabel="Average Length", ylabel="Time (s)", legend=false)
    plot!(p_time, df.AvgLength, df.SPMFTime, label="", marker=:square, linewidth=2, color=:green, linestyle=:solid)
    
    # 2. Biểu đồ bộ nhớ (không hiện legend)
    p_mem = plot(df.AvgLength, df.JuliaMemory, label="", marker=:circle, linewidth=2.5, color=:blue, linestyle=:dash,
                 title="Memory vs Avg Length",
                 xlabel="Average Length", ylabel="Memory (MB)", legend=false)
    plot!(p_mem, df.AvgLength, df.SPMFMemory, label="", marker=:square, linewidth=2, color=:green, linestyle=:solid)
    
    # 3. Vẽ dummy plot chứa Legend nằm ngang căn giữa
    p_legend = plot([0 0], showaxis=false, grid=false, 
                    label=["Julia" "SPMF"], 
                    color=[:blue :green],
                    marker=[:circle :square],
                    linestyle=[:dash :solid],
                    linewidth=2.5,
                    legend=:top, 
                    legendcolumns=2, 
                    frame=:none,
                    xlims=(2, 3), ylims=(2, 3))
    
    # Tạo layout: Hàng trên là 2 plot, hàng dưới là legend chung căn giữa
    l = @layout [
        [a b]
        c{0.12h}
    ]
    
    display(plot(p_time, p_mem, p_legend, layout=l, size=(900, 450), bottom_margin=5mm, left_margin=5mm))
end
