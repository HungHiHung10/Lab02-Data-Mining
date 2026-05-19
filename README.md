# Frequent Pattern Mining - FP-Growth Algorithm 

![Julia](https://img.shields.io/badge/Julia-1.9-blue?logo=julia) 
![IJulia](https://img.shields.io/badge/IJulia-0.7+-success) 
![SPMF](https://img.shields.io/badge/SPMF-Java-orange) 
![Java](https://img.shields.io/badge/Java-8%2B-red?logo=java)

Đồ án: Khai thác tập phổ biến (Frequent Itemset Mining) - Cài đặt thuật toán FP-Growth bằng ngôn ngữ **Julia** và so sánh & đánh giá đối với thư viện Built-in **SPMF (Java)** trên đa dạng dataset/database.

---

## 1. Hướng dẫn Cài đặt Môi trường & Gói phụ thuộc

### Danh sách Julia dependencies
| Packets | Version | Description |
|------|-------------------|-------|
| `Julia` | 1.9+ | Main language |
| `IJulia` | 0.7+ | Jupyter Kernel |
| `CSV` | 0.10+ | Read/Write CSV files |
| `DataFrames` | 1.6+ | Data processing |
| `Plots` | 1.30+ | Plotting |
| `ProgressMeter` | 1.8+ | Progress bar |
| `Statistics` (standard) | – | Basic statistics |
| `BenchmarkTools` (optional) | 1.3+ | Performance measurement |

> **Notice:** `Project.toml` và `Manifest.toml` của dự án đã thực hiện theo chính xác các phiên bản; chạy `instantiate` sẽ tự động cài đặt các packages.

### Bước 1: Cài đặt Julia (ngôn ngữ chính)
1. Truy cập https://julialang.org/downloads/ và tải bản phù hợp với hệ điều hành (Windows/macOS/Linux).
2. **Windows:** Đánh dấu *Add Julia to PATH* trong quá trình cài đặt, hoặc sau cài đặt thêm thủ công:
   ```powershell
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\\Users\\%USERNAME%\\AppData\\Local\\Programs\\Julia-1.x\\bin", "User")
   ```
3. **macOS / Linux:** Bạn có thể dùng Homebrew hoặc apt:
   ```bash
   # macOS
   brew install julia
   # Ubuntu
   sudo apt update && sudo apt install julia
   ```
4. Kiểm tra:
   ```bash
   julia --version
   ```
   Kết quả phải >= `1.9`.

### Bước 2: Cài đặt Jupyter Notebook và IJulia
1. Nếu chưa có Python, cài Miniconda hoặc Python 3.x.
2. Cài Jupyter:
   ```bash
   pip install notebook   # hoặc conda install -c conda-forge notebook
   ```
3. Mở Julia REPL (`julia`).
4. Vào Package Manager (`]`).
5. Kích hoạt môi trường dự án và cài các gói:
   ```julia
   activate .          # đọc Project.toml
   instantiate         # tải các gói, bao gồm IJulia, CSV, DataFrames, Plots, ProgressMeter
   ```
6. Đăng ký kernel Jupyter (chỉ chạy một lần):
   ```julia
   using IJulia
   installkernel("Julia")
   ```
7. Kiểm tra: Mở terminal, chạy `jupyter notebook`, tạo notebook mới, chọn kernel **Julia**, thử:
   ```julia
   using Plots
   plot([1,2,3])
   ```
   Nếu biểu đồ hiện ra → mọi thứ đã sẵn sàng.

### Bước 3: Cài đặt Java
* **Windows**: https://adoptium.net/ → tải *Windows x64 Installer* → chọn *Add to PATH* → kiểm tra `java -version` và `javac -version`.
* **macOS**: `brew install openjdk@11` → thêm vào `~/.zshrc`:
  ```bash
  export JAVA_HOME="$(/usr/libexec/java_home -v 11)"
  export PATH=$JAVA_HOME/bin:$PATH
  ```
* **Linux (Ubuntu/Debian)**: `sudo apt install openjdk-11-jdk`.
* Thư viện `fpgrowth_spmf.jar` đã được đặt sẵn trong thư mục `src/algorithm/`.
* Kiểm tra tích hợp:
  ```bash
  java -jar src/algorithm/fpgrowth_spmf.jar
  ```
  Nếu xuất hiện phiên bản SPMF → chuẩn bị xong.

## 2. Cấu trúc Thư mục Chi tiết

Dự án được tổ chức chặt chẽ theo mô hình module của phần mềm chuyên nghiệp:

```text
Lab02-Data-Mining/
│
├── data/                       # Chứa các tập dữ liệu đầu vào.
│   ├── benchmark/              # Các dataset lớn để đo hiệu năng (chess.dat, mushroom.dat,...)
│   └── toy/                    # Các dataset nhỏ gọn dùng để debug và test độ chính xác.
│
├── docs/                       # Chứa tài liệu tham khảo, báo cáo, PDF mô tả thuật toán.
│
├── notebooks/                  # Chứa các file Jupyter Notebook dùng để chạy kịch bản (Pipeline).
│   ├── 01_evaluate.ipynb       # File orchestrator chính: Đánh giá Tính đúng đắn, Hiệu năng và Độ mở rộng.
│   ├── 02_bechmarking.ipynb    # (Mở rộng) Các kịch bản test chuyên sâu.
│   └── 03_employ.ipynb         # (Mở rộng) Ứng dụng thuật toán vào bài toán thực tế.
│
├── results/                    # Thư mục lưu trữ kết quả đầu ra sinh ra trong quá trình chạy.
│   └── (Sẽ chứa file kết quả .txt, file báo cáo .csv và các biểu đồ lưu lại)
│
├── src/                        # Chứa 100% Mã nguồn (Source Code) của dự án.
│   ├── algorithm/
│   │   ├── fpgrowth_base.jl    # Thuật toán FP-Growth cơ bản (Baseline).
│   │   ├── fpgrowth_opt.jl     # Thuật toán FP-Growth tối ưu hóa (Optimized).
│   │   └── fpgrowth_spmf.jar   # Bản SPMF Java chính thức dùng để đối chuẩn hiệu năng.
│   ├── eval.jl                 # Kịch bản thực nghiệm, so sánh độ chính xác và vẽ biểu đồ.
│   ├── logger.jl               # Module OOP tự viết: In log màu sắc chuyên nghiệp.
│   ├── structures.jl           # Cấu trúc dữ liệu: FPNode và HeaderTable.
│   ├── utils.jl                # Tiện ích: Đọc/ghi dữ liệu chuẩn SPMF và hỗ trợ gọi JVM.
│   └── FPGrowth.jl             # Module chính đóng gói toàn bộ code thuật toán.
│
├── .cursorrules                # File cấu hình quy tắc dành riêng cho AI.
├── .gitignore                  # Chỉ định các tệp/thư mục Git bỏ qua.
├── Manifest.toml               # Ghi chính xác các gói dependencies để tái lập.
├── Project.toml                # File quản lý môi trường và thư viện liên kết.
└── README.md                   # Tệp hướng dẫn này.
```
