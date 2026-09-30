-- Quick fix script to rename Customer table to Customers
-- Run this if you have existing Customer table that needs to be renamed

-- Check if Customer table exists and Customers doesn't
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Customer')
   AND NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Customers')
BEGIN
    PRINT 'Renaming Customer table to Customers...'
    EXEC sp_rename 'Customer', 'Customers'
    PRINT 'Table renamed successfully!'
END
ELSE IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Customers')
BEGIN
    PRINT 'Customers table already exists - no changes needed'
END
ELSE IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Customer')
     AND EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Customers')
BEGIN
    PRINT 'Both Customer and Customers tables exist!'
    PRINT 'Please manually resolve this conflict:'
    PRINT '1. Check data in both tables'
    PRINT '2. Migrate data if needed'  
    PRINT '3. Drop the Customer table when safe'
END
ELSE
BEGIN
    PRINT 'Neither Customer nor Customers table exists!'
    PRINT 'Please run the database_setup.sql script to create all tables'
END

-- Verify the result
SELECT 'Table Check After Fix:' as Info;
SELECT TABLE_NAME, 
       CASE WHEN TABLE_NAME = 'Customers' THEN '? Correct table name' 
            WHEN TABLE_NAME = 'Customer' THEN '? Old table name still exists'
            ELSE 'Other table' END as Status
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME IN ('Customer', 'Customers')
ORDER BY TABLE_NAME;