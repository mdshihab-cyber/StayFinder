-- Fix script for existing Customer users who don't have records in Customers table
-- Updated to work with actual Customers table structure (Id is both PK and FK)

-- Insert missing Customer records for existing Customer users
INSERT INTO Customers (Id, Rating, SavedProperties)
SELECT u.Id, 0.00, '[]'
FROM Users u
LEFT JOIN Customers c ON u.Id = c.Id
WHERE u.Role = 'Customer' AND c.Id IS NULL;

-- Verify the fix
SELECT 
    u.Id as UserId,
    u.FullName,
    u.Role,
    c.Id as CustomerTableId,
    c.Rating,
    c.SavedProperties
FROM Users u
LEFT JOIN Customers c ON u.Id = c.Id
WHERE u.Role = 'Customer'
ORDER BY u.Id;