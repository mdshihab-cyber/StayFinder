-- ============================================
-- Test Script for Host Customers Functionality
-- ============================================

PRINT '?? Setting up test data for Host Customers...';

-- Create test host if not exists
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'host.customers@test.com')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Test Host Customers', 'host.customers@test.com', 'hashedpassword123', 'Host', '555-0100', GETUTCDATE());
    
    DECLARE @HostId INT = SCOPE_IDENTITY();
    
    INSERT INTO Hosts (Id, Bio)
    VALUES (@HostId, 'Host for testing customer functionality');
    
    PRINT '? Created test host with ID: ' + CAST(@HostId AS VARCHAR);
END
ELSE
BEGIN
    SELECT @HostId = Id FROM Users WHERE Email = 'host.customers@test.com';
    PRINT '? Using existing test host with ID: ' + CAST(@HostId AS VARCHAR);
END

-- Create multiple test customers
-- Customer 1: Repeat customer with multiple bookings
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'customer.repeat@test.com')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Alice Johnson', 'customer.repeat@test.com', 'hashedpassword123', 'Customer', '555-0201', DATEADD(day, -120, GETUTCDATE()));
    
    DECLARE @Customer1Id INT = SCOPE_IDENTITY();
    INSERT INTO Customers (Id, Rating, SavedProperties) VALUES (@Customer1Id, 4.8, '[]');
    PRINT '? Created repeat customer: Alice Johnson';
END
ELSE
BEGIN
    SELECT @Customer1Id = Id FROM Users WHERE Email = 'customer.repeat@test.com';
    PRINT '? Using existing repeat customer: Alice Johnson';
END

-- Customer 2: New customer with one booking
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'customer.new@test.com')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Bob Smith', 'customer.new@test.com', 'hashedpassword123', 'Customer', '555-0202', DATEADD(day, -30, GETUTCDATE()));
    
    DECLARE @Customer2Id INT = SCOPE_IDENTITY();
    INSERT INTO Customers (Id, Rating, SavedProperties) VALUES (@Customer2Id, 4.2, '[]');
    PRINT '? Created new customer: Bob Smith';
END
ELSE
BEGIN
    SELECT @Customer2Id = Id FROM Users WHERE Email = 'customer.new@test.com';
    PRINT '? Using existing new customer: Bob Smith';
END

-- Customer 3: Premium customer with high spending
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'customer.premium@test.com')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Carol Davis', 'customer.premium@test.com', 'hashedpassword123', 'Customer', '555-0203', DATEADD(day, -90, GETUTCDATE()));
    
    DECLARE @Customer3Id INT = SCOPE_IDENTITY();
    INSERT INTO Customers (Id, Rating, SavedProperties) VALUES (@Customer3Id, 4.9, '[]');
    PRINT '? Created premium customer: Carol Davis';
END
ELSE
BEGIN
    SELECT @Customer3Id = Id FROM Users WHERE Email = 'customer.premium@test.com';
    PRINT '? Using existing premium customer: Carol Davis';
END

-- Customer 4: Recent customer
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'customer.recent@test.com')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('David Wilson', 'customer.recent@test.com', 'hashedpassword123', 'Customer', NULL, DATEADD(day, -10, GETUTCDATE()));
    
    DECLARE @Customer4Id INT = SCOPE_IDENTITY();
    INSERT INTO Customers (Id, Rating, SavedProperties) VALUES (@Customer4Id, 4.5, '[]');
    PRINT '? Created recent customer: David Wilson';
END
ELSE
BEGIN
    SELECT @Customer4Id = Id FROM Users WHERE Email = 'customer.recent@test.com';
    PRINT '? Using existing recent customer: David Wilson';
END

-- Create test properties for the host
IF NOT EXISTS (SELECT 1 FROM Properties WHERE HostId = @HostId)
BEGIN
    INSERT INTO Properties (HostId, Name, Type, PricePerDay, Location, ImageUrl, Description, Status, BookingStatus, CreatedAt)
    VALUES 
    (@HostId, 'Luxury Beachfront Villa', 'Luxury', 500.00, 'Malibu, CA', 
     'https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Stunning beachfront villa with private pool and ocean views.', 'active', 'not booked', GETUTCDATE()),
     
    (@HostId, 'Mountain Lodge Retreat', 'Premium', 200.00, 'Aspen, CO', 
     'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Cozy mountain lodge perfect for skiing and relaxation.', 'active', 'not booked', GETUTCDATE()),
     
    (@HostId, 'City Center Penthouse', 'Luxury', 350.00, 'Manhattan, NY', 
     'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Elegant penthouse in the heart of Manhattan with city views.', 'active', 'not booked', GETUTCDATE());
     
    PRINT '? Created test properties';
