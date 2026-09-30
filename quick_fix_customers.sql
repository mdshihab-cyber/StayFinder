-- ============================================
-- Quick Fix for Host Customers Issue
-- ============================================

PRINT '?? QUICK FIX: Creating minimal test data for customers functionality...';

-- Ensure we have a test host
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'test.host@fix.com')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Test Host Fix', 'test.host@fix.com', 'password123', 'Host', '555-1234', GETUTCDATE());
    
    DECLARE @HostId INT = SCOPE_IDENTITY();
    
    -- Create host record if Hosts table exists
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Hosts')
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM Hosts WHERE Id = @HostId)
        BEGIN
            INSERT INTO Hosts (Id, Bio) VALUES (@HostId, 'Test host for debugging');
        END
    END
    
    PRINT '? Created test host with ID: ' + CAST(@HostId AS VARCHAR);
END
ELSE
BEGIN
    SELECT @HostId = Id FROM Users WHERE Email = 'test.host@fix.com';
    PRINT '? Using existing test host with ID: ' + CAST(@HostId AS VARCHAR);
END

-- Ensure we have a test customer
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'test.customer@fix.com')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Test Customer Fix', 'test.customer@fix.com', 'password123', 'Customer', '555-5678', GETUTCDATE());
    
    DECLARE @CustomerId INT = SCOPE_IDENTITY();
    
    -- Create customer record if Customers table exists
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Customers')
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM Customers WHERE Id = @CustomerId)
        BEGIN
            INSERT INTO Customers (Id, Rating, SavedProperties) VALUES (@CustomerId, 4.5, '[]');
        END
    END
    
    PRINT '? Created test customer with ID: ' + CAST(@CustomerId AS VARCHAR);
END
ELSE
BEGIN
    SELECT @CustomerId = Id FROM Users WHERE Email = 'test.customer@fix.com';
    PRINT '? Using existing test customer with ID: ' + CAST(@CustomerId AS VARCHAR);
END

-- Create a test property
IF NOT EXISTS (SELECT 1 FROM Properties WHERE HostId = @HostId AND Name = 'Test Property Fix')
BEGIN
    INSERT INTO Properties (HostId, Name, Type, PricePerDay, Location, Status, BookingStatus, CreatedAt)
    VALUES (@HostId, 'Test Property Fix', 'Standard', 100.00, 'Test City', 'active', 'not booked', GETUTCDATE());
    
    DECLARE @PropertyId INT = SCOPE_IDENTITY();
    PRINT '? Created test property with ID: ' + CAST(@PropertyId AS VARCHAR);
END
ELSE
BEGIN
    SELECT @PropertyId = Id FROM Properties WHERE HostId = @HostId AND Name = 'Test Property Fix';
    PRINT '? Using existing test property with ID: ' + CAST(@PropertyId AS VARCHAR);
END

-- Create a test booking
IF NOT EXISTS (SELECT 1 FROM Bookings WHERE CustomerId = @CustomerId AND PropertyId = @PropertyId)
BEGIN
    INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
    VALUES (@CustomerId, @PropertyId, DATEADD(day, -10, GETUTCDATE()), DATEADD(day, -7, GETUTCDATE()), 2, 300.00, 'completed', 'paid', DATEADD(day, -15, GETUTCDATE()));
    
    PRINT '? Created test booking';
END
ELSE
BEGIN
    PRINT '? Test booking already exists';
END

-- Test the query that the API uses
PRINT '';
PRINT '?? TESTING API QUERY:';
PRINT '=====================';

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
WHERE prop.HostId = @HostId AND u.Role = 'Customer'
GROUP BY u.Id, u.FullName, u.Email, u.Phone, c.Rating
ORDER BY MAX(b.CreatedAt) DESC;

-- Test the summary query
SELECT 
    COUNT(DISTINCT u.Id) AS TotalCustomers,
    'Summary for Host ID: ' + CAST(@HostId AS VARCHAR) as HostInfo
FROM Users u
INNER JOIN Bookings b ON u.Id = b.CustomerId
INNER JOIN Properties prop ON b.PropertyId = prop.Id
WHERE prop.HostId = @HostId AND u.Role = 'Customer';

PRINT '';
PRINT '?? TEST CREDENTIALS:';
PRINT '====================';
PRINT 'Host Email: test.host@fix.com';
PRINT 'Host ID: ' + CAST(@HostId AS VARCHAR);
PRINT '';
PRINT 'API URL to test: GET /api/Customers/host/' + CAST(@HostId AS VARCHAR);
PRINT 'Summary URL: GET /api/Customers/host/' + CAST(@HostId AS VARCHAR) + '/summary';
PRINT 'Test URL: GET /api/Customers/test';
PRINT '';
PRINT '? Quick fix complete! Try the host customers section again.';