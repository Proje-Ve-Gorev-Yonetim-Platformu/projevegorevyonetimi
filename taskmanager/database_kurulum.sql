-- Eğer veritabanını henüz oluşturmadıysan önce bu iki satırı çalıştır:
-- CREATE DATABASE GorevYonetimDB;
-- USE GorevYonetimDB;
CREATE DATABASE GorevYonetimDB;
USE GorevYonetimDB;
-- 1. ROLES TABLOSU
CREATE TABLE Roles (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    RoleName VARCHAR(50) NOT NULL UNIQUE
);

-- 2. USERS TABLOSU
CREATE TABLE Users (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    Username VARCHAR(50) NOT NULL UNIQUE,
    Email VARCHAR(100) NOT NULL UNIQUE,
    PasswordHash VARCHAR(255) NOT NULL,
    IsActive BOOLEAN DEFAULT 1,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 3. USERROLES TABLOSU
CREATE TABLE UserRoles (
    UserId INT,
    RoleId INT,
    PRIMARY KEY (UserId, RoleId),
    FOREIGN KEY (UserId) REFERENCES Users(Id),
    FOREIGN KEY (RoleId) REFERENCES Roles(Id)
);

-- 4. SESSIONS TABLOSU
CREATE TABLE Sessions (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    UserId INT,
    Token VARCHAR(255) NOT NULL,
    ExpiryDate DATETIME NOT NULL,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (UserId) REFERENCES Users(Id)
);

-- 5. PROJECTS TABLOSU
CREATE TABLE Projects (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Description TEXT,
    StartDate DATE,
    EndDate DATE,
    IsActive BOOLEAN DEFAULT 1,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 6. TASKS TABLOSU
CREATE TABLE Tasks (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    ProjectId INT,
    Title VARCHAR(150) NOT NULL,
    Description TEXT,
    Status VARCHAR(50) DEFAULT 'Yapılacak',
    DueDate DATE,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ProjectId) REFERENCES Projects(Id)
);

-- 7. TASKASSIGNMENTS TABLOSU
CREATE TABLE TaskAssignments (
    TaskId INT,
    UserId INT,
    AssignedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (TaskId, UserId),
    FOREIGN KEY (TaskId) REFERENCES Tasks(Id),
    FOREIGN KEY (UserId) REFERENCES Users(Id)
);

-- 8. PENALTYTYPES TABLOSU
CREATE TABLE PenaltyTypes (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    DefaultPoints INT NOT NULL
);

-- 9. PENALTIES TABLOSU (Ceza Sistemi)
CREATE TABLE Penalties (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    UserId INT,
    PenaltyTypeId INT,
    Reason TEXT,
    AppliedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (UserId) REFERENCES Users(Id),
    FOREIGN KEY (PenaltyTypeId) REFERENCES PenaltyTypes(Id)
);

-- 10. ACTIONLOGS TABLOSU
CREATE TABLE ActionLogs (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    UserId INT,
    ActionType VARCHAR(50) NOT NULL,
    Description TEXT,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (UserId) REFERENCES Users(Id)
);

-- 11. COMMENTS TABLOSU
CREATE TABLE Comments (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TaskId INT,
    UserId INT,
    Content TEXT NOT NULL,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (TaskId) REFERENCES Tasks(Id),
    FOREIGN KEY (UserId) REFERENCES Users(Id)
);

-- 12. ATTACHMENTS TABLOSU
CREATE TABLE Attachments (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TaskId INT,
    FileUrl VARCHAR(255) NOT NULL,
    UploadedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (TaskId) REFERENCES Tasks(Id)
);

-- =============================================
-- STORED PROCEDURE VE TRIGGER İÇİN DELIMITER DEĞİŞİMİ
-- =============================================
DELIMITER //

-- =============================================
-- STORED PROCEDURE: Görev Tamamlama ve Ceza Kontrolü
-- =============================================
CREATE PROCEDURE sp_CompleteTask(IN p_TaskId INT, IN p_UserId INT)
BEGIN
    DECLARE v_DueDate DATE;
    DECLARE v_PenaltyTypeId INT;

    -- Görevin bitiş tarihini çek
    SELECT DueDate INTO v_DueDate FROM Tasks WHERE Id = p_TaskId;

    -- Görevi Tamamlandı olarak güncelle
    UPDATE Tasks SET Status = 'Tamamlandı' WHERE Id = p_TaskId;

    -- Tarih geçmişse ceza uygula
    IF (CURDATE() > v_DueDate) THEN
        -- Gecikme cezası ID'sini bul (Tabloda 'Gecikme' adında bir ceza türü eklenmiş olmalı)
        SELECT Id INTO v_PenaltyTypeId FROM PenaltyTypes WHERE Name = 'Gecikme' LIMIT 1;
        
        IF (v_PenaltyTypeId IS NOT NULL) THEN
            INSERT INTO Penalties (UserId, PenaltyTypeId, Reason)
            VALUES (p_UserId, v_PenaltyTypeId, 'Görev teslim tarihinden sonra tamamlandı.');
        END IF;
    END IF;
END //

-- =============================================
-- TRIGGER: Sistem Loglayıcısı (Proje Silinmesini Engelleme ve Loglama)
-- =============================================
CREATE TRIGGER trg_PreventProjectDelete
BEFORE DELETE ON Projects
FOR EACH ROW
BEGIN
    -- İşlem logunu tut (Kimlik 1 olarak varsayıldı, uygulama tarafında yönetilebilir)
    INSERT INTO ActionLogs (UserId, ActionType, Description)
    VALUES (1, 'DELETE_ATTEMPT', CONCAT('Proje silinmek istendi. Proje ID: ', OLD.Id));

    -- Silme işlemini hata fırlatarak durdur
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Projeler fiziksel olarak silinemez, durumunu pasif (IsActive=0) yapmalısınız!';
END //

DELIMITER ;