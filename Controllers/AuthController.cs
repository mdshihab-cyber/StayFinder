using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using StayFinder_Web_API.Models;

namespace StayFinder_Web_API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly string connectionString = "Server=DESKTOP-7VNIMVI\\SQLEXPRESS;Database=StayFinderWebApiDB;Trusted_Connection=True;Encrypt=False;";
        private readonly ILogger<AuthController> _logger;

        public AuthController(ILogger<AuthController> logger)
        {
            _logger = logger;
        }

        [HttpPost("register")]
        public IActionResult Register([FromBody] RegisterRequest req)
        {
            try
            {
                _logger.LogInformation("Registration attempt for email: {Email}, role: {Role}", req?.Email ?? "null", req?.Role ?? "null");

                // Validate model
                if (!ModelState.IsValid)
                {
                    var errors = ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage);
                    _logger.LogWarning("Registration validation failed: {Errors}", string.Join(", ", errors));
                    return BadRequest(new { message = "Validation failed", errors = errors });
                }

                // Check password match
                if (req.Password != req.ConfirmPassword)
                {
                    _logger.LogWarning("Password mismatch for registration: {Email}", req.Email);
                    return BadRequest(new { message = "Passwords do not match" });
                }

                // Validate role
                if (!req.Role.Equals("Host", StringComparison.OrdinalIgnoreCase) && 
                    !req.Role.Equals("Customer", StringComparison.OrdinalIgnoreCase))
                {
                    _logger.LogWarning("Invalid role specified: {Role}", req.Role);
                    return BadRequest(new { message = "Role must be either 'Host' or 'Customer'" });
                }

                using (var conn = new SqlConnection(connectionString))
                {
                    _logger.LogInformation("Attempting to connect to database");
                    conn.Open();
                    _logger.LogInformation("Database connection successful");
                    
                    using (var transaction = conn.BeginTransaction())
                    {
                        try
                        {
                            // Check for existing email
                            _logger.LogInformation("Checking for existing email: {Email}", req.Email);
                            var checkCmd = new SqlCommand("SELECT COUNT(*) FROM Users WHERE Email=@Email", conn, transaction);
                            checkCmd.Parameters.AddWithValue("@Email", req.Email);
                            int count = (int)checkCmd.ExecuteScalar();

                            if (count > 0)
                            {
                                _logger.LogWarning("Email already exists: {Email}", req.Email);
                                return BadRequest(new { message = "Email already registered" });
                            }

                            // Insert user
                            _logger.LogInformation("Inserting new user: {Email}", req.Email);
                            var insertCmd = new SqlCommand(@"
                            INSERT INTO Users (Role, FullName, Email, Phone, Password, CreatedAt)
                            VALUES (@Role, @FullName, @Email, @Phone, @Password, @CreatedAt);
                            SELECT SCOPE_IDENTITY();", conn, transaction);

                            insertCmd.Parameters.AddWithValue("@Role", req.Role);
                            insertCmd.Parameters.AddWithValue("@FullName", req.FullName);
                            insertCmd.Parameters.AddWithValue("@Email", req.Email);
                            insertCmd.Parameters.AddWithValue("@Phone", req.Phone);
                            insertCmd.Parameters.AddWithValue("@Password", req.Password);
                            insertCmd.Parameters.AddWithValue("@CreatedAt", DateTime.UtcNow);

                            var result = insertCmd.ExecuteScalar();
                            if (result == null || result == DBNull.Value)
                            {
                                throw new Exception("Failed to get new user ID from database");
                            }
                            
                            var userId = Convert.ToInt32(result);
                            _logger.LogInformation("User created with ID: {UserId}", userId);

                            // Create role-specific records
                            if (req.Role.Equals("Host", StringComparison.OrdinalIgnoreCase))
                            {
                                _logger.LogInformation("Creating Host record for user: {UserId}", userId);
                                var hostCmd = new SqlCommand(@"
                                INSERT INTO Hosts (UserId, Bio, Rating, NumberOfProperties)
                                VALUES (@UserId, @Bio, @Rating, @NumberOfProperties)", conn, transaction);

                                hostCmd.Parameters.AddWithValue("@UserId", userId);
                                hostCmd.Parameters.AddWithValue("@Bio", "");
                                hostCmd.Parameters.AddWithValue("@Rating", 0.00);
                                hostCmd.Parameters.AddWithValue("@NumberOfProperties", 0);
                                
                                hostCmd.ExecuteNonQuery();
                                _logger.LogInformation("Host record created successfully for user: {UserId}", userId);
                            }
                            else if (req.Role.Equals("Customer", StringComparison.OrdinalIgnoreCase))
                            {
                                _logger.LogInformation("Creating Customer record for user: {UserId}", userId);
                                // For Customers table, Id is both PK and FK to Users.Id
                                var customerCmd = new SqlCommand(@"
                                INSERT INTO Customers (Id, Rating, SavedProperties)
                                VALUES (@Id, @Rating, @SavedProperties)", conn, transaction);

                                customerCmd.Parameters.AddWithValue("@Id", userId); // Using userId as the Id (PK/FK)
                                customerCmd.Parameters.AddWithValue("@Rating", 0.00);
                                customerCmd.Parameters.AddWithValue("@SavedProperties", "[]");
                                
                                customerCmd.ExecuteNonQuery();
                                _logger.LogInformation("Customer record created successfully for user: {UserId}", userId);
                            }

                            transaction.Commit();
                            _logger.LogInformation("Registration completed successfully for user: {UserId}, email: {Email}", userId, req.Email);
                            
                            return Created("", new { 
                                message = "User registered successfully", 
                                userId = userId,
                                role = req.Role,
                                fullName = req.FullName,
                                email = req.Email
                            });
                        }
                        catch (Exception ex)
                        {
                            transaction.Rollback();
                            _logger.LogError(ex, "Error during registration transaction for email: {Email}", req.Email);
                            throw;
                        }
                    }
                }
            }
            catch (SqlException sqlEx)
            {
                _logger.LogError(sqlEx, "Database error during registration for email: {Email}", req?.Email ?? "null");
                return StatusCode(500, new { 
                    message = "Database error during registration", 
                    error = sqlEx.Message,
                    sqlErrorNumber = sqlEx.Number
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error during registration for email: {Email}", req?.Email ?? "null");
                return StatusCode(500, new { 
                    message = "Registration failed due to an unexpected error", 
                    error = ex.Message 
                });
            }
        }

        [HttpPost("login")]
        public IActionResult Login([FromBody] LoginRequest req)
        {
            try
            {
                _logger.LogInformation("Login attempt for email: {Email}", req?.Email ?? "null");

                if (!ModelState.IsValid)
                {
                    var errors = ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage);
                    _logger.LogWarning("Login validation failed: {Errors}", string.Join(", ", errors));
                    return BadRequest(new { message = "Validation failed", errors = errors });
                }

                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();

                    var cmd = new SqlCommand(@"
                        SELECT Id, Role, FullName, Email, Phone, CreatedAt 
                        FROM Users 
                        WHERE Email = @Email AND Password = @Password", conn);
                    
                    cmd.Parameters.AddWithValue("@Email", req.Email);
                    cmd.Parameters.AddWithValue("@Password", req.Password);

                    using (var reader = cmd.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            var user = new
                            {
                                id = reader["Id"].ToString(),
                                role = reader["Role"].ToString(),
                                fullName = reader["FullName"].ToString(),
                                email = reader["Email"].ToString(),
                                phone = reader["Phone"].ToString(),
                                createdAt = reader["CreatedAt"].ToString()
                            };

                            _logger.LogInformation("Login successful for user: {UserId}, email: {Email}", user.id, req.Email);
                            
                            return Ok(new { 
                                message = "Login successful", 
                                user = user 
                            });
                        }
                    }
                }

                _logger.LogWarning("Login failed - invalid credentials for email: {Email}", req.Email);
                return Unauthorized(new { message = "Invalid email or password" });
            }
            catch (SqlException sqlEx)
            {
                _logger.LogError(sqlEx, "Database error during login for email: {Email}", req?.Email ?? "null");
                return StatusCode(500, new { 
                    message = "Database error during login", 
                    error = sqlEx.Message 
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error during login for email: {Email}", req?.Email ?? "null");
                return StatusCode(500, new { 
                    message = "Login failed due to an unexpected error", 
                    error = ex.Message 
                });
            }
        }

        // Get current user info (validate authentication)
        [HttpGet("me")]
        public IActionResult GetCurrentUser([FromQuery] string userId, [FromQuery] string email)
        {
            try
            {
                _logger.LogInformation("Getting current user info for userId: {UserId}, email: {Email}", userId ?? "null", email ?? "null");

                if (string.IsNullOrEmpty(userId) && string.IsNullOrEmpty(email))
                {
                    return BadRequest(new { message = "UserId or email is required" });
                }

                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();

                    SqlCommand cmd;
                    if (!string.IsNullOrEmpty(userId))
                    {
                        cmd = new SqlCommand(@"
                            SELECT Id, Role, FullName, Email, Phone, CreatedAt 
                            FROM Users 
                            WHERE Id = @Id", conn);
                        cmd.Parameters.AddWithValue("@Id", userId);
                    }
                    else
                    {
                        cmd = new SqlCommand(@"
                            SELECT Id, Role, FullName, Email, Phone, CreatedAt 
                            FROM Users 
                            WHERE Email = @Email", conn);
                        cmd.Parameters.AddWithValue("@Email", email);
                    }

                    using (var reader = cmd.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            var user = new
                            {
                                id = reader["Id"].ToString(),
                                role = reader["Role"].ToString(),
                                fullName = reader["FullName"].ToString(),
                                email = reader["Email"].ToString(),
                                phone = reader["Phone"].ToString(),
                                createdAt = reader["CreatedAt"].ToString()
                            };

                            _logger.LogInformation("Current user info retrieved successfully for user: {UserId}", user.id);
                            
                            return Ok(new { 
                                message = "User info retrieved successfully", 
                                user = user 
                            });
                        }
                    }
                }

                _logger.LogWarning("User not found for userId: {UserId}, email: {Email}", userId, email);
                return NotFound(new { message = "User not found" });
            }
            catch (SqlException sqlEx)
            {
                _logger.LogError(sqlEx, "Database error getting current user for userId: {UserId}, email: {Email}", userId, email);
                return StatusCode(500, new { 
                    message = "Database error retrieving user info", 
                    error = sqlEx.Message 
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error getting current user for userId: {UserId}, email: {Email}", userId, email);
                return StatusCode(500, new { 
                    message = "Failed to retrieve user info due to an unexpected error", 
                    error = ex.Message 
                });
            }
        }

        // Test endpoint to verify API is working
        [HttpGet("test")]
        public IActionResult Test()
        {
            try
            {
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    var cmd = new SqlCommand("SELECT COUNT(*) FROM Users", conn);
                    var userCount = (int)cmd.ExecuteScalar();
                    
                    return Ok(new { 
                        message = "API is working", 
                        userCount = userCount,
                        timestamp = DateTime.UtcNow 
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in test endpoint");
                return StatusCode(500, new { 
                    message = "Database connection failed", 
                    error = ex.Message 
                });
            }
        }
    }
}
