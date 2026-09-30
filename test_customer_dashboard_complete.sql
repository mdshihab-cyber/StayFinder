-- Quick Test Script for Customer Dashboard
-- Run this script to set up test data and verify the customer.html functionality

PRINT '?? Setting up test data for Customer Dashboard...';

-- Create test customer if not exists
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'customer@test.com')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Test Customer', 'customer@test.com', 'hashedpassword123', 'Customer', '123-456-7890', GETUTCDATE());
    
    DECLARE @CustomerId INT = SCOPE_IDENTITY();
    
    INSERT INTO Customers (Id, Rating, SavedProperties)
    VALUES (@CustomerId, 4.5, '[]');
    
    PRINT '? Created test customer with ID: ' + CAST(@CustomerId AS VARCHAR);
END

-- Create test host if not exists
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'host@test.com')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Test Host', 'host@test.com', 'hashedpassword123', 'Host', '987-654-3210', GETUTCDATE());
    
    DECLARE @HostId INT = SCOPE_IDENTITY();
    
    INSERT INTO Hosts (Id, Bio)
    VALUES (@HostId, 'Professional host with amazing properties');
    
    PRINT '? Created test host with ID: ' + CAST(@HostId AS VARCHAR);
END

-- Create test properties if not enough exist
DECLARE @PropertyCount INT = (SELECT COUNT(*) FROM Properties);
IF @PropertyCount < 3
BEGIN
    DECLARE @TestHostId INT = (SELECT TOP 1 Id FROM Users WHERE Role = 'Host');
    
    -- Clear existing properties for clean test
    DELETE FROM CustomerSavedProperties;
    DELETE FROM Properties;
    
    INSERT INTO Properties (HostId, Name, Type, PricePerDay, Location, ImageUrl, Description, Status, BookingStatus, CreatedAt)
    VALUES 
    (@TestHostId, 'Luxury Beach Villa', 'Luxury', 350.00, 'Malibu, CA', 
     'https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Stunning oceanfront villa with private beach access, infinity pool, and panoramic ocean views.', 'active', 'not booked', GETUTCDATE()),
     
    (@TestHostId, 'Downtown Loft', 'Premium', 180.00, 'New York, NY', 
     'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Modern loft in the heart of Manhattan with exposed brick walls and city views.', 'active', 'not booked', GETUTCDATE()),
     
    (@TestHostId, 'Cozy Mountain Cabin', 'Standard', 95.00, 'Aspen, CO', 
     'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Rustic cabin nestled in the mountains, perfect for a peaceful getaway.', 'active', 'not booked', GETUTCDATE()),
     
    (@TestHostId, 'City Center Apartment', 'Premium', 220.00, 'San Francisco, CA', 
     'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Elegant apartment in downtown SF with modern amenities and great location.', 'active', 'not booked', GETUTCDATE());
     
    PRINT '? Created test properties';
END

-- Create saved properties for testing
DECLARE @TestCustomerId INT = (SELECT TOP 1 Id FROM Users WHERE Role = 'Customer');
DECLARE @Property1Id INT = (SELECT TOP 1 Id FROM Properties WHERE Type = 'Luxury');
DECLARE @Property2Id INT = (SELECT TOP 1 Id FROM Properties WHERE Type = 'Premium');

-- Clear existing saved properties
DELETE FROM CustomerSavedProperties WHERE CustomerId = @TestCustomerId;

-- Add saved properties
INSERT INTO CustomerSavedProperties (CustomerId, PropertyId, CreatedAt)
VALUES 
(@TestCustomerId, @Property1Id, DATEADD(day, -5, GETUTCDATE())),
(@TestCustomerId, @Property2Id, DATEADD(day, -2, GETUTCDATE()));

PRINT '? Created saved properties for testing';

-- Create a test booking
IF NOT EXISTS (SELECT 1 FROM Bookings WHERE CustomerId = @TestCustomerId)
BEGIN
    INSERT INTO Bookings (CustomerId, PropertyId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
    VALUES (@TestCustomerId, @Property1Id, 
            DATEADD(day, 7, GETUTCDATE()), 
            DATEADD(day, 10, GETUTCDATE()), 
            2, 1050.00, 'pending', 'initial', GETUTCDATE());
    
    PRINT '? Created test booking';
END

-- Display login credentials
PRINT '';
PRINT '?? TEST LOGIN CREDENTIALS:';
PRINT '==========================';
SELECT 
    'Email: ' + Email + ' | Password: any (basic auth)' as LoginInfo,
    'Role: ' + Role as UserRole,
    'ID: ' + CAST(Id AS VARCHAR) as UserId
FROM Users 
WHERE Role = 'Customer';

-- Verify saved properties API call
PRINT '';
PRINT '?? SAVED PROPERTIES TEST QUERY:';
PRINT '===============================';
SELECT 
    csp.Id as SavedPropertyId,
    csp.PropertyId,
    p.Name as PropertyName,
    p.Type,
    p.PricePerDay,
    p.Location,
    p.Status,
    FORMAT(csp.CreatedAt, 'yyyy-MM-dd') as SavedDate
FROM CustomerSavedProperties csp
INNER JOIN Properties p ON csp.PropertyId = p.Id
WHERE csp.CustomerId = @TestCustomerId
ORDER BY csp.CreatedAt DESC;

PRINT '';
PRINT '? Customer Dashboard Test Setup Complete!';
PRINT '';
PRINT '?? TO TEST:';
PRINT '1. Start the application (dotnet run)';
PRINT '2. Go to register.html and login with the customer credentials above';
PRINT '3. Navigate to customer.html';
PRINT '4. Click on the "SAVED PROPERTIES" tab';
PRINT '5. You should see the saved properties with "View Details" buttons';
PRINT '6. Test the property modal by clicking "View Details"';
PRINT '7. Test other tabs (Profile, Bookings, Payments, Reviews)';