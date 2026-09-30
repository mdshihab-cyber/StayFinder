-- ? CUSTOMER DASHBOARD FIX VERIFICATION SCRIPT
-- Run this to verify your database matches the expected schema and test the fixes

USE StayFinderWebApiDB;

-- 1. ? Verify Table Structure
PRINT '=== TABLE STRUCTURE VERIFICATION ===';

PRINT 'Checking if all required tables exist...';
SELECT 
    CASE WHEN EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Users') THEN '?' ELSE '?' END as Users,
    CASE WHEN EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Customers') THEN '?' ELSE '?' END as Customers,
    CASE WHEN EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Properties') THEN '?' ELSE '?' END as Properties,
    CASE WHEN EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Bookings') THEN '?' ELSE '?' END as Bookings,
    CASE WHEN EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Payments') THEN '?' ELSE '?' END as Payments;

-- 2. ? Verify PaymentStatus Values Match Code Expectations
PRINT '=== PAYMENT STATUS VERIFICATION ===';
PRINT 'Current PaymentStatus values in Bookings table:';
SELECT DISTINCT PaymentStatus, COUNT(*) as Count FROM Bookings GROUP BY PaymentStatus;

PRINT 'Expected values: unpaid, pending, paid';

-- 3. ? Create Test Data if None Exists
PRINT '=== TEST DATA CREATION ===';

-- Check if we have any customer users
DECLARE @CustomerCount INT = (SELECT COUNT(*) FROM Users WHERE Role = 'Customer');
PRINT 'Current Customer count: ' + CAST(@CustomerCount AS NVARCHAR(10));

IF @CustomerCount = 0
BEGIN
    PRINT 'Creating test customer...';
    
    -- Create a test customer user
    INSERT INTO Users (Role, FullName, Email, Phone, Password, CreatedAt)
    VALUES ('Customer', 'Test Customer', 'testcustomer@example.com', '1234567890', 'hashed_password', GETUTCDATE());
    
    DECLARE @TestCustomerId INT = SCOPE_IDENTITY();
    
    -- Create customer record
    INSERT INTO Customers (Id, Rating, SavedProperties)
    VALUES (@TestCustomerId, 4.5, '');
    
    PRINT 'Test customer created with ID: ' + CAST(@TestCustomerId AS NVARCHAR(10));
END

-- Check if we have any properties
DECLARE @PropertyCount INT = (SELECT COUNT(*) FROM Properties);
PRINT 'Current Property count: ' + CAST(@PropertyCount AS NVARCHAR(10));

IF @PropertyCount = 0
BEGIN
    PRINT 'Creating test property...';
    
    -- First, create a host user if none exists
    IF NOT EXISTS (SELECT * FROM Users WHERE Role = 'Host')
    BEGIN
        INSERT INTO Users (Role, FullName, Email, Phone, Password, CreatedAt)
        VALUES ('Host', 'Test Host', 'testhost@example.com', '0987654321', 'hashed_password', GETUTCDATE());
    END
    
    DECLARE @TestHostId INT = (SELECT TOP 1 Id FROM Users WHERE Role = 'Host');
    
    -- Create test property
    INSERT INTO Properties (HostId, Name, Type, PricePerDay, Location, ImageUrl, Status, Description, CreatedAt)
    VALUES (@TestHostId, 'Cozy Downtown Apartment', 'Apartment', 120.00, 'Downtown, City Center', 
            'https://via.placeholder.com/400x300', 'active', 'Beautiful apartment in the heart of the city', GETUTCDATE());
    
    PRINT 'Test property created';
END

-- Check if we have any bookings
DECLARE @BookingCount INT = (SELECT COUNT(*) FROM Bookings);
PRINT 'Current Booking count: ' + CAST(@BookingCount AS NVARCHAR(10));

IF @BookingCount = 0
BEGIN
    PRINT 'Creating test booking...';
    
    DECLARE @TestCustomerId2 INT = (SELECT TOP 1 Id FROM Users WHERE Role = 'Customer');
    DECLARE @TestPropertyId INT = (SELECT TOP 1 Id FROM Properties);
    
    IF @TestCustomerId2 IS NOT NULL AND @TestPropertyId IS NOT NULL
    BEGIN
        -- Create test booking with correct PaymentStatus
        INSERT INTO Bookings (PropertyId, CustomerId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
        VALUES (@TestPropertyId, @TestCustomerId2, 
                DATEADD(DAY, 7, GETDATE()),   -- Check-in: 7 days from now
                DATEADD(DAY, 10, GETDATE()),  -- Check-out: 10 days from now  
                2, 360.00, 'confirmed', 'unpaid', GETUTCDATE());
        
        DECLARE @TestBookingId INT = SCOPE_IDENTITY();
        PRINT 'Test booking created with ID: ' + CAST(@TestBookingId AS NVARCHAR(10));
        
        -- Create test payment
        INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status)
        VALUES (@TestBookingId, @TestCustomerId2, 360.00, 36.00, 'Credit Card', 'Initial Booking', 'completed');
        
        -- Update booking payment status
        UPDATE Bookings SET PaymentStatus = 'pending' WHERE Id = @TestBookingId;
        
        PRINT 'Test payment created';
    END
END

-- 4. ? Test API Queries
PRINT '=== API QUERY TESTING ===';

-- Test the query that the BookingsController uses
PRINT 'Testing BookingsController query...';
DECLARE @TestCustomerId3 INT = (SELECT TOP 1 Id FROM Users WHERE Role = 'Customer');

IF @TestCustomerId3 IS NOT NULL
BEGIN
    SELECT 
        'Query Result:' as Status,
        COUNT(*) as BookingCount
    FROM Bookings b
    INNER JOIN Properties p ON b.PropertyId = p.Id
    WHERE b.CustomerId = @TestCustomerId3;
    
    -- Show sample results
    SELECT TOP 3
        b.Id,
        b.PropertyId,
        p.Name as PropertyName,
        p.Location,
        b.BookingFrom,
        b.BookingTo,
        b.TotalPrice,
        b.Status,
        b.PaymentStatus
    FROM Bookings b
    INNER JOIN Properties p ON b.PropertyId = p.Id
    WHERE b.CustomerId = @TestCustomerId3
    ORDER BY b.CreatedAt DESC;
END

-- Test the CustomerProfile query
PRINT 'Testing CustomerProfile query...';
IF @TestCustomerId3 IS NOT NULL
BEGIN
    SELECT 
        u.Id, u.FullName, u.Email, u.Phone, u.Role,
        c.Rating, c.SavedProperties
    FROM Users u
    LEFT JOIN Customers c ON u.Id = c.Id
    WHERE u.Id = @TestCustomerId3 AND u.Role = 'Customer';
END

-- 5. ? Final Status Report
PRINT '=== FINAL STATUS REPORT ===';
SELECT 
    'Users' as TableName, COUNT(*) as RecordCount FROM Users
UNION ALL
SELECT 'Customers', COUNT(*) FROM Customers  
UNION ALL
SELECT 'Properties', COUNT(*) FROM Properties
UNION ALL
SELECT 'Bookings', COUNT(*) FROM Bookings
UNION ALL
SELECT 'Payments', COUNT(*) FROM Payments;

-- Show payment status distribution
PRINT 'Payment Status Distribution:';
SELECT 
    PaymentStatus, 
    COUNT(*) as Count,
    CASE 
        WHEN PaymentStatus IN ('unpaid', 'pending', 'paid') THEN '? Valid'
        ELSE '? Invalid - Update needed'
    END as Status
FROM Bookings 
GROUP BY PaymentStatus;

PRINT '=== VERIFICATION COMPLETE ===';
PRINT 'If you see ? for all tables and valid payment statuses, your database is ready!';
PRINT 'If you see ?, please run the necessary fixes.';

-- Quick fix for invalid payment statuses
IF EXISTS (SELECT * FROM Bookings WHERE PaymentStatus NOT IN ('unpaid', 'pending', 'paid'))
BEGIN
    PRINT 'FIXING INVALID PAYMENT STATUSES...';
    
    UPDATE Bookings SET PaymentStatus = 'unpaid' WHERE PaymentStatus IS NULL OR PaymentStatus = '';
    UPDATE Bookings SET PaymentStatus = 'pending' WHERE PaymentStatus = 'initial';
    
    PRINT 'Payment statuses fixed!';
    
    -- Show updated distribution
    SELECT 'AFTER FIX - PaymentStatus Distribution:' as Status;
    SELECT PaymentStatus, COUNT(*) as Count FROM Bookings GROUP BY PaymentStatus;
END