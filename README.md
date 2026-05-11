# Frequent Pattern Mining - FP-Growth Algorithm

Đồ án 2: Khai thác tập phổ biến (Frequent Itemset Mining) - Thuật toán FP-Growth

## Cấu trúc thư mục
- `src/`: Chứa mã nguồn cài đặt.
  - `structures.jl`: Cấu trúc dữ liệu FP-Tree.
  - `algorithm/fpgrowth.jl`: Cài đặt thuật toán.
  - `utils.jl`: Đọc/ghi định dạng SPMF.
  - `FPGrowth.jl`: Module chính.
- `tests/`: Bộ kiểm thử.
  - `test_correctness.jl`: Kiểm tra độ chính xác trên toy dataset.
- `data/`: Nơi chứa dữ liệu test.

## Cài đặt mã nguồn

Mã nguồn được viết bằng Julia. Để chạy thử:

1. Chạy unit tests:
```bash
julia tests/test_correctness.jl
```

2. Tích hợp trong code của bạn:
```julia
include("src/FPGrowth.jl")
using .FPGrowth

# Đọc dữ liệu
transactions = read_spmf("data/benchmark/chess.txt")

# Chạy thuật toán (ví dụ min_support = 2000)
frequent_itemsets = fpgrowth(transactions, 2000)

# Ghi kết quả
write_spmf("output.txt", frequent_itemsets)
```
