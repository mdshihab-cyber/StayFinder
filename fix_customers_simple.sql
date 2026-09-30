-- ============================================
-- Fix Customer Data for Host Dashboard - Simplified
-- ============================================

PRINT '?? FIXING: Customer data for host dashboard testing...';

-- Find or create test host
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

-- Test the query without PropertyReviews issues
PRINT '';
PRINT '?? TESTING SIMPLIFIED CUSTOMERS QUERY:';
PRINT '=====================================';

SELECT DISTINCT
    u.Id AS CustomerId,
    u.FullName AS CustomerName,
    u.Email AS CustomerEmail,
    u.Phone AS CustomerPhone,
    COALESCE(c.Rating, 0) AS CustomerRating,
    COUNT(b.Id) AS TotalBookings,
    COALESCE(SUM(b.TotalPrice), 0) AS TotalSpent,
    0 AS AverageRating,  -- Simplified for now
    MAX(b.CreatedAt) AS LastBookingDate,
    MIN(b.CreatedAt) AS FirstBookingDate
FROM Users u
INNER JOIN Bookings b ON u.Id = b.CustomerId
INNER JOIN Properties prop ON b.PropertyId = prop.Id
LEFT JOIN Customers c ON u.Id = c.Id
WHERE prop.HostId = @TestHostUserId AND u.Role = 'Customer'
GROUP BY u.Id, u.FullName, u.Email, u.Phone, c.Rating
ORDER BY MAX(b.CreatedAt) DESC;

PRINT '';
PRINT '?? TEST INFORMATION:';
PRINT '====================';
PRINT 'Host User ID: ' + CAST(@TestHostUserId AS VARCHAR);
PRINT 'Customer User ID: ' + CAST(@TestCustomerUserId AS VARCHAR);
PRINT 'Test Property ID: ' + CAST(@TestPropertyId AS VARCHAR);
PRINT '';
PRINT 'API URLs to test:';
PRINT 'GET /api/Customers/host/' + CAST(@TestHostUserId AS VARCHAR);
PRINT 'GET /api/Customers/host/' + CAST(@TestHostUserId AS VARCHAR) + '/summary';
PRINT 'GET /api/Customers/test';
PRINT '';
PRINT '? Customer data setup complete!';