END

-- Get property IDs
DECLARE @Property1Id INT = (SELECT TOP 1 Id FROM Properties WHERE HostId = @HostId AND Name LIKE '%Villa%');
DECLARE @Property2Id INT = (SELECT TOP 1 Id FROM Properties WHERE HostId = @HostId AND Name LIKE '%Lodge%');
DECLARE @Property3Id INT = (SELECT TOP 1 Id FROM Properties WHERE HostId = @HostId AND Name LIKE '%Penthouse%');

-- Clean up existing test data
DELETE FROM PropertyReviews WHERE BookingId IN (SELECT Id FROM Bookings WHERE PropertyId IN (@Property1Id, @Property2Id, @Property3Id));
DELETE FROM Payments WHERE BookingId IN (SELECT Id FROM Bookings WHERE PropertyId IN (@Property1Id, @Property2Id, @Property3Id));
DELETE FROM Bookings WHERE PropertyId IN (@Property1Id, @Property2Id, @Property3Id);

-- Create bookings for Alice (Repeat Customer) - 3 bookings
-- Booking 1: Completed stay
INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@Customer1Id, @Property1Id, 
        DATEADD(day, -90, GETUTCDATE()), 
        DATEADD(day, -87, GETUTCDATE()), 
        4, 1500.00, 'completed', 'paid', DATEADD(day, -95, GETUTCDATE()));

DECLARE @AliceBooking1 INT = SCOPE_IDENTITY();

-- Booking 2: Another completed stay
INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@Customer1Id, @Property2Id, 
        DATEADD(day, -60, GETUTCDATE()), 
        DATEADD(day, -55, GETUTCDATE()), 
        2, 1000.00, 'completed', 'paid', DATEADD(day, -65, GETUTCDATE()));

DECLARE @AliceBooking2 INT = SCOPE_IDENTITY();

-- Booking 3: Recent booking
INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@Customer1Id, @Property3Id, 
        DATEADD(day, -15, GETUTCDATE()), 
        DATEADD(day, -12, GETUTCDATE()), 
        3, 1050.00, 'completed', 'paid', DATEADD(day, -20, GETUTCDATE()));

DECLARE @AliceBooking3 INT = SCOPE_IDENTITY();

-- Create bookings for Bob (New Customer) - 1 booking
INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@Customer2Id, @Property2Id, 
        DATEADD(day, -25, GETUTCDATE()), 
        DATEADD(day, -22, GETUTCDATE()), 
        2, 600.00, 'completed', 'paid', DATEADD(day, -30, GETUTCDATE()));

DECLARE @BobBooking1 INT = SCOPE_IDENTITY();

-- Create bookings for Carol (Premium Customer) - 2 expensive bookings
INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@Customer3Id, @Property1Id, 
        DATEADD(day, -75, GETUTCDATE()), 
        DATEADD(day, -68, GETUTCDATE()), 
        6, 3500.00, 'completed', 'paid', DATEADD(day, -80, GETUTCDATE()));

DECLARE @CarolBooking1 INT = SCOPE_IDENTITY();

INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@Customer3Id, @Property3Id, 
        DATEADD(day, -45, GETUTCDATE()), 
        DATEADD(day, -40, GETUTCDATE()), 
        4, 1750.00, 'completed', 'paid', DATEADD(day, -50, GETUTCDATE()));

DECLARE @CarolBooking2 INT = SCOPE_IDENTITY();

-- Create bookings for David (Recent Customer) - 1 recent booking
INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@Customer4Id, @Property2Id, 
        DATEADD(day, -5, GETUTCDATE()), 
        DATEADD(day, -3, GETUTCDATE()), 
        1, 400.00, 'completed', 'paid', DATEADD(day, -10, GETUTCDATE()));

DECLARE @DavidBooking1 INT = SCOPE_IDENTITY();

