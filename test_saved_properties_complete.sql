-- ============================================
-- Complete Test for Saved Properties Frontend
-- ============================================

-- First, let's check if we have the required tables and data
SELECT 'Checking Tables...' as Status;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME IN ('Users', 'Customers', 'Properties', 'CustomerSavedProperties')
ORDER BY TABLE_NAME;

-- Check if we have any users
SELECT 'Checking Users...' as Status;
SELECT Id, FullName, Email, Role FROM Users WHERE Role = 'Customer';

-- Check if we have any properties
SELECT 'Checking Properties...' as Status;
SELECT Id, Name, Type, PricePerDay, Location, Status FROM Properties;

-- If no data exists, let's create some test data
-- Insert a test customer if none exists
IF NOT EXISTS (SELECT 1 FROM Users WHERE Role = 'Customer')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('John Doe Customer', 'customer@test.com', 'hashedpassword123', 'Customer', '123-456-7890', GETUTCDATE());
    
    DECLARE @CustomerId INT = SCOPE_IDENTITY();
    
    -- Insert customer record
    INSERT INTO Customers (Id, Rating, SavedProperties)
    VALUES (@CustomerId, 4.5, '[]');
    
    PRINT 'Created test customer with ID: ' + CAST(@CustomerId AS VARCHAR);
END

-- Insert test host if none exists  
IF NOT EXISTS (SELECT 1 FROM Users WHERE Role = 'Host')
BEGIN
    INSERT INTO Users (FullName, Email, PasswordHash, Role, Phone, CreatedAt)
    VALUES ('Jane Doe Host', 'host@test.com', 'hashedpassword123', 'Host', '098-765-4321', GETUTCDATE());
    
    DECLARE @HostId INT = SCOPE_IDENTITY();
    
    -- Insert host record
    INSERT INTO Hosts (Id, Bio)
    VALUES (@HostId, 'Experienced host with great properties');
    
    PRINT 'Created test host with ID: ' + CAST(@HostId AS VARCHAR);
END

-- Insert test properties if none exist
IF NOT EXISTS (SELECT 1 FROM Properties)
BEGIN
    DECLARE @TestHostId INT = (SELECT TOP 1 Id FROM Users WHERE Role = 'Host');
    
    INSERT INTO Properties (HostId, Name, Type, PricePerDay, Location, ImageUrl, Description, Status, BookingStatus, CreatedAt)
    VALUES 
    (@TestHostId, 'Luxury Downtown Apartment', 'Luxury', 250.00, 'Downtown Manhattan, NY', 
     'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Beautiful luxury apartment in the heart of downtown with stunning city views and modern amenities.', 'active', 'not booked', GETUTCDATE()),
     
    (@TestHostId, 'Cozy Beach House', 'Premium', 180.00, 'Miami Beach, FL', 
     'https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?ixlib=rb-4.0.3&auto=format&fit=crop&w=2340&q=80', 
     'Charming beach house with direct ocean access and breathtaking sunset views.', 'active', 'not booked', GETUTCDATE()),
     
    (@TestHostId, 'Modern Studio', 'Standard', 85.00, 'Arts District, LA', 
     'https://images.unsplash.com/photo-1484154218962-a197022b5858?ixlib=rb-4.0.3&auto=format&fit=crop&w=2274&q=80', 
     'Clean and modern studio apartment perfect for solo travelers or couples.', 'active', 'not booked', GETUTCDATE());
     
    PRINT 'Created test properties';
END

-- Now let's create some saved properties for testing
DECLARE @TestCustomerId INT = (SELECT TOP 1 Id FROM Users WHERE Role = 'Customer');
DECLARE @Property1Id INT = (SELECT TOP 1 Id FROM Properties WHERE Type = 'Luxury');
DECLARE @Property2Id INT = (SELECT TOP 1 Id FROM Properties WHERE Type = 'Premium');

-- Clear existing saved properties for clean test
DELETE FROM CustomerSavedProperties WHERE CustomerId = @TestCustomerId;

-- Add some saved properties
INSERT INTO CustomerSavedProperties (CustomerId, PropertyId, CreatedAt)
VALUES 
(@TestCustomerId, @Property1Id, DATEADD(day, -3, GETUTCDATE())),
(@TestCustomerId, @Property2Id, DATEADD(day, -1, GETUTCDATE()));

PRINT 'Created test saved properties';

-- Test the API query that the frontend will use
SELECT 'Testing API Query...' as Status;
SELECT 
    csp.Id,
    csp.PropertyId,
    csp.CreatedAt,
    p.Name,
    p.PricePerDay,
    p.Location,
    p.ImageUrl,
    p.Type,
    p.Status
FROM CustomerSavedProperties csp
INNER JOIN Properties p ON csp.PropertyId = p.Id
WHERE csp.CustomerId = @TestCustomerId
ORDER BY csp.CreatedAt DESC;

-- Display test customer info for login
SELECT 'Test Customer Login Info:' as Info;
SELECT 
    Id,
    FullName,
    Email,
    'Use any password (authentication is basic)' as Password,
    Role
FROM Users 
WHERE Role = 'Customer';

-- Verify the saved properties table structure
SELECT 'CustomerSavedProperties Table Structure:' as Info;
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'CustomerSavedProperties'
ORDER BY ORDINAL_POSITION;

PRINT '? Test setup complete!';
PRINT 'You can now:';
PRINT '1. Login with the customer credentials shown above';
PRINT '2. Navigate to the Saved Properties tab';
PRINT '3. You should see the saved properties displayed';