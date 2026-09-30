-- ============================================
-- Test Script for Host Earnings Functionality
-- ============================================

PRINT '?? Setting up test data for Host Earnings...';

-- Create test host if not exists
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'host.earnings@test.com')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Test Host Earnings', 'host.earnings@test.com', 'hashedpassword123', 'Host', '555-0123', GETUTCDATE());
    
    DECLARE @HostId INT = SCOPE_IDENTITY();
    
    INSERT INTO Hosts (Id, Bio)
    VALUES (@HostId, 'Host for testing earnings functionality');
    
    PRINT '? Created test host with ID: ' + CAST(@HostId AS VARCHAR);
END
ELSE
BEGIN
    SELECT @HostId = Id FROM Users WHERE Email = 'host.earnings@test.com';
    PRINT '? Using existing test host with ID: ' + CAST(@HostId AS VARCHAR);
END

-- Create test customers
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'customer1.earnings@test.com')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Customer One', 'customer1.earnings@test.com', 'hashedpassword123', 'Customer', '555-0201', GETUTCDATE());
    
    DECLARE @Customer1Id INT = SCOPE_IDENTITY();
    INSERT INTO Customers (Id, Rating, SavedProperties) VALUES (@Customer1Id, 4.5, '[]');
    
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Customer Two', 'customer2.earnings@test.com', 'hashedpassword123', 'Customer', '555-0202', GETUTCDATE());
    
    DECLARE @Customer2Id INT = SCOPE_IDENTITY();
    INSERT INTO Customers (Id, Rating, SavedProperties) VALUES (@Customer2Id, 4.8, '[]');
    
    PRINT '? Created test customers';
END
ELSE
BEGIN
    SELECT @Customer1Id = Id FROM Users WHERE Email = 'customer1.earnings@test.com';
    SELECT @Customer2Id = Id FROM Users WHERE Email = 'customer2.earnings@test.com';
    PRINT '? Using existing test customers';
END

-- Create test properties for the host
IF NOT EXISTS (SELECT 1 FROM Properties WHERE HostId = @HostId)
BEGIN
    INSERT INTO Properties (HostId, Name, Type, PricePerDay, Location, ImageUrl, Description, Status, BookingStatus, CreatedAt)
    VALUES 
    (@HostId, 'Luxury Ocean Villa', 'Luxury', 450.00, 'Miami Beach, FL', 
     'https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Beautiful oceanfront villa with private beach access and stunning views.', 'active', 'not booked', GETUTCDATE()),
     
    (@HostId, 'Mountain Retreat Cabin', 'Premium', 180.00, 'Aspen, CO', 
     'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Cozy mountain cabin perfect for a peaceful getaway.', 'active', 'not booked', GETUTCDATE()),
     
    (@HostId, 'Downtown Studio Loft', 'Standard', 120.00, 'Denver, CO', 
     'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Modern studio loft in the heart of downtown.', 'active', 'not booked', GETUTCDATE());
     
    PRINT '? Created test properties';
END

-- Get property IDs
DECLARE @Property1Id INT = (SELECT TOP 1 Id FROM Properties WHERE HostId = @HostId AND Type = 'Luxury');
DECLARE @Property2Id INT = (SELECT TOP 1 Id FROM Properties WHERE HostId = @HostId AND Type = 'Premium');
DECLARE @Property3Id INT = (SELECT TOP 1 Id FROM Properties WHERE HostId = @HostId AND Type = 'Standard');

-- Create test bookings with payments
DELETE FROM Payments WHERE BookingId IN (SELECT Id FROM Bookings WHERE PropertyId IN (@Property1Id, @Property2Id, @Property3Id));
DELETE FROM Bookings WHERE PropertyId IN (@Property1Id, @Property2Id, @Property3Id);

-- Booking 1: Completed booking with full payment
INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@Customer1Id, @Property1Id, 
        DATEADD(day, -30, GETUTCDATE()), 
        DATEADD(day, -27, GETUTCDATE()), 
        4, 1350.00, 'completed', 'paid', DATEADD(day, -35, GETUTCDATE()));

DECLARE @Booking1Id INT = SCOPE_IDENTITY();

-- Initial payment for Booking 1
INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status, PaymentDate)
VALUES (@Booking1Id, @Customer1Id, 1350.00, 135.00, 'Credit Card', 'Initial Booking', 'completed', DATEADD(day, -35, GETUTCDATE()));

-- Remaining payment for Booking 1
INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status, PaymentDate)
VALUES (@Booking1Id, @Customer1Id, 1350.00, 1215.00, 'Credit Card', 'Remaining Payment', 'completed', DATEADD(day, -30, GETUTCDATE()));

-- Booking 2: Current booking with initial payment only
INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@Customer2Id, @Property2Id, 
        DATEADD(day, -15, GETUTCDATE()), 
        DATEADD(day, -10, GETUTCDATE()), 
        2, 900.00, 'confirmed', 'initial', DATEADD(day, -20, GETUTCDATE()));

DECLARE @Booking2Id INT = SCOPE_IDENTITY();

-- Initial payment for Booking 2
INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status, PaymentDate)
VALUES (@Booking2Id, @Customer2Id, 900.00, 90.00, 'PayPal', 'Initial Booking', 'completed', DATEADD(day, -20, GETUTCDATE()));

-- Booking 3: Recent booking with full payment
INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@Customer1Id, @Property3Id, 
        DATEADD(day, -7, GETUTCDATE()), 
        DATEADD(day, -5, GETUTCDATE()), 
        1, 240.00, 'completed', 'paid', DATEADD(day, -10, GETUTCDATE()));

DECLARE @Booking3Id INT = SCOPE_IDENTITY();

-- Initial payment for Booking 3
INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status, PaymentDate)
VALUES (@Booking3Id, @Customer1Id, 240.00, 24.00, 'Credit Card', 'Initial Booking', 'completed', DATEADD(day, -10, GETUTCDATE()));

-- Remaining payment for Booking 3
INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status, PaymentDate)
VALUES (@Booking3Id, @Customer1Id, 240.00, 216.00, 'Credit Card', 'Remaining Payment', 'completed', DATEADD(day, -7, GETUTCDATE()));

-- Booking 4: This month booking for monthly earnings test
INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@Customer2Id, @Property2Id, 
        DATEADD(day, -3, GETUTCDATE()), 
        DATEADD(day, -1, GETUTCDATE()), 
        3, 360.00, 'completed', 'paid', DATEADD(day, -5, GETUTCDATE()));

DECLARE @Booking4Id INT = SCOPE_IDENTITY();

-- Payments for Booking 4
INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status, PaymentDate)
VALUES (@Booking4Id, @Customer2Id, 360.00, 36.00, 'Credit Card', 'Initial Booking', 'completed', DATEADD(day, -5, GETUTCDATE()));

INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status, PaymentDate)
VALUES (@Booking4Id, @Customer2Id, 360.00, 324.00, 'Credit Card', 'Remaining Payment', 'completed', DATEADD(day, -3, GETUTCDATE()));

PRINT '? Created test bookings and payments';

-- Display test results
PRINT '';
PRINT '?? HOST EARNINGS TEST DATA:';
PRINT '============================';

-- Show summary
SELECT 
    COUNT(*) AS TotalTransactions,
    SUM(p.AmountPaid) AS TotalPaymentsReceived,
    SUM(p.AmountPaid * 0.10) AS TotalCommission,
    SUM(p.AmountPaid * 0.90) AS TotalHostEarnings,
    AVG(p.AmountPaid * 0.90) AS AvgEarningPerTransaction
FROM Payments p
JOIN Bookings b ON p.BookingId = b.Id
JOIN Properties pr ON b.PropertyId = pr.Id
WHERE pr.HostId = @HostId AND p.Status = 'completed';

-- Show individual transactions
SELECT 
    p.PaymentDate,
    pr.Name AS PropertyName,
    u.FullName AS CustomerName,
    p.AmountPaid AS Amount,
    (p.AmountPaid * 0.10) AS Commission,
    (p.AmountPaid * 0.90) AS HostEarning,
    p.PaymentType,
    p.Status
FROM Payments p
JOIN Bookings b ON p.BookingId = b.Id
JOIN Properties pr ON b.PropertyId = pr.Id
JOIN Users u ON p.CustomerId = u.Id
WHERE pr.HostId = @HostId AND p.Status = 'completed'
ORDER BY p.PaymentDate DESC;

-- Display login credentials
PRINT '';
PRINT '?? TEST HOST LOGIN CREDENTIALS:';
PRINT '===============================';
SELECT 
    'Email: ' + Email + ' | Password: any (basic auth)' as LoginInfo,
    'Role: ' + Role as UserRole,
    'ID: ' + CAST(Id AS VARCHAR) as UserId
FROM Users 
WHERE Email = 'host.earnings@test.com';

PRINT '';
PRINT '? Host Earnings Test Setup Complete!';
PRINT '';
PRINT '?? TO TEST:';
PRINT '1. Start the application (dotnet run)';
PRINT '2. Go to register.html and login with the host credentials above';
PRINT '3. Navigate to host.html';
PRINT '4. Click on the "Earnings" section in the sidebar';
PRINT '5. You should see earnings summary cards and transaction table populated';
PRINT '6. Test the refresh button to reload data';