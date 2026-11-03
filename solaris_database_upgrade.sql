-- =============================================================================
-- SOLARIS - BỔ SUNG BẢNG CHO DATABASE CŨ
-- Nguồn: database/solaris_schema.sql và database/tv4-billing.sql.
-- Import file này trước solaris_data_insert_fixed.sql nếu cần nạp dữ liệu mẫu.
-- Nếu giữ dữ liệu cũ: chỉ chạy file này, không chạy file seed.
-- Các bảng đã tồn tại được giữ nguyên; không chèn, xóa hoặc cập nhật dữ liệu.
-- Gồm 17 bảng lõi/bán sữa và 2 bảng vật tư phát sinh/thanh toán dự án.
-- hoa_don/ct_hoadon: hóa đơn bán sữa; project_payments: thanh toán dự án solar.
-- File chỉ bổ sung bảng thiếu, không ALTER cột hoặc sửa khóa ngoại bảng đã có.
-- Các cột của database solaris đã đọc trong phiên làm việc hiện tại tương thích
-- với dữ liệu mẫu. Database khác có thể cần migration cột riêng.
-- DDL có implicit commit: sao lưu database trước khi import; nếu có lỗi thì
-- dừng, xử lý nguyên nhân rồi chạy lại toàn bộ file (CREATE IF NOT EXISTS).
-- Cách chạy: phpMyAdmin -> chọn solaris -> Import -> chọn file này -> Go.
-- =============================================================================

CREATE DATABASE IF NOT EXISTS `solaris` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `solaris`;
SET NAMES utf8mb4;
SET SESSION FOREIGN_KEY_CHECKS = 1;

CREATE TABLE IF NOT EXISTS `users` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `username` VARCHAR(50) NOT NULL UNIQUE,
    `password_hash` VARCHAR(255) NOT NULL,
    `full_name` VARCHAR(100) NOT NULL,
    `email` VARCHAR(100) NOT NULL UNIQUE,
    `phone` VARCHAR(20) NOT NULL,
    `role` ENUM('guest', 'customer', 'technician', 'admin') NOT NULL DEFAULT 'customer',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_users_role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `categories` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `slug` VARCHAR(100) NOT NULL UNIQUE,
    `description` TEXT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `products` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `category_id` INT NOT NULL,
    `product_code` VARCHAR(50) NOT NULL UNIQUE,
    `name` VARCHAR(255) NOT NULL,
    `capacity_watts` INT NULL COMMENT 'Công suất danh định Wp/W',
    `price` DECIMAL(15,2) NOT NULL COMMENT 'Đơn giá VNĐ',
    `warranty_years` INT DEFAULT 5 COMMENT 'Thời gian bảo hành (năm)',
    `technical_specs` JSON NULL COMMENT 'Thông số kỹ thuật định dạng JSON',
    `image_url` VARCHAR(255) NULL,
    `stock_quantity` INT DEFAULT 0,
    `is_active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`category_id`) REFERENCES `categories`(`id`) ON DELETE RESTRICT,
    INDEX `idx_products_cat` (`category_id`, `is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `solar_quotes` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NULL COMMENT 'FK tới users.id nếu khách hàng đã đăng nhập',
    `customer_name` VARCHAR(100) NOT NULL,
    `customer_phone` VARCHAR(20) NOT NULL,
    `customer_email` VARCHAR(100) NULL,
    `address` VARCHAR(255) NOT NULL,
    `monthly_electric_bill` DECIMAL(15,2) NOT NULL COMMENT 'Tiền điện hàng tháng VNĐ',
    `roof_area_sqm` DECIMAL(8,2) NOT NULL COMMENT 'Diện tích mái khả dụng m2',
    `estimated_system_kwp` DECIMAL(6,2) NOT NULL COMMENT 'Công suất tối ưu đề xuất kWp',
    `panel_count` INT NOT NULL COMMENT 'Số lượng tấm pin',
    `estimated_total_cost` DECIMAL(15,2) NOT NULL COMMENT 'Tổng chi phí đầu tư dự kiến VNĐ',
    `payback_years` DECIMAL(4,1) NOT NULL COMMENT 'Thời gian hoàn vốn ước tính (năm)',
    `notes` TEXT NULL,
    `status` ENUM('pending', 'contacted', 'survey_scheduled', 'approved', 'rejected') DEFAULT 'pending',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
    INDEX `idx_quotes_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `projects` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `contract_code` VARCHAR(20) NOT NULL UNIQUE COMMENT 'Mã hợp đồng chuẩn SOLAR-YYYY-XXX',
    `quote_id` INT NULL UNIQUE COMMENT 'Liên kết 1:1 với báo giá đã duyệt',
    `user_id` INT NOT NULL COMMENT 'Khách hàng sở hữu dự án',
    `technician_id` INT NULL COMMENT 'Kỹ thuật viên trưởng nhóm phụ trách',
    `project_name` VARCHAR(255) NOT NULL,
    `capacity_kwp` DECIMAL(6,2) NOT NULL,
    `total_amount` DECIMAL(15,2) NOT NULL,
    `installation_address` VARCHAR(255) NOT NULL,
    `status` ENUM('new', 'in_progress', 'completed', 'cancelled') NOT NULL DEFAULT 'new',
    `current_stage` ENUM('survey', 'design', 'procurement', 'installation', 'grid_connection', 'handover', 'cancelled') NOT NULL DEFAULT 'survey',
    `notes` TEXT NULL,
    `start_date` DATE NULL,
    `completion_date` DATE NULL,
    `planned_end_date` DATE NULL,
    `completed_at` DATETIME NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`quote_id`) REFERENCES `solar_quotes`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE RESTRICT,
    FOREIGN KEY (`technician_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
    INDEX `idx_projects_lookup` (`contract_code`, `status`, `current_stage`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `installation_items` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `project_id` INT NOT NULL,
    `product_id` INT NOT NULL,
    `quantity` INT NOT NULL DEFAULT 1,
    `unit_price` DECIMAL(15,2) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`project_id`) REFERENCES `projects`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `project_stages` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `project_id` INT NOT NULL,
    `stage` ENUM('survey', 'design', 'procurement', 'installation', 'grid_connection', 'handover') NOT NULL,
    `position` TINYINT NOT NULL COMMENT 'Thứ tự từ 1 đến 6',
    `status` ENUM('locked', 'in_progress', 'pending_approval', 'revision_required', 'approved') NOT NULL DEFAULT 'locked',
    `planned_start` DATE NULL,
    `planned_end` DATE NULL,
    `started_at` DATETIME NULL,
    `submitted_at` DATETIME NULL,
    `submitted_by` INT NULL,
    `reviewed_at` DATETIME NULL,
    `reviewed_by` INT NULL,
    `completed_at` DATETIME NULL,
    `review_note` TEXT NULL,
    UNIQUE KEY `uk_project_stage` (`project_id`, `stage`),
    UNIQUE KEY `uk_project_position` (`project_id`, `position`),
    FOREIGN KEY (`project_id`) REFERENCES `projects`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`submitted_by`) REFERENCES `users`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`reviewed_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `project_assignments` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `project_id` INT NOT NULL,
    `technician_id` INT NOT NULL,
    `planned_start` DATE NOT NULL,
    `planned_end` DATE NOT NULL,
    `hours_per_day` DECIMAL(4,2) NOT NULL DEFAULT 4.00,
    `assigned_by` INT NOT NULL,
    `assigned_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ended_at` DATETIME NULL,
    FOREIGN KEY (`project_id`) REFERENCES `projects`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`technician_id`) REFERENCES `users`(`id`) ON DELETE RESTRICT,
    FOREIGN KEY (`assigned_by`) REFERENCES `users`(`id`) ON DELETE RESTRICT,
    INDEX `idx_assign_workload` (`technician_id`, `ended_at`, `planned_start`, `planned_end`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `project_requests` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `project_id` INT NOT NULL,
    `stage_id` INT NOT NULL,
    `request_type` ENUM('postpone', 'replacement') NOT NULL,
    `reason` TEXT NOT NULL,
    `proposed_start` DATE NULL,
    `proposed_end` DATE NULL,
    `old_technician_id` INT NULL,
    `proposed_technician_id` INT NULL,
    `status` ENUM('pending', 'approved', 'rejected', 'superseded') NOT NULL DEFAULT 'pending',
    `requested_by` INT NOT NULL,
    `requested_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `reviewed_by` INT NULL,
    `reviewed_at` DATETIME NULL,
    `review_note` TEXT NULL,
    FOREIGN KEY (`project_id`) REFERENCES `projects`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`stage_id`) REFERENCES `project_stages`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`old_technician_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`proposed_technician_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`requested_by`) REFERENCES `users`(`id`) ON DELETE RESTRICT,
    FOREIGN KEY (`reviewed_by`) REFERENCES `users`(`id`) ON DELETE SET NULL,
    INDEX `idx_requests_status` (`project_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `project_stage_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `project_id` INT NOT NULL,
    `stage` ENUM('survey', 'design', 'procurement', 'installation', 'grid_connection', 'handover') NOT NULL,
    `started_at` DATETIME NOT NULL,
    `completed_at` DATETIME NULL,
    `actor_id` INT NULL,
    `action` VARCHAR(50) NOT NULL,
    `from_status` VARCHAR(30) NULL,
    `to_status` VARCHAR(30) NULL,
    `note` TEXT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`project_id`) REFERENCES `projects`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`actor_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
    INDEX `idx_stage_logs` (`project_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `project_documents` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `project_id` INT NOT NULL,
    `stage_id` INT NOT NULL,
    `document_type` ENUM(
        'survey_photo',
        'technical_drawing',
        'evn_permit',
        'procurement_invoice',
        'handover_report',
        'installation_photo',
        'testing_photo',
        'stage_photo'
    ) NOT NULL,
    `file_name` VARCHAR(255) NOT NULL COMMENT 'Tên tệp gốc',
    `file_hash` CHAR(64) NOT NULL COMMENT 'Chuỗi băm SHA-256 chống trùng lặp',
    `file_path` VARCHAR(255) NOT NULL COMMENT 'Đường dẫn lưu trên disk',
    `file_size_kb` INT NOT NULL,
    `file_type` VARCHAR(50) NOT NULL COMMENT 'MIME-type',
    `uploaded_by` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`project_id`) REFERENCES `projects`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`stage_id`) REFERENCES `project_stages`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`uploaded_by`) REFERENCES `users`(`id`) ON DELETE RESTRICT,
    UNIQUE KEY `uk_stage_filehash` (`stage_id`, `file_hash`),
    INDEX `idx_project_docs` (`project_id`, `stage_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hang_sua` (
    `Ma_hang_sua` VARCHAR(20) NOT NULL PRIMARY KEY,
    `Ten_hang_sua` VARCHAR(100) NOT NULL,
    `Dia_chi` VARCHAR(200) NULL,
    `Dien_thoai` VARCHAR(20) NULL,
    `Email` VARCHAR(100) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `loai_sua` (
    `Ma_loai_sua` VARCHAR(20) NOT NULL PRIMARY KEY,
    `Ten_loai` VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sua` (
    `Ma_sua` VARCHAR(20) NOT NULL PRIMARY KEY,
    `Ten_sua` VARCHAR(100) NOT NULL,
    `Ma_hang_sua` VARCHAR(20) NOT NULL,
    `Ma_loai_sua` VARCHAR(20) NOT NULL,
    `Trong_luong` INT NOT NULL COMMENT 'Trọng lượng (gram hoặc ml)',
    `Don_gia` DECIMAL(15,2) NOT NULL COMMENT 'Đơn giá (VNĐ)',
    `TP_Dinh_Duong` TEXT NULL COMMENT 'Thành phần dinh dưỡng',
    `Loi_ich` TEXT NULL COMMENT 'Lợi ích sức khỏe',
    `Hinh` VARCHAR(255) NULL COMMENT 'Tên file hình ảnh sản phẩm',
    FOREIGN KEY (`Ma_hang_sua`) REFERENCES `hang_sua`(`Ma_hang_sua`) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (`Ma_loai_sua`) REFERENCES `loai_sua`(`Ma_loai_sua`) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX `idx_sua_search` (`Ten_sua`, `Don_gia`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `khach_hang` (
    `Ma_khach_hang` VARCHAR(20) NOT NULL PRIMARY KEY,
    `Ten_khach_hang` VARCHAR(100) NOT NULL,
    `Phai` TINYINT(1) DEFAULT 0 COMMENT '0: Nam, 1: Nữ',
    `Dia_chi` VARCHAR(200) NULL,
    `Dien_thoai` VARCHAR(20) NULL,
    `Email` VARCHAR(100) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hoa_don` (
    `So_hoa_don` VARCHAR(20) NOT NULL PRIMARY KEY,
    `Ngay_HD` DATE NOT NULL,
    `Ma_khach_hang` VARCHAR(20) NOT NULL,
    `Tri_gia` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (`Ma_khach_hang`) REFERENCES `khach_hang`(`Ma_khach_hang`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ct_hoadon` (
    `So_hoa_don` VARCHAR(20) NOT NULL,
    `Ma_sua` VARCHAR(20) NOT NULL,
    `So_luong` INT NOT NULL DEFAULT 1,
    `Don_gia` DECIMAL(15,2) NOT NULL,
    PRIMARY KEY (`So_hoa_don`, `Ma_sua`),
    FOREIGN KEY (`So_hoa_don`) REFERENCES `hoa_don`(`So_hoa_don`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`Ma_sua`) REFERENCES `sua`(`Ma_sua`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS project_extra_materials (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    product_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(15,2) NOT NULL,
    reason TEXT NOT NULL,
    added_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (added_by) REFERENCES users(id),
    INDEX(project_id,id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS project_payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    paid_by INT NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    payment_code VARCHAR(40) NOT NULL UNIQUE,
    method VARCHAR(30) NOT NULL DEFAULT 'simulation',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (paid_by) REFERENCES users(id),
    INDEX(project_id,id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
