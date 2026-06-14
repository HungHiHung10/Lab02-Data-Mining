# Frequent Itemset Mining - FP-Growth

Đồ án 2 môn **Khai thác dữ liệu và ứng dụng - CSC14004**.

Dự án cài đặt thuật toán **FP-Growth** bằng **Julia** để khai thác tập phổ biến
(Frequent Itemset Mining), hỗ trợ đọc/ghi dữ liệu theo định dạng SPMF, kiểm thử
tự động, và so sánh thực nghiệm với bản tham chiếu **SPMF Java**.

![Julia](https://img.shields.io/badge/Julia-1.9+-blue?logo=julia)
![SPMF](https://img.shields.io/badge/SPMF-Java-orange)
![Tests](https://img.shields.io/badge/tests-passing-success)

## 1. Mục Tiêu

- Cài đặt FP-Growth từ đầu bằng Julia, không dùng thư viện FIM có sẵn.
- Xuất toàn bộ frequent itemsets kèm support tương ứng.
- Hỗ trợ input/output theo định dạng SPMF:

```text
1 2 5
2 4
1 2 3
```

Output:

```text
1 2 #SUP: 3
2 5 #SUP: 4
```

- Có bản cài đặt cơ bản và bản tối ưu.
- Có unit test tự động trên ít nhất 5 cơ sở dữ liệu nhỏ.
- Có notebook/script phục vụ đánh giá correctness, runtime, memory, scalability và ứng dụng thực tế.

## 2. Yêu Cầu Môi Trường

| Thành phần | Phiên bản | Vai trò |
|---|---:|---|
| Julia | >= 1.9 | Ngôn ngữ cài đặt chính |
| Java | Microsoft OpenJDK 21 | Chạy SPMF Java baseline |
| Jupyter Notebook | tùy chọn | Chạy notebook thực nghiệm |
| IJulia | theo `Project.toml` | Julia kernel cho notebook |

Các package Julia được quản lý bằng `Project.toml` và `Manifest.toml`.

## 3. Cài Đặt Bằng Windows CMD

Các lệnh dưới đây dùng **Command Prompt (CMD)** trên Windows.

### 3.1. Cài Julia bằng Juliaup

Cài Juliaup:

```cmd
winget install julia -s msstore
```

Đóng CMD, mở lại CMD mới rồi kiểm tra:

```cmd
julia --version
```

Nếu máy có nhiều phiên bản Julia, có thể dùng Juliaup để cài/chọn bản ổn định:

```cmd
juliaup add release
juliaup default release
julia --version
```

Project yêu cầu Julia `>= 1.9`. Julia mới hơn, ví dụ `1.10`, `1.11`, `1.12`, vẫn dùng được nếu package instantiate thành công.

### 3.2. Mở đúng thư mục project

```cmd
cd /d D:\DataMining\Lab02-Data-Mining
```

Kiểm tra project files:

```cmd
dir Project.toml
dir Manifest.toml
```

### 3.3. Cài dependency Julia cho project

```cmd
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

Nếu muốn làm sạch trạng thái dependency hơn:

```cmd
julia --project=. -e "using Pkg; Pkg.resolve(); Pkg.instantiate(); Pkg.precompile()"
```

### 3.4. Cài Java để chạy SPMF

Kiểm tra Java:

```cmd
java -version
```

Nếu chưa có Java, cài **Microsoft OpenJDK 21** để khớp với cấu hình benchmark trong notebook:

```cmd
winget install Microsoft.OpenJDK.21
```

Đóng CMD, mở lại CMD mới rồi kiểm tra đúng đường dẫn Java:

```cmd
"C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot\bin\java.exe" -version
```

Trong các notebook benchmark, cấu hình Java nên dùng:

```julia
"java_path" => "C:/Program Files/Microsoft/jdk-21.0.10.7-hotspot/bin/java.exe"
```

Sau đó kiểm tra SPMF:

```cmd
cd /d D:\DataMining\Lab02-Data-Mining
"C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot\bin\java.exe" -jar src\algorithm\fpgrowth_spmf.jar
```

### 3.5. Kiểm Tra Setup Nhanh

Ba lệnh quan trọng nhất:

```cmd
cd /d D:\DataMining\Lab02-Data-Mining
julia --project=. -e "using Pkg; Pkg.instantiate()"
julia --project=. test\runtests.jl
```

### 3.6. Cài Kernel Julia Cho Notebook

`IJulia` đã có sẵn trong `Project.toml` và `Manifest.toml`, nên không cần `Pkg.add("IJulia")`.
Sau khi instantiate project, đăng ký kernel cho Jupyter:

```cmd
cd /d D:\DataMining\Lab02-Data-Mining
julia --project=. -e "using IJulia; installkernel(\"Julia Lab02 DataMining\", \"--project=D:/DataMining/Lab02-Data-Mining\")"
```

Mở Jupyter Notebook:

```cmd
jupyter notebook
```

Khi mở các file trong `notebooks/`, chọn kernel:

```text
Julia Lab02 DataMining
```

## 4. Cài Đặt Trên macOS/Linux

Nếu chạy trên macOS hoặc Linux, vẫn dùng Juliaup để cài Julia, nhưng đường dẫn Java sẽ khác Windows.

### 4.1. Cài Julia bằng Juliaup

macOS/Linux:

```bash
curl -fsSL https://install.julialang.org | sh
```

Đóng terminal, mở lại terminal mới rồi kiểm tra:

```bash
julia --version
```

Nếu cần chọn bản ổn định:

```bash
juliaup add release
juliaup default release
```

### 4.2. Cài Java

macOS dùng Homebrew:

```bash
brew install openjdk@21
java -version
```

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install openjdk-21-jdk
java -version
```

### 4.3. Cài dependency project

Từ thư mục project:

```bash
cd /path/to/Lab02-Data-Mining
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Chạy test:

```bash
julia --project=. test/runtests.jl
```

Chạy thuật toán:

```bash
julia --project=. main.jl --input data/toy/test1.txt --minsup 0.4 --output results/result1.txt
```

Chạy SPMF:

```bash
java -jar src/algorithm/fpgrowth_spmf.jar run FPGrowth_itemsets data/toy/test1.txt results/spmf_test1.txt 0.4
```

### 4.4. Lưu Ý `java_path` Trong Notebook

Trên Windows, notebook đang dùng:

```julia
"java_path" => "C:/Program Files/Microsoft/jdk-21.0.10.7-hotspot/bin/java.exe"
```

Trên macOS/Linux, đổi thành:

```julia
"java_path" => "java"
```

Hoặc dùng đường dẫn lấy từ terminal:

```bash
which java
```

Ví dụ:

```julia
"java_path" => "/usr/bin/java"
```

## 5. Cách Chạy Thuật Toán

Lệnh chính:

```cmd
julia --project=. main.jl --input <input-file> --minsup <minsup> --output <output-file>
```

Ví dụ với tỷ lệ minsup:

```cmd
julia --project=. main.jl --input data/toy/test1.txt --minsup 0.4 --output results/result1.txt
```

Ví dụ với minsup tuyệt đối:

```cmd
julia --project=. main.jl --input data/toy/test1.txt --minsup 3 --output results/result1_abs.txt
```

Tham số:

| Tham số | Ý nghĩa |
|---|---|
| `--input`, `-i` | Đường dẫn file giao dịch theo định dạng SPMF |
| `--minsup`, `-s` | Ngưỡng support, dạng tỷ lệ `0 < s <= 1` hoặc số tuyệt đối `s > 1` |
| `--output`, `-o` | Đường dẫn file kết quả |

## 6. Chạy Kiểm Thử Tự Động

Lệnh chạy test:

```cmd
julia --project=. test/runtests.jl
```

Output lần chạy cuối:

```text
Test Summary:                         | Pass  Total  Time
FP-Growth correctness on toy datasets |   81     81  5.0s
Test Summary:                                    | Pass  Total  Time
SPMF reader accepts comma-separated transactions |    1      1  0.1s
Test Summary:         | Pass  Total  Time
Benchmark smoke tests |   23     23  0.4s
```

Bộ test hiện có:

- `test/test_correctness.jl`: kiểm tra `fpgrowth` và `fpgrowth_opt` trên 5 toy datasets bằng cách đối chiếu trực tiếp với SPMF; brute-force oracle được dùng như lớp kiểm tra phụ.
- `test/test_benchmark.jl`: smoke test cho pipeline benchmark nhẹ, output SPMF-style và tính nhất quán giữa base/optimized.
- `test/test_helpers.jl`: hàm hỗ trợ chuẩn hóa itemset, brute-force reference và parse output.
- `test/runtests.jl`: entrypoint chạy toàn bộ test.

## 7. Cấu Trúc Thư Mục

```text
Lab02-Data-Mining/
|-- README.md
|-- Project.toml
|-- Manifest.toml
|-- main.jl
|-- src/
|   |-- FPGrowth.jl
|   |-- structures.jl
|   |-- utils.jl
|   |-- logger.jl
|   |-- eval.jl
|   |-- algorithm/
|   |   |-- fpgrowth_base.jl
|   |   |-- fpgrowth_opt.jl
|   |   |-- fpgrowth_spmf.jar
|-- test/
|   |-- runtests.jl
|   |-- test_correctness.jl
|   |-- test_benchmark.jl
|   |-- test_helpers.jl
|-- data/
|   |-- toy/
|   |   |-- test1.txt
|   |   |-- test2.txt
|   |   |-- test3.txt
|   |   |-- test4.txt
|   |   |-- test5.txt
|   |-- benchmark/
|   |   |-- accidents.dat
|   |   |-- connect-4.dat
|   |   |-- retail.dat
|   |   |-- transactional_T10I4D100K.csv
|   |   |-- transactional_T20I6D100K.csv
|   |-- analysis/
|   |   |-- Groceries_dataset.csv
|-- notebooks/
|   |-- 01_evaluate.ipynb
|   |-- 02_benchmarking.ipynb
|   |-- 03_employ.ipynb
|-- results/
|-- docs/
|   |-- Report.pdf
```

Ghi chú trước khi nộp: đề bài yêu cầu báo cáo chính thức nằm ở `docs/Report.pdf`.
Nếu báo cáo được viết trong notebook hoặc công cụ khác, cần xuất thành PDF và đặt vào
đúng đường dẫn này trước khi đóng gói.

## 8. Mô Tả Mã Nguồn

| File | Vai trò |
|---|---|
| `src/algorithm/fpgrowth_base.jl` | Bản FP-Growth cơ bản |
| `src/algorithm/fpgrowth_opt.jl` | Bản tối ưu với single-path pruning, bit filter và giảm cấp phát trung gian |
| `src/structures.jl` | Cấu trúc `FPNode`, `HeaderTable`, `HeaderTableEntry` |
| `src/utils.jl` | Đọc/ghi SPMF, parse output, gọi SPMF Java, sinh dữ liệu tổng hợp |
| `src/eval.jl` | Hàm đánh giá correctness, performance, memory, scalability, transaction length |
| `main.jl` | CLI chạy thuật toán từ terminal |

## 9. Dataset

Toy datasets dùng cho unit test:

| Dataset | Mục đích |
|---|---|
| `data/toy/test1.txt` | Kiểm thử cơ bản với nhiều frequent itemsets |
| `data/toy/test2.txt` | Trường hợp gần single path |
| `data/toy/test3.txt` | Dataset nhỏ để kiểm tra support |
| `data/toy/test4.txt` | Dataset có giao dịch giao nhau |
| `data/toy/test5.txt` | Dataset sparse nhỏ |

Benchmark datasets:

| Dataset | File |
|---|---|
| Accidents | `data/benchmark/accidents.dat` |
| Connect-4 | `data/benchmark/connect-4.dat` |
| Retail | `data/benchmark/retail.dat` |
| T10I4D100K | `data/benchmark/transactional_T10I4D100K.csv` |
| T20I6D100K | `data/benchmark/transactional_T20I6D100K.csv` |

Application dataset:

| Dataset | File |
|---|---|
| Groceries | `data/analysis/Groceries_dataset.csv` |

## 10. Thực Nghiệm Và Notebook

Các notebook chính:

| Notebook | Nội dung |
|---|---|
| `notebooks/01_evaluate.ipynb` | Kiểm tra correctness, chạy toy datasets, đối chiếu SPMF |
| `notebooks/02_benchmarking.ipynb` | Benchmark thời gian, bộ nhớ, số frequent itemsets, scalability |
| `notebooks/03_employ.ipynb` | Ứng dụng thực tế với dữ liệu Groceries/market basket |

Các kết quả trung gian và CSV được lưu trong `results/`.

## 11. So Sánh Với SPMF

SPMF Java baseline được đặt tại:

```text
src/algorithm/fpgrowth_spmf.jar
```

Ví dụ chạy SPMF trực tiếp:

```cmd
"C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot\bin\java.exe" -jar src\algorithm\fpgrowth_spmf.jar run FPGrowth_itemsets data\toy\test1.txt results\spmf_test1.txt 0.4
```

Trong code, hàm `Utils.execute_spmf(...)` hỗ trợ gọi SPMF và parse thời gian/bộ nhớ từ output.

## 12. Tái Lập Kết Quả

Quy trình khuyến nghị:

1. Cài Julia bằng Juliaup và cài Java.
2. Chạy `julia --project=. -e "using Pkg; Pkg.instantiate()"`.
3. Chạy `julia --project=. test/runtests.jl`.
4. Chạy ví dụ CLI:

```cmd
julia --project=. main.jl --input data/toy/test1.txt --minsup 0.4 --output results/result1.txt
```

5. Mở các notebook trong `notebooks/` và chạy lại theo thứ tự:

```text
01_evaluate.ipynb
02_benchmarking.ipynb
03_employ.ipynb
```

## 13. Checklist Theo Yêu Cầu Đề

| Yêu cầu | Trạng thái trong repo |
|---|---|
| Julia >= 1.9 | Có, khai báo trong `Project.toml` |
| Không dùng thư viện FIM có sẵn | Có, thuật toán tự cài đặt trong `src/algorithm/` |
| Đọc input SPMF | Có, `FPGrowth.read_spmf` |
| Ghi output SPMF | Có, `FPGrowth.write_spmf` |
| CLI nhận input/minsup/output | Có, `main.jl` |
| Unit test tự động | Có, `test/runtests.jl` |
| Ít nhất 5 toy datasets | Có, `data/toy/test1.txt` đến `test5.txt` |
| Bản tối ưu | Có, `fpgrowth_opt.jl` |
| Benchmark datasets | Có, trong `data/benchmark/` |
| So sánh SPMF | Có, qua `fpgrowth_spmf.jar`, `src/eval.jl`, notebooks và `results/` |
| Ứng dụng thực tế | Có, `notebooks/03_employ.ipynb` và `data/analysis/Groceries_dataset.csv` |
| Báo cáo PDF chính thức | Cần đặt tại `docs/Report.pdf` trước khi nộp |

## 14. Ghi Chú Nộp Bài

- Nếu file nén vượt giới hạn dung lượng, đưa dataset lớn lên Google Drive và cập nhật link tại đây.
- Trước khi nộp, chạy lại toàn bộ test:

```cmd
julia --project=. test/runtests.jl
```

- Restart & Run All các notebook trước khi xuất báo cáo hoặc nộp notebook.
- Đảm bảo `docs/Report.pdf` tồn tại nếu nộp theo đúng cấu trúc đề bài.
