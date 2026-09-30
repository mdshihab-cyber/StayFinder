-- ============================================
-- Diagnostic Script for Host Customers Issues
-- ============================================

PRINT '?? DIAGNOSING HOST CUSTOMERS FUNCTIONALITY...';
PRINT '============================================';

-- Check if required tables exist
PRINT '';
PRINT '1. CHECKING TABLE EXISTENCE:';
PRINT '----------------------------';
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Users') 
        THEN '? Users table exists'
        ELSE '? Users table MISSING'
    END as UsersTable,
    
    CASE 
        WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Customers') 
        THEN '? Customers table exists'
        ELSE '? Customers table MISSING'
    END as CustomersTable,
    
    CASE 
        WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Bookings') 
        THEN '? Bookings table exists'
        ELSE '? Bookings table MISSING'
    END as BookingsTable,
    
    CASE 
        WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Properties') 
        THEN '? Properties table exists'
        ELSE '? Properties table MISSING'
    END as PropertiesTable,
    
    CASE 
        WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'PropertyReviews') 
        THEN '? PropertyReviews table exists'
        ELSE '? PropertyReviews table MISSING'
    END as PropertyReviewsTable;

-- Check data in tables
PRINT '';
PRINT '2. CHECKING DATA AVAILABILITY:';
PRINT '------------------------------';

-- Users data
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Users')
BEGIN
    SELECT 
        'Users Table' as TableName,
        COUNT(*) as TotalRecords,
        COUNT(CASE WHEN Role = 'Host' THEN 1 END) as Hosts,
        COUNT(CASE WHEN Role = 'Customer' THEN 1 END) as Customers
    FROM Users;
END
ELSE
BEGIN
    SELECT 'Users table does not exist' as Error;
END

-- Properties data
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Properties')
BEGIN
    SELECT 
        'Properties Table' as TableName,
        COUNT(*) as TotalProperties,
        COUNT(DISTINCT HostId) as UniqueHosts
    FROM Properties;
END

-- Bookings data
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Bookings')
BEGIN
    SELECT 
        'Bookings Table' as TableName,
        COUNT(*) as TotalBookings,
        COUNT(DISTINCT CustomerId) as UniqueCustomers,
        COUNT(DISTINCT PropertyId) as PropertiesWithBookings
    FROM Bookings;
END

-- Check if there are any host-customer relationships
PRINT '';
PRINT '3. CHECKING HOST-CUSTOMER RELATIONSHIPS:';
PRINT '---------------------------------------';

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Users') 
   AND EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Properties')
   AND EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Bookings')
BEGIN
    SELECT 
        h.Id as HostId,
        h.FullName as HostName,
        h.Email as HostEmail,
        COUNT(DISTINCT p.Id) as Properties,
        COUNT(DISTINCT b.Id) as Bookings,
        COUNT(DISTINCT b.CustomerId) as UniqueCustomers
    FROM Users h
    LEFT JOIN Properties p ON h.Id = p.HostId
    LEFT JOIN Bookings b ON p.Id = b.PropertyId
    WHERE h.Role = 'Host'
    GROUP BY h.Id, h.FullName, h.Email
    ORDER BY COUNT(DISTINCT b.Id) DESC;
END

-- Test the actual query that the API uses
PRINT '';
PRINT '4. TESTING API QUERY WITH SAMPLE HOST:';
PRINT '--------------------------------------';

DECLARE @TestHostId INT = (SELECT TOP 1 Id FROM Users WHERE Role = 'Host');

IF @TestHostId IS NOT NULL
BEGIN
    PRINT 'Testing with Host ID: ' + CAST(@TestHostId AS VARCHAR);
    
    SELECT 
        u.Id AS CustomerId,
        u.FullName AS CustomerName,
        u.Email AS CustomerEmail,
        u.Phone AS CustomerPhone,
        COALESCE(c.Rating, 0) AS CustomerRating,
        COUNT(b.Id) AS TotalBookings,
        COALESCE(SUM(b.TotalPrice), 0) AS TotalSpent,
        MAX(b.CreatedAt) AS LastBookingDate
    FROM Users u
    INNER JOIN Bookings b ON u.Id = b.CustomerId
    INNER JOIN Properties prop ON b.PropertyId = prop.Id
    LEFT JOIN Customers c ON u.Id = c.Id
    WHERE prop.HostId = @TestHostId AND u.Role = 'Customer'
    GROUP BY u.Id, u.FullName, u.Email, u.Phone, c.Rating
    ORDER BY MAX(b.CreatedAt) DESC;
    
    -- Also test the summary query
    SELECT 
        COUNT(DISTINCT u.Id) AS TotalCustomers,
        'Summary for Host ID: ' + CAST(@TestHostId AS VARCHAR) as Note
    FROM Users u
    INNER JOIN Bookings b ON u.Id = b.CustomerId
    INNER JOIN Properties prop ON b.PropertyId = prop.Id
    WHERE prop.HostId = @TestHostId AND u.Role = 'Customer';
END
ELSE
BEGIN
    PRINT '? No hosts found in database';
END

-- Check for common issues
PRINT '';
PRINT '5. CHECKING FOR COMMON ISSUES:';
PRINT '------------------------------';

-- Check for missing Role column
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'Role')
BEGIN
    PRINT '? Users.Role column exists';
END
ELSE
BEGIN
    PRINT '? Users.Role column MISSING - this will cause queries to fail';
END

-- Check for foreign key relationships
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Bookings' AND COLUMN_NAME = 'CustomerId')
   AND EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Bookings' AND COLUMN_NAME = 'PropertyId')
   AND EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Properties' AND COLUMN_NAME = 'HostId')
BEGIN
    PRINT '? Required foreign key columns exist';
END
ELSE
BEGIN
    PRINT '? Missing required foreign key columns';
END

-- Final recommendation
PRINT '';
PRINT '6. RECOMMENDATIONS:';
PRINT '------------------';
PRINT 'If you see any ? above, you need to:';
PRINT '1. Create missing tables using your create_tables.sql script';
PRINT '2. Add test data using test_host_customers_complete.sql';
PRINT '3. Ensure your connection string matches your actual database';
PRINT '4. Check server logs for specific error messages';

PRINT '';
PRINT '? Diagnostic complete. Check results above for issues.';