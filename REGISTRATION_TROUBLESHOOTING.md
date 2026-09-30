# StayFinder Registration Troubleshooting Guide

## Issues Fixed & Diagnostic Steps

### 1. **IMMEDIATE TESTING STEPS**

#### Test API Connection:
1. **Run the application** and go to the registration page
2. **Click "Test API Connection"** button - this will verify:
   - API is running
   - Database connection works
   - Basic endpoint functionality

#### Check Browser Console:
1. **Open Developer Tools** (F12)
2. **Go to Console tab**
3. **Try to register** - look for error messages
4. **Check Network tab** - verify API requests are being made

### 2. **COMMON ISSUES & SOLUTIONS**

#### Issue: Database Connection
**Symptoms:**
- "Database connection failed" error
- API test returns 500 error

**Solutions:**
1. **Verify SQL Server is running**
2. **Check connection string** in Program.cs matches your SQL Server
3. **Run database_setup.sql** to ensure tables exist
4. **Test connection manually** using SQL Management Studio

#### Issue: Missing Tables
**Symptoms:**
- "Invalid object name 'Users'" error
- SQL errors in logs

**Solution:**
```sql
-- Run this in SQL Server Management Studio:
USE StayFinderWebApiDB;

-- Check if tables exist:
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES;

-- If tables don't exist, run the full database_setup.sql script
```

#### Issue: CORS Problems
**Symptoms:**
- Network requests fail in browser
- CORS error in browser console

**Solution:** Already configured in Program.cs with AllowAnyOrigin

#### Issue: Model Validation
**Symptoms:**
- "Validation failed" errors
- Required field errors

**Solution:** Fixed RegisterRequest.cs with proper validation attributes

### 3. **DIAGNOSTIC SCRIPTS**

#### Run these SQL scripts to diagnose issues:

1. **Basic Database Check:**
```sql
-- Check if database exists and tables are accessible
SELECT 'Database: ' + DB_NAME() as Info;
SELECT 'Tables: ' + STRING_AGG(TABLE_NAME, ', ') as Tables 
FROM INFORMATION_SCHEMA.TABLES;
```

2. **Test User Insert:**
```sql
-- Test if basic insert works
BEGIN TRY
    INSERT INTO Users (Role, FullName, Email, Phone, Password, CreatedAt)
    VALUES ('Test', 'Test User', 'test@test.com', '1234567890', 'test123', GETUTCDATE());
    
    SELECT 'Insert successful' as Result;
    
    -- Clean up
    DELETE FROM Users WHERE Email = 'test@test.com';
END TRY
BEGIN CATCH
    SELECT 'Insert failed: ' + ERROR_MESSAGE() as Result;
END CATCH;
```

### 4. **STEP-BY-STEP TESTING**

#### Frontend Testing:
1. **Open register.html**
2. **Fill in all fields** with test data
3. **Select a role** (Host or Customer)
4. **Click "Test API Connection"** first
5. **If API test passes**, try registration
6. **Check browser console** for any JavaScript errors

#### Backend Testing:
1. **Check application startup** - should show "Database connection successful!"
2. **Test the test endpoint** manually: `GET /api/auth/test`
3. **Try registration** with Postman or similar tool:

```json
POST /api/auth/register
Content-Type: application/json

{
  "role": "Customer",
  "fullName": "Test User",
  "email": "test@example.com",
  "phone": "1234567890",
  "password": "test123",
  "confirmPassword": "test123"
}
```

### 5. **ENHANCED ERROR HANDLING**

The updated code now provides:
- **Detailed error messages** in browser console
- **Visual error panels** on the registration form
- **API test button** to verify connectivity
- **Comprehensive logging** in the backend
- **Better validation messages**

### 6. **LOG LOCATIONS**

**Backend Logs:**
- Console output when running the application
- Visual Studio Output window
- IIS Express logs if using IIS

**Frontend Logs:**
- Browser Developer Tools ? Console tab
- Network tab shows API request/response details

### 7. **MANUAL TESTING CHECKLIST**

- [ ] SQL Server is running
- [ ] Database "StayFinderWebApiDB" exists
- [ ] All tables exist (Users, Hosts, Customer, Properties)
- [ ] Application starts without errors
- [ ] "Database connection successful!" message appears
- [ ] Browser can access register.html
- [ ] "Test API Connection" button works
- [ ] Registration form validation works
- [ ] Registration completes successfully
- [ ] User record appears in database

### 8. **QUICK FIX COMMANDS**

If you need to reset everything:

```sql
-- Drop all tables and recreate
USE StayFinderWebApiDB;
DROP TABLE IF EXISTS Properties;
DROP TABLE IF EXISTS Customer;  
DROP TABLE IF EXISTS Hosts;
DROP TABLE IF EXISTS Users;

-- Then run the full database_setup.sql script
```

### 9. **SUPPORT INFORMATION**

The registration system now includes:
- ? **Proper validation** on both client and server
- ? **Detailed error messages** for debugging
- ? **Database connection testing**
- ? **Transaction safety** for data integrity
- ? **Role-based record creation** (Host/Customer)
- ? **Enhanced logging** for troubleshooting

Try the registration now and use the "Test API Connection" button to verify everything is working!