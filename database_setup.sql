-- StayFinder Database Setup Script
-- Updated to match your actual table structure

-- Drop tables if they exist (use with caution in production)
-- DROP TABLE IF EXISTS Properties;
-- DROP TABLE IF EXISTS Customers;
-- DROP TABLE IF EXISTS Hosts;
-- DROP TABLE IF EXISTS Users;

-- Create Users table
CREATE TABLE Users (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Role NVARCHAR(50) NOT NULL,
    FullName NVARCHAR(200) NOT NULL,
    Email NVARCHAR(150) NOT NULL UNIQUE,
    Phone NVARCHAR(20) NOT NULL,
    Password NVARCHAR(100) NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

-- Create Hosts table
CREATE TABLE Hosts (
    HostId INT IDENTITY(1,1) PRIMARY KEY,  
    UserId INT NOT NULL,                   
    Bio NVARCHAR(MAX) NULL,
    Rating DECIMAL(3,2) DEFAULT 0.00,
    NumberOfProperties INT DEFAULT 0,
    FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
);

-- Create Customers table (Id is both PK and FK to Users.Id)
CREATE TABLE Customers (
    Id INT PRIMARY KEY, 
    Rating DECIMAL(3,2) DEFAULT 0, 
    SavedProperties NVARCHAR(MAX) DEFAULT '[]',
    FOREIGN KEY (Id) REFERENCES Users(Id) ON DELETE CASCADE
);

-- Create Properties table with Description field
CREATE TABLE Properties (
    Id INT IDENTITY(1,1) PRIMARY KEY,      
    HostId INT NOT NULL,                  
    Name NVARCHAR(100) NOT NULL,           
    Type NVARCHAR(50) NOT NULL,             
    PricePerDay DECIMAL(10,2) NOT NULL,     
    Location NVARCHAR(200) NOT NULL,       
    ImageUrl NVARCHAR(500),                
    Status NVARCHAR(50) NOT NULL DEFAULT 'active', 
    BookingStatus NVARCHAR(50) NOT NULL DEFAULT 'not booked',
    BookingFrom DATETIME NULL,              
    BookingTo DATETIME NULL,
    Description NVARCHAR(MAX),             -- Added description field
    CreatedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME NULL,

    CONSTRAINT FK_Properties_Host FOREIGN KEY (HostId)
        REFERENCES Users(Id)
        ON DELETE CASCADE
);

-- Verify Users table structure
SELECT 
    'Users' as TableName,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Users'
ORDER BY ORDINAL_POSITION;

-- Verify Hosts table structure
SELECT 
    'Hosts' as TableName,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Hosts'
ORDER BY ORDINAL_POSITION;

-- Verify Customers table structure
SELECT 
    'Customers' as TableName,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Customers'
ORDER BY ORDINAL_POSITION;

-- Verify Properties table structure
SELECT 
    'Properties' as TableName,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Properties'
ORDER BY ORDINAL_POSITION;

-- Sample data (optional - for testing)
-- INSERT INTO Users (Role, FullName, Email, Phone, Password, CreatedAt)
-- VALUES 
-- ('Host', 'John Doe', 'john@example.com', '+1234567890', 'password123', GETUTCDATE()),
-- ('Customer', 'Jane Smith', 'jane@example.com', '+0987654321', 'password456', GETUTCDATE());

-- Sample host data (will be created automatically when users register as hosts)
-- INSERT INTO Hosts (UserId, Bio, Rating, NumberOfProperties)
-- VALUES (1, 'Experienced host with multiple properties', 4.5, 3);

-- Sample customer data (will be created automatically when users register as customers)
-- Note: For Customers table, Id is the same as Users.Id (no separate UserId column)
-- INSERT INTO Customers (Id, Rating, SavedProperties)
-- VALUES (2, 4.2, '[1,3]');

-- Sample property data with description
-- INSERT INTO Properties (HostId, Name, Type, PricePerDay, Location, ImageUrl, Status, BookingStatus, Description, CreatedAt)
-- VALUES 
-- (1, 'Cozy Downtown Apartment', 'Standard', 75.00, 'Downtown City Center', 'https://example.com/image1.jpg', 'active', 'not booked', 'Beautiful apartment in the heart of downtown with modern amenities', GETUTCDATE()),
-- (1, 'Luxury Beach House', 'Luxury', 250.00, 'Beachfront Boulevard', 'https://example.com/image2.jpg', 'active', 'not booked', 'Stunning beachfront property with panoramic ocean views and private beach access', GETUTCDATE());