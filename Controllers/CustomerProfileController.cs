using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using StayFinder_Web_API.Models;
using System.Text.Json;

namespace StayFinder_Web_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CustomerProfileController : ControllerBase
    {
        private readonly string connectionString =
            "Server=DESKTOP-7VNIMVI\\SQLEXPRESS;Database=StayFinderWebApiDB;Trusted_Connection=True;Encrypt=False;";

        [HttpGet("{id}")]
        public IActionResult GetCustomer(int id)
        {
            try
            {
                using var conn = new SqlConnection(connectionString);
                conn.Open();

                // Get basic user info
                var cmd = new SqlCommand("SELECT FullName, Email, Phone, Role FROM Users WHERE Id=@Id AND Role='Customer'", conn);
                cmd.Parameters.AddWithValue("@Id", id);

                using var reader = cmd.ExecuteReader();
                if (!reader.Read()) 
                    return NotFound(new { message = "Customer not found" });

                var userData = new
                {
                    fullName = reader["FullName"].ToString(),
                    email = reader["Email"].ToString(),
                    phone = reader["Phone"].ToString(),
                    role = reader["Role"].ToString()
                };
                reader.Close();

                // Get customer-specific data from Customers table (Id is both PK and FK)
                var custCmd = new SqlCommand("SELECT Rating, SavedProperties FROM Customers WHERE Id=@Id", conn);
                custCmd.Parameters.AddWithValue("@Id", id);
                
                using var custReader = custCmd.ExecuteReader();
                if (custReader.Read())
                {
                    var savedPropsJson = custReader["SavedProperties"]?.ToString() ?? "[]";
                    List<int> savedProps;
                    try
                    {
                        savedProps = JsonSerializer.Deserialize<List<int>>(savedPropsJson) ?? new List<int>();
                    }
                    catch
                    {
                        savedProps = new List<int>();
                    }

                    return Ok(new
                    {
                        userData.fullName,
                        userData.email,
                        userData.phone,
                        userData.role,
                        rating = custReader["Rating"],
                        savedProperties = savedProps
                    });
                }

                // If no customer record exists, return default values
                return Ok(new
                {
                    userData.fullName,
                    userData.email,
                    userData.phone,
                    userData.role,
                    rating = 0.0,
                    savedProperties = new List<int>()
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error retrieving customer profile", error = ex.Message });
            }
        }

        [HttpPut("{id}")]
        public IActionResult UpdateCustomerProfile(int id, [FromBody] CustomerProfileUpdateRequest req)
        {
            if (!ModelState.IsValid) 
                return BadRequest(ModelState);

            try
            {
                using var conn = new SqlConnection(connectionString);
                conn.Open();
                using var transaction = conn.BeginTransaction();

                try
                {
                    // Check if user exists and is a customer
                    var checkCmd = new SqlCommand("SELECT Role FROM Users WHERE Id=@Id", conn, transaction);
                    checkCmd.Parameters.AddWithValue("@Id", id);
                    string role = checkCmd.ExecuteScalar()?.ToString();
                    
                    if (role == null)
                        return NotFound(new { message = "User not found" });
                    
                    if (role != "Customer")
                        return BadRequest(new { message = "User is not a customer" });

                    // Update user table
                    var updateUserCmd = new SqlCommand(@"
                        UPDATE Users
                        SET FullName=@FullName, Email=@Email, Phone=@Phone
                        WHERE Id=@Id", conn, transaction);
                    updateUserCmd.Parameters.AddWithValue("@Id", id);
                    updateUserCmd.Parameters.AddWithValue("@FullName", req.FullName ?? "");
                    updateUserCmd.Parameters.AddWithValue("@Email", req.Email ?? "");
                    updateUserCmd.Parameters.AddWithValue("@Phone", req.Phone ?? "");
                    updateUserCmd.ExecuteNonQuery();

                    // Ensure customer record exists in Customers table (Id is both PK and FK)
                    var checkCustomerCmd = new SqlCommand("SELECT COUNT(*) FROM Customers WHERE Id=@Id", conn, transaction);
                    checkCustomerCmd.Parameters.AddWithValue("@Id", id);
                    int customerExists = (int)checkCustomerCmd.ExecuteScalar();

                    if (customerExists == 0)
                    {
                        // Create customer record if it doesn't exist
                        var insertCustomerCmd = new SqlCommand(@"
                            INSERT INTO Customers (Id, Rating, SavedProperties)
                            VALUES (@Id, @Rating, @SavedProperties)", conn, transaction);
                        insertCustomerCmd.Parameters.AddWithValue("@Id", id);
                        insertCustomerCmd.Parameters.AddWithValue("@Rating", 0.0);
                        insertCustomerCmd.Parameters.AddWithValue("@SavedProperties", "[]");
                        insertCustomerCmd.ExecuteNonQuery();
                    }

                    transaction.Commit();
                    return Ok(new { message = "Profile updated successfully" });
                }
                catch (Exception ex)
                {
                    transaction.Rollback();
                    return StatusCode(500, new { message = "Update failed", error = ex.Message });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error updating customer profile", error = ex.Message });
            }
        }

        // Add/Remove saved properties
        [HttpPost("{id}/saved-properties/{propertyId}")]
        public IActionResult AddSavedProperty(int id, int propertyId)
        {
            try
            {
                using var conn = new SqlConnection(connectionString);
                conn.Open();
                using var transaction = conn.BeginTransaction();

                try
                {
                    // Ensure customer record exists
                    EnsureCustomerRecordExists(id, conn, transaction);

                    // Get current saved properties from Customers table (Id is both PK and FK)
                    var getCmd = new SqlCommand("SELECT SavedProperties FROM Customers WHERE Id=@Id", conn, transaction);
                    getCmd.Parameters.AddWithValue("@Id", id);
                    var savedPropsJson = getCmd.ExecuteScalar()?.ToString() ?? "[]";

                    var savedProps = JsonSerializer.Deserialize<List<int>>(savedPropsJson) ?? new List<int>();
                    
                    if (!savedProps.Contains(propertyId))
                    {
                        savedProps.Add(propertyId);
                        var updatedJson = JsonSerializer.Serialize(savedProps);

                        var updateCmd = new SqlCommand("UPDATE Customers SET SavedProperties=@SavedProperties WHERE Id=@Id", conn, transaction);
                        updateCmd.Parameters.AddWithValue("@Id", id);
                        updateCmd.Parameters.AddWithValue("@SavedProperties", updatedJson);
                        updateCmd.ExecuteNonQuery();
                    }

                    transaction.Commit();
                    return Ok(new { message = "Property saved successfully" });
                }
                catch (Exception ex)
                {
                    transaction.Rollback();
                    return StatusCode(500, new { message = "Failed to save property", error = ex.Message });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error saving property", error = ex.Message });
            }
        }

        [HttpDelete("{id}/saved-properties/{propertyId}")]
        public IActionResult RemoveSavedProperty(int id, int propertyId)
        {
            try
            {
                using var conn = new SqlConnection(connectionString);
                conn.Open();
                using var transaction = conn.BeginTransaction();

                try
                {
                    // Get current saved properties from Customers table (Id is both PK and FK)
                    var getCmd = new SqlCommand("SELECT SavedProperties FROM Customers WHERE Id=@Id", conn, transaction);
                    getCmd.Parameters.AddWithValue("@Id", id);
                    var savedPropsJson = getCmd.ExecuteScalar()?.ToString() ?? "[]";

                    var savedProps = JsonSerializer.Deserialize<List<int>>(savedPropsJson) ?? new List<int>();
                    
                    if (savedProps.Contains(propertyId))
                    {
                        savedProps.Remove(propertyId);
                        var updatedJson = JsonSerializer.Serialize(savedProps);

                        var updateCmd = new SqlCommand("UPDATE Customers SET SavedProperties=@SavedProperties WHERE Id=@Id", conn, transaction);
                        updateCmd.Parameters.AddWithValue("@Id", id);
                        updateCmd.Parameters.AddWithValue("@SavedProperties", updatedJson);
                        updateCmd.ExecuteNonQuery();
                    }

                    transaction.Commit();
                    return Ok(new { message = "Property removed successfully" });
                }
                catch (Exception ex)
                {
                    transaction.Rollback();
                    return StatusCode(500, new { message = "Failed to remove property", error = ex.Message });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error removing property", error = ex.Message });
            }
        }

        // Get saved properties with details
        [HttpGet("{id}/saved-properties")]
        public IActionResult GetSavedProperties(int id)
        {
            try
            {
                using var conn = new SqlConnection(connectionString);
                conn.Open();

                // Get saved property IDs from Customers table (Id is both PK and FK)
                var getCmd = new SqlCommand("SELECT SavedProperties FROM Customers WHERE Id=@Id", conn);
                getCmd.Parameters.AddWithValue("@Id", id);
                var savedPropsJson = getCmd.ExecuteScalar()?.ToString() ?? "[]";

                var savedPropIds = JsonSerializer.Deserialize<List<int>>(savedPropsJson) ?? new List<int>();
                
                if (savedPropIds.Count == 0)
                {
                    return Ok(new List<object>());
                }

                // Get property details
                var propIds = string.Join(",", savedPropIds);
                var propCmd = new SqlCommand($@"
                    SELECT p.Id, p.Name, p.Type, p.PricePerDay, p.Location, p.ImageUrl, p.Status,
                           u.FullName as HostName
                    FROM Properties p
                    JOIN Users u ON p.HostId = u.Id
                    WHERE p.Id IN ({propIds})", conn);

                var properties = new List<object>();
                using var reader = propCmd.ExecuteReader();
                while (reader.Read())
                {
                    properties.Add(new
                    {
                        id = reader["Id"],
                        name = reader["Name"].ToString(),
                        type = reader["Type"].ToString(),
                        pricePerDay = reader["PricePerDay"],
                        location = reader["Location"].ToString(),
                        imageUrl = reader["ImageUrl"]?.ToString() ?? "",
                        status = reader["Status"].ToString(),
                        hostName = reader["HostName"].ToString()
                    });
                }

                return Ok(properties);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error retrieving saved properties", error = ex.Message });
            }
        }

        private void EnsureCustomerRecordExists(int userId, SqlConnection conn, SqlTransaction transaction)
        {
            var checkCmd = new SqlCommand("SELECT COUNT(*) FROM Customers WHERE Id=@Id", conn, transaction);
            checkCmd.Parameters.AddWithValue("@Id", userId);
            int exists = (int)checkCmd.ExecuteScalar();

            if (exists == 0)
            {
                var insertCmd = new SqlCommand(@"
                    INSERT INTO Customers (Id, Rating, SavedProperties)
                    VALUES (@Id, @Rating, @SavedProperties)", conn, transaction);
                insertCmd.Parameters.AddWithValue("@Id", userId);
                insertCmd.Parameters.AddWithValue("@Rating", 0.0);
                insertCmd.Parameters.AddWithValue("@SavedProperties", "[]");
                insertCmd.ExecuteNonQuery();
            }
        }
    }
}
