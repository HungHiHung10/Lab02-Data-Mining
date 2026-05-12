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
* Sau khi cài, sao chép `spmf.jar` (đã có trong repository) vào thư mục gốc dự án.
* Kiểm tra tích hợp:
  ```bash
  java -jar spmf.jar
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
│   │   └── fpgrowth.jl         # Thuật toán cốt lõi: Khởi tạo FP-Tree và hàm đệ quy _mine_tree! siêu tối ưu bộ nhớ.
│   ├── eval_utils.jl           # Các hàm Hỗ trợ Đánh giá: Gọi ngầm SPMF (Java) và parse kết quả so khớp.
│   ├── logger.jl               # Module OOP tự viết: In log màu sắc chuyên nghiệp ra Terminal/Notebook.
│   ├── structures.jl           # Cấu trúc dữ liệu: Định nghĩa FPNode (Vector Lazy) và HeaderTable.
│   ├── utils.jl                # Các hàm tiện ích: Đọc/ghi dữ liệu chuẩn SPMF (.dat/.txt).
│   └── FPGrowth.jl             # Module chính đóng gói toàn bộ code thuật toán.
│
├── .cursorrules                # File cấu hình quy tắc và context dành riêng cho AI (Cursor IDE).
├── .gitignore                  # Chỉ định các tệp/thư mục Git không được phép theo dõi (ví dụ: data/, results/).
├── Manifest.toml               # File khóa (Lockfile): Ghi chính xác version từng thư viện đảm bảo tái lập 100%.
├── Project.toml                # File quản lý môi trường: Liệt kê các dependencies chính (tương tự package.json).
├── spmf.jar                    # Thư viện SPMF chính thức bằng Java dùng để đánh giá chéo.
└── README.md                   # Tệp hướng dẫn này.
```