-- Add reviews for some bookings to test rating functionality
INSERT INTO PropertyReviews (BookingId, CustomerId, PropertyId, Rating, Comment, CreatedAt)
VALUES 
(@AliceBooking1, @Customer1Id, @Property1Id, 5, 'Amazing beachfront villa! Perfect for family vacation.', DATEADD(day, -85, GETUTCDATE())),
(@AliceBooking2, @Customer1Id, @Property2Id, 4, 'Great mountain retreat, very cozy and well-equipped.', DATEADD(day, -53, GETUTCDATE())),
(@AliceBooking3, @Customer1Id, @Property3Id, 5, 'Stunning penthouse with incredible city views!', DATEADD(day, -10, GETUTCDATE())),
(@BobBooking1, @Customer2Id, @Property2Id, 4, 'Nice lodge, good value for money.', DATEADD(day, -20, GETUTCDATE())),
(@CarolBooking1, @Customer3Id, @Property1Id, 5, 'Exceeded expectations! Luxury at its finest.', DATEADD(day, -66, GETUTCDATE())),
(@CarolBooking2, @Customer3Id, @Property3Id, 5, 'Perfect penthouse for business trip. Highly recommend!', DATEADD(day, -38, GETUTCDATE())),
(@DavidBooking1, @Customer4Id, @Property2Id, 4, 'Good stay, friendly host.', DATEADD(day, -1, GETUTCDATE()));

PRINT '? Created test bookings and reviews';

-- Display test results
PRINT '';
PRINT '?? HOST CUSTOMERS TEST DATA:';
PRINT '============================';

-- Show customer summary
SELECT 
    COUNT(DISTINCT u.Id) AS TotalCustomers,
    COUNT(DISTINCT CASE WHEN customer_bookings.BookingCount > 1 THEN u.Id END) AS RepeatCustomers,
    AVG(CAST(pr_reviews.Rating AS FLOAT)) AS CustomerSatisfaction
FROM Users u
INNER JOIN Customers c ON u.Id = c.Id
INNER JOIN Bookings b ON u.Id = b.CustomerId
INNER JOIN Properties prop ON b.PropertyId = prop.Id
LEFT JOIN PropertyReviews pr_reviews ON b.Id = pr_reviews.BookingId
LEFT JOIN (
    SELECT 
        b_inner.CustomerId,
        COUNT(b_inner.Id) AS BookingCount
    FROM Bookings b_inner
    INNER JOIN Properties prop_inner ON b_inner.PropertyId = prop_inner.Id
    WHERE prop_inner.HostId = @HostId
    GROUP BY b_inner.CustomerId
) customer_bookings ON u.Id = customer_bookings.CustomerId
WHERE prop.HostId = @HostId;

-- Show individual customers
SELECT 
    u.FullName AS CustomerName,
    u.Email AS CustomerEmail,
    u.Phone AS CustomerPhone,
    COUNT(b.Id) AS TotalBookings,
    SUM(b.TotalPrice) AS TotalSpent,
    AVG(CAST(pr_reviews.Rating AS FLOAT)) AS AverageRating,
    MAX(b.CreatedAt) AS LastBookingDate
FROM Users u
INNER JOIN Customers c ON u.Id = c.Id
INNER JOIN Bookings b ON u.Id = b.CustomerId
INNER JOIN Properties prop ON b.PropertyId = prop.Id
LEFT JOIN PropertyReviews pr_reviews ON b.Id = pr_reviews.BookingId
WHERE prop.HostId = @HostId
GROUP BY u.Id, u.FullName, u.Email, u.Phone
ORDER BY MAX(b.CreatedAt) DESC;

-- Display login credentials
PRINT '';
PRINT '?? TEST HOST LOGIN CREDENTIALS:';
PRINT '===============================';
SELECT 
    'Email: ' + Email + ' | Password: any (basic auth)' as LoginInfo,
    'Role: ' + Role as UserRole,
    'ID: ' + CAST(Id AS VARCHAR) as UserId
FROM Users 
WHERE Email = 'host.customers@test.com';

PRINT '';
PRINT '? Host Customers Test Setup Complete!';
PRINT '';
PRINT '?? TO TEST:';
PRINT '1. Start the application (dotnet run)';
PRINT '2. Go to register.html and login with the host credentials above';
PRINT '3. Navigate to host.html';
PRINT '4. Click on the "Customers" section in the sidebar';
PRINT '5. You should see customer summary cards and customer table populated';
PRINT '6. Test the search functionality by typing customer names';
PRINT '7. Test customer action buttons (view details, contact)';
PRINT '';
PRINT '?? TEST CUSTOMERS CREATED:';
PRINT 'Alice Johnson - Repeat customer (3 bookings, $3550 spent)';
PRINT 'Bob Smith - New customer (1 booking, $600 spent)';  
PRINT 'Carol Davis - Premium customer (2 bookings, $5250 spent)';
PRINT 'David Wilson - Recent customer (1 booking, $400 spent)';