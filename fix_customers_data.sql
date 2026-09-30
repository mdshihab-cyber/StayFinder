-- ============================================
-- Fix Customer Data for Host Dashboard
-- ============================================

PRINT '?? FIXING: Customer data for host dashboard testing...';

-- First, let's check current data
PRINT 'Current Users:';
SELECT Id, Role, FullName, Email FROM Users;

PRINT 'Current Hosts:';
SELECT * FROM Hosts;

PRINT 'Current Properties:';
SELECT Id, HostId, Name, Location FROM Properties;

PRINT 'Current Bookings:';
SELECT Id, CustomerId, PropertyId FROM Bookings;

-- Find a test host (or create one)
DECLARE @TestHostUserId INT;
DECLARE @TestCustomerUserId INT;
DECLARE @TestPropertyId INT;

-- Get or create test host
SELECT TOP 1 @TestHostUserId = Id FROM Users WHERE Role = 'Host';

IF @TestHostUserId IS NULL
BEGIN
    INSERT INTO Users (Role, FullName, Email, Phone, Password, CreatedAt)
    VALUES ('Host', 'Test Host', 'testhost@example.com', '555-0001', 'password123', GETUTCDATE());
    
    SET @TestHostUserId = SCOPE_IDENTITY();
    
    -- Create host record
    INSERT INTO Hosts (UserId, Bio, Rating, NumberOfProperties)
    VALUES (@TestHostUserId, 'Test host for customer dashboard', 4.8, 1);
    
    PRINT '? Created test host with User ID: ' + CAST(@TestHostUserId AS VARCHAR);
END
ELSE
BEGIN
    PRINT '? Using existing host with User ID: ' + CAST(@TestHostUserId AS VARCHAR);
END

-- Get or create test customer
SELECT TOP 1 @TestCustomerUserId = Id FROM Users WHERE Role = 'Customer';

IF @TestCustomerUserId IS NULL
BEGIN
    INSERT INTO Users (Role, FullName, Email, Phone, Password, CreatedAt)
    VALUES ('Customer', 'Test Customer', 'testcustomer@example.com', '555-0002', 'password123', GETUTCDATE());
    
    SET @TestCustomerUserId = SCOPE_IDENTITY();
    
    -- Create customer record
    INSERT INTO Customers (Id, Rating, SavedProperties)
    VALUES (@TestCustomerUserId, 4.5, '[]');
    
    PRINT '? Created test customer with User ID: ' + CAST(@TestCustomerUserId AS VARCHAR);
END
ELSE
BEGIN
    PRINT '? Using existing customer with User ID: ' + CAST(@TestCustomerUserId AS VARCHAR);
    
    -- Ensure customer record exists in Customers table
    IF NOT EXISTS (SELECT 1 FROM Customers WHERE Id = @TestCustomerUserId)
    BEGIN
        INSERT INTO Customers (Id, Rating, SavedProperties)
        VALUES (@TestCustomerUserId, 4.5, '[]');
        PRINT '? Created customer record in Customers table';
    END
END

-- Get or create test property owned by the host
SELECT TOP 1 @TestPropertyId = Id FROM Properties WHERE HostId = @TestHostUserId;

IF @TestPropertyId IS NULL
BEGIN
    INSERT INTO Properties (HostId, Name, Type, PricePerDay, Location, Status, BookingStatus, CreatedAt)
    VALUES (@TestHostUserId, 'Test Property for Dashboard', 'Standard', 150.00, 'Test City', 'active', 'not booked', GETUTCDATE());
    
    SET @TestPropertyId = SCOPE_IDENTITY();
    PRINT '? Created test property with ID: ' + CAST(@TestPropertyId AS VARCHAR);
END
ELSE
BEGIN
    PRINT '? Using existing property with ID: ' + CAST(@TestPropertyId AS VARCHAR);
END

-- Create test bookings to establish relationship
IF NOT EXISTS (SELECT 1 FROM Bookings WHERE CustomerId = @TestCustomerUserId AND PropertyId = @TestPropertyId)
BEGIN
    INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
    VALUES (
        @TestCustomerUserId, 
        @TestPropertyId, 
        DATEADD(day, -30, GETUTCDATE()),  -- 30 days ago
        DATEADD(day, -27, GETUTCDATE()),  -- 27 days ago (3 night stay)
        2, 
        450.00, 
        'completed', 
        'paid', 
        DATEADD(day, -35, GETUTCDATE())   -- Booked 35 days ago
    );
    
    PRINT '? Created test booking';
END

-- Create a second customer and booking for more test data
DECLARE @TestCustomer2UserId INT;

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'testcustomer2@example.com')
BEGIN
    INSERT INTO Users (Role, FullName, Email, Phone, Password, CreatedAt)
    VALUES ('Customer', 'Test Customer 2', 'testcustomer2@example.com', '555-0003', 'password123', GETUTCDATE());
    
    SET @TestCustomer2UserId = SCOPE_IDENTITY();
    
    -- Create customer record
    INSERT INTO Customers (Id, Rating, SavedProperties)
    VALUES (@TestCustomer2UserId, 4.8, '[]');
    
    -- Create another booking
    INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
    VALUES (
        @TestCustomer2UserId, 
        @TestPropertyId, 
        DATEADD(day, -15, GETUTCDATE()),  -- 15 days ago
        DATEADD(day, -13, GETUTCDATE()),  -- 13 days ago (2 night stay)
        1, 
        300.00, 
        'completed', 
        'paid', 
        DATEADD(day, -20, GETUTCDATE())   -- Booked 20 days ago
    );
    
    PRINT '? Created second test customer and booking';
END

-- Test the exact query used by CustomersController
PRINT '';
PRINT '?? TESTING CUSTOMERS CONTROLLER QUERY:';
PRINT '=======================================';

SELECT DISTINCT
    u.Id AS CustomerId,
    u.FullName AS CustomerName,
    u.Email AS CustomerEmail,
    u.Phone AS CustomerPhone,
    COALESCE(c.Rating, 0) AS CustomerRating,
    COUNT(b.Id) AS TotalBookings,
    COALESCE(SUM(b.TotalPrice), 0) AS TotalSpent,
    COALESCE(AVG(CAST(COALESCE(pr_reviews.Rating, 0) AS FLOAT)), 0) AS AverageRating,
    MAX(b.CreatedAt) AS LastBookingDate,
    MIN(b.CreatedAt) AS FirstBookingDate
FROM Users u
INNER JOIN Bookings b ON u.Id = b.CustomerId
INNER JOIN Properties prop ON b.PropertyId = prop.Id
LEFT JOIN Customers c ON u.Id = c.Id
LEFT JOIN PropertyReviews pr_reviews ON b.Id = pr_reviews.BookingId
WHERE prop.HostId = @TestHostUserId AND u.Role = 'Customer'
GROUP BY u.Id, u.FullName, u.Email, u.Phone, c.Rating
ORDER BY MAX(b.CreatedAt) DESC;

-- Test summary query
PRINT '';
PRINT '?? TESTING CUSTOMERS SUMMARY QUERY:';
PRINT '====================================';

SELECT 
    COUNT(DISTINCT u.Id) AS TotalCustomers,
    COUNT(DISTINCT CASE 
        WHEN (SELECT COUNT(*) FROM Bookings b2 
              INNER JOIN Properties p2 ON b2.PropertyId = p2.Id 
              WHERE b2.CustomerId = u.Id AND p2.HostId = @TestHostUserId) > 1 
        THEN u.Id END) AS RepeatCustomers,
    COALESCE(AVG(CAST(COALESCE(pr_reviews.Rating, 0) AS FLOAT)), 0) AS CustomerSatisfaction
FROM Users u
INNER JOIN Bookings b ON u.Id = b.CustomerId
INNER JOIN Properties prop ON b.PropertyId = prop.Id
LEFT JOIN PropertyReviews pr_reviews ON b.Id = pr_reviews.BookingId
WHERE prop.HostId = @TestHostUserId AND u.Role = 'Customer';

PRINT '';
PRINT '?? TEST INFORMATION:';
PRINT '====================';
PRINT 'Host User ID: ' + CAST(@TestHostUserId AS VARCHAR);
PRINT 'Test Property ID: ' + CAST(@TestPropertyId AS VARCHAR);
PRINT '';
PRINT 'API URLs to test:';
PRINT 'GET /api/Customers/host/' + CAST(@TestHostUserId AS VARCHAR);
PRINT 'GET /api/Customers/host/' + CAST(@TestHostUserId AS VARCHAR) + '/summary';
PRINT 'GET /api/Customers/test';
PRINT '';
PRINT '? Customer data setup complete!';