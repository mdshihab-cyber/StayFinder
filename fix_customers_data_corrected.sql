-- ============================================
-- Fixed Quick Fix for Host Customers Issue  
-- ============================================

PRINT '?? QUICK FIX: Creating minimal test data for customers functionality...';

-- Declare variables at the top
DECLARE @HostId INT;
DECLARE @CustomerId INT;
DECLARE @PropertyId INT;

-- Ensure we have a test host
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'test.host@fix.com')
BEGIN
    INSERT INTO Users (FullName, Email, Password, Role, Phone, CreatedAt)
    VALUES ('Test Host Fix', 'test.host@fix.com', 'password123', 'Host', '555-1234', GETUTCDATE());
    
    SET @HostId = SCOPE_IDENTITY();
    
    -- Create host record if Hosts table exists
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Hosts')
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM Hosts WHERE UserId = @HostId)
        BEGIN
            INSERT INTO Hosts (UserId, Bio) VALUES (@HostId, 'Test host for debugging');
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
    INSERT INTO Users (FullName, Email, Password, Role, Phone, CreatedAt)
    VALUES ('Test Customer Fix', 'test.customer@fix.com', 'password123', 'Customer', '555-5678', GETUTCDATE());
    
    SET @CustomerId = SCOPE_IDENTITY();
    
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
    
    SET @PropertyId = SCOPE_IDENTITY();
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

-- Create some test reviews
IF NOT EXISTS (SELECT 1 FROM PropertyReviews WHERE PropertyId = @PropertyId AND CustomerId = @CustomerId)
BEGIN
    INSERT INTO PropertyReviews (PropertyId, CustomerId, Rating, Comment, CreatedAt)
    VALUES (@PropertyId, @CustomerId, 5, 'Excellent property! Great location and clean facilities.', DATEADD(day, -5, GETUTCDATE()));
    
    PRINT '? Created test review';
END

-- Create additional test customers and bookings for better data
DECLARE @Customer2Id INT, @Customer3Id INT;

-- Customer 2
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'customer2@test.com')
BEGIN
    INSERT INTO Users (FullName, Email, Password, Role, Phone, CreatedAt)
    VALUES ('Jane Smith', 'customer2@test.com', 'password123', 'Customer', '555-9999', DATEADD(day, -30, GETUTCDATE()));
    
    SET @Customer2Id = SCOPE_IDENTITY();
    INSERT INTO Customers (Id, Rating, SavedProperties) VALUES (@Customer2Id, 4.2, '[]');
    
    -- Create booking for customer 2
    INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
    VALUES (@Customer2Id, @PropertyId, DATEADD(day, -20, GETUTCDATE()), DATEADD(day, -17, GETUTCDATE()), 1, 300.00, 'completed', 'paid', DATEADD(day, -25, GETUTCDATE()));
    
    -- Create review for customer 2
    INSERT INTO PropertyReviews (PropertyId, CustomerId, Rating, Comment, CreatedAt)
    VALUES (@PropertyId, @Customer2Id, 4, 'Good property, nice amenities but could be cleaner.', DATEADD(day, -15, GETUTCDATE()));
    
    PRINT '? Created customer 2 with booking and review';
END

-- Customer 3 (repeat customer)
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'customer3@test.com')
BEGIN
    INSERT INTO Users (FullName, Email, Password, Role, Phone, CreatedAt)
    VALUES ('Bob Johnson', 'customer3@test.com', 'password123', 'Customer', '555-7777', DATEADD(day, -60, GETUTCDATE()));
    
    SET @Customer3Id = SCOPE_IDENTITY();
    INSERT INTO Customers (Id, Rating, SavedProperties) VALUES (@Customer3Id, 4.8, '[]');
    
    -- Create multiple bookings for customer 3 (repeat customer)
    INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
    VALUES (@Customer3Id, @PropertyId, DATEADD(day, -40, GETUTCDATE()), DATEADD(day, -37, GETUTCDATE()), 2, 300.00, 'completed', 'paid', DATEADD(day, -45, GETUTCDATE()));
    
    INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
    VALUES (@Customer3Id, @PropertyId, DATEADD(day, -80, GETUTCDATE()), DATEADD(day, -77, GETUTCDATE()), 1, 100.00, 'completed', 'paid', DATEADD(day, -85, GETUTCDATE()));
    
    -- Create reviews for customer 3
    INSERT INTO PropertyReviews (PropertyId, CustomerId, Rating, Comment, CreatedAt)
    VALUES (@PropertyId, @Customer3Id, 5, 'Amazing experience! Will definitely come back again.', DATEADD(day, -35, GETUTCDATE()));
    
    INSERT INTO PropertyReviews (PropertyId, CustomerId, Rating, Comment, CreatedAt)
    VALUES (@PropertyId, @Customer3Id, 4, 'Second stay was good as well. Highly recommended.', DATEADD(day, -75, GETUTCDATE()));
    
    PRINT '? Created customer 3 with multiple bookings and reviews';
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
    COALESCE(AVG(CAST(pr.Rating AS FLOAT)), 0) AS AverageRating,
    MAX(b.CreatedAt) AS LastBookingDate,
    MIN(b.CreatedAt) AS FirstBookingDate
FROM Users u
INNER JOIN Bookings b ON u.Id = b.CustomerId
INNER JOIN Properties prop ON b.PropertyId = prop.Id
LEFT JOIN Customers c ON u.Id = c.Id
LEFT JOIN PropertyReviews pr ON prop.Id = pr.PropertyId AND u.Id = pr.CustomerId
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

-- Test reviews query for host
SELECT 
    pr.Id,
    pr.Rating,
    pr.Comment,
    pr.CreatedAt,
    u.FullName AS CustomerName,
    u.Email AS CustomerEmail,
    p.Name AS PropertyName,
    p.Location AS PropertyLocation
FROM PropertyReviews pr
INNER JOIN Properties p ON pr.PropertyId = p.Id
INNER JOIN Users u ON pr.CustomerId = u.Id
WHERE p.HostId = @HostId
ORDER BY pr.CreatedAt DESC;

PRINT '';
PRINT '?? TEST CREDENTIALS:';
PRINT '====================';
PRINT 'Host Email: test.host@fix.com';
PRINT 'Host ID: ' + CAST(@HostId AS VARCHAR);
PRINT '';
PRINT 'API URLs to test:';
PRINT 'GET /api/Customers/host/' + CAST(@HostId AS VARCHAR);
PRINT 'GET /api/Customers/host/' + CAST(@HostId AS VARCHAR) + '/summary';
PRINT 'GET /api/PropertyReviews/host/' + CAST(@HostId AS VARCHAR);
PRINT '';
PRINT '? Quick fix complete! Try the host customers and reviews sections again.';