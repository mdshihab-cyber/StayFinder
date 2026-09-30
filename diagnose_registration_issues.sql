-- Diagnostic script to identify registration issues
-- Updated to work with actual Customers table structure (Id is both PK and FK)

-- 1. Check if database and tables exist
SELECT 'Database Check:' as Info;
SELECT DB_NAME() as CurrentDatabase;

-- 2. Check if all required tables exist
SELECT 'Table Existence Check:' as Info;
SELECT 
    TABLE_NAME,
    CASE WHEN TABLE_NAME IN ('Users', 'Hosts', 'Customers', 'Properties') 
         THEN 'Required table exists' 
         ELSE 'Additional table' END as Status
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- 3. Check Users table structure
SELECT 'Users Table Structure:' as Info;
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Users'
ORDER BY ORDINAL_POSITION;

-- 4. Check for any existing users (to see if basic insert works)
SELECT 'Existing Users Count:' as Info;
SELECT COUNT(*) as TotalUsers FROM Users;

-- 5. Test a sample INSERT to see if there are any constraint issues
SELECT 'Testing Sample Insert:' as Info;
BEGIN TRY
    BEGIN TRANSACTION;
    
    -- Try inserting a test user
    INSERT INTO Users (Role, FullName, Email, Phone, Password, CreatedAt)
    VALUES ('Customer', 'Test User', 'test@example.com', '1234567890', 'testpass', GETUTCDATE());
    
    DECLARE @TestUserId INT = SCOPE_IDENTITY();
    SELECT 'Test user insert successful, UserId: ' + CAST(@TestUserId as NVARCHAR(10)) as Result;
    
    -- Test inserting into Customers table (Id is both PK and FK)
    INSERT INTO Customers (Id, Rating, SavedProperties)
    VALUES (@TestUserId, 0.00, '[]');
    
    SELECT 'Customer record insert successful' as Result;
    
    -- Clean up the test records
    DELETE FROM Customers WHERE Id = @TestUserId;
    DELETE FROM Users WHERE Id = @TestUserId;
    
    ROLLBACK TRANSACTION;
    SELECT 'Test completed successfully - no database issues' as FinalResult;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    SELECT 
        'Error occurred during test insert:' as Result,
        ERROR_MESSAGE() as ErrorMessage,
        ERROR_NUMBER() as ErrorNumber,
        ERROR_SEVERITY() as ErrorSeverity;
END CATCH;

-- 6. Check foreign key constraints
SELECT 'Foreign Key Constraints:' as Info;
SELECT 
    fk.name as ConstraintName,
    tp.name as ParentTable,
    tr.name as ReferencedTable
FROM sys.foreign_keys fk
INNER JOIN sys.tables tp ON fk.parent_object_id = tp.object_id
INNER JOIN sys.tables tr ON fk.referenced_object_id = tr.object_id;

-- 7. Check for any triggers that might interfere
SELECT 'Triggers on Users table:' as Info;
SELECT 
    t.name as TriggerName,
    t.is_disabled as IsDisabled,
    te.type_desc as TriggerEvent
FROM sys.triggers t
INNER JOIN sys.trigger_events te ON t.object_id = te.object_id
INNER JOIN sys.tables tb ON t.parent_id = tb.object_id
WHERE tb.name = 'Users';

-- 8. Check if Customers table exists and has correct structure
SELECT 'Customers Table Check:' as Info;
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Customers')
    SELECT 'Customers table exists' as Status
ELSE
    SELECT 'Customers table MISSING - this is the problem!' as Status;

-- 9. Show Customers table structure if it exists
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Customers')
BEGIN
    SELECT 'Customers Table Structure:' as Info;
    SELECT 
        COLUMN_NAME,
        DATA_TYPE,
        IS_NULLABLE,
        COLUMN_DEFAULT,
        CHARACTER_MAXIMUM_LENGTH
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'Customers'
    ORDER BY ORDINAL_POSITION;
    
    -- Specifically check for the expected structure
    SELECT 'Customers Table Column Analysis:' as Info;
    SELECT 
        CASE 
            WHEN COLUMN_NAME = 'Id' AND DATA_TYPE = 'int' THEN '? Id column correct (int, PK/FK)'
            WHEN COLUMN_NAME = 'Rating' AND DATA_TYPE = 'decimal' THEN '? Rating column correct'
            WHEN COLUMN_NAME = 'SavedProperties' AND DATA_TYPE = 'nvarchar' THEN '? SavedProperties column correct'
            ELSE '? ' + COLUMN_NAME + ' (' + DATA_TYPE + ') - unexpected column'
        END as ColumnStatus,
        COLUMN_NAME,
        DATA_TYPE
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'Customers'
    ORDER BY ORDINAL_POSITION;
END;