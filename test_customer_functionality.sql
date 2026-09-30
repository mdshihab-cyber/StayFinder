-- Test script to verify Customer functionality
-- Updated to work with actual Customers table structure (Id is both PK and FK)

-- 1. Check current state of all tables
SELECT 'Current Users:' as Info;
SELECT Id, Role, FullName, Email, CreatedAt FROM Users ORDER BY Id;

SELECT 'Current Customers:' as Info;
SELECT c.Id as CustomerTableId, u.FullName, c.Rating, c.SavedProperties 
FROM Customers c
JOIN Users u ON c.Id = u.Id
ORDER BY c.Id;

SELECT 'Current Hosts:' as Info;
SELECT h.HostId, h.UserId, u.FullName, h.Bio, h.Rating, h.NumberOfProperties 
FROM Hosts h
JOIN Users u ON h.UserId = u.Id
ORDER BY h.HostId;

SELECT 'Current Properties:' as Info;
SELECT p.Id, p.HostId, u.FullName as HostName, p.Name, p.Type, p.PricePerDay, 
       p.Location, p.Status, p.BookingStatus, p.CreatedAt
FROM Properties p
JOIN Users u ON p.HostId = u.Id
ORDER BY p.Id;

-- 2. Test query to check Customer users without Customer records
SELECT 'Customer users without Customer records:' as Info;
SELECT u.Id, u.FullName, u.Email, u.Role
FROM Users u
LEFT JOIN Customers c ON u.Id = c.Id
WHERE u.Role = 'Customer' AND c.Id IS NULL;

-- 3. Test saved properties functionality
SELECT 'Sample saved properties test:' as Info;
-- This shows how saved properties are stored as JSON
SELECT c.Id, u.FullName, c.SavedProperties,
       CASE 
           WHEN c.SavedProperties = '[]' OR c.SavedProperties IS NULL THEN 'No saved properties'
           ELSE 'Has saved properties'
       END as Status
FROM Customers c
JOIN Users u ON c.Id = u.Id;

-- 4. Summary statistics
SELECT 'Summary Statistics:' as Info;
SELECT 
    (SELECT COUNT(*) FROM Users WHERE Role = 'Customer') as TotalCustomers,
    (SELECT COUNT(*) FROM Users WHERE Role = 'Host') as TotalHosts,
    (SELECT COUNT(*) FROM Properties) as TotalProperties,
    (SELECT COUNT(*) FROM Customers) as CustomerRecords,
    (SELECT COUNT(*) FROM Hosts) as HostRecords;