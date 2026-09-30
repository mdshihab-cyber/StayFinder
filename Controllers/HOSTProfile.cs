using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using StayFinder_Web_API.Models;

namespace StayFinder_Web_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class HOSTProfile : ControllerBase
    {
        private readonly string connectionString =
            "Server=DESKTOP-7VNIMVI\\SQLEXPRESS;Database=StayFinderWebApiDB;Trusted_Connection=True;Encrypt=False;";

        [HttpGet("{id}")]
        public IActionResult GetUser(int id)
        {
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();

                // Get user info
                var cmd = new SqlCommand(
                    "SELECT FullName, Email, Phone, Role FROM Users WHERE Id=@Id",
                    conn
                );
                cmd.Parameters.AddWithValue("@Id", id);

                string fullName = "", email = "", phone = "", role = "", bio = "";

                using (var reader = cmd.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        fullName = reader["FullName"].ToString();
                        email = reader["Email"].ToString();
                        phone = reader["Phone"].ToString();
                        role = reader["Role"].ToString();
                    }
                    else
                    {
                        return NotFound(new { message = "User not found" });
                    }
                }

                // Get host bio if user is a host
                if (role.Equals("Host", StringComparison.OrdinalIgnoreCase))
                {
                    var hostCmd = new SqlCommand(
                        "SELECT Bio FROM Hosts WHERE UserId=@UserId",
                        conn
                    );
                    hostCmd.Parameters.AddWithValue("@UserId", id);

                    using (var reader = hostCmd.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            bio = reader["Bio"]?.ToString() ?? "";
                        }
                        // If no host record exists, we'll create one during update
                    }
                }

                return Ok(new { fullName, email, phone, role, bio });
            }
        }

        [HttpPut("{id}")]
        public IActionResult UpdateUserProfile(int id, [FromBody] UserProfileUpdateRequest req)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                using (var transaction = conn.BeginTransaction())
                {
                    try
                    {
                        // Check if user exists
                        var checkCmd = new SqlCommand("SELECT Role FROM Users WHERE Id=@Id", conn, transaction);
                        checkCmd.Parameters.AddWithValue("@Id", id);

                        string role = checkCmd.ExecuteScalar()?.ToString();
                        if (role == null)
                            return NotFound(new { message = "User not found" });

                        // Update basic user info
                        var updateUserCmd = new SqlCommand(@"
                            UPDATE Users 
                            SET FullName = @FullName, 
                                Email = @Email, 
                                Phone = @Phone 
                            WHERE Id = @Id", conn, transaction);

                        updateUserCmd.Parameters.AddWithValue("@Id", id);
                        updateUserCmd.Parameters.AddWithValue("@FullName", req.FullName ?? "");
                        updateUserCmd.Parameters.AddWithValue("@Email", req.Email ?? "");
                        updateUserCmd.Parameters.AddWithValue("@Phone", req.Phone ?? "");
                        updateUserCmd.ExecuteNonQuery();

                        // Handle host bio if user is a host
                        if (role.Equals("Host", StringComparison.OrdinalIgnoreCase))
                        {
                            // Check if host record exists
                            var checkHostCmd = new SqlCommand("SELECT COUNT(*) FROM Hosts WHERE UserId=@UserId", conn, transaction);
                            checkHostCmd.Parameters.AddWithValue("@UserId", id);
                            int hostExists = (int)checkHostCmd.ExecuteScalar();

                            if (hostExists > 0)
                            {
                                // Update existing host record
                                var updateHostCmd = new SqlCommand(@"
                                    UPDATE Hosts
                                    SET Bio = @Bio
                                    WHERE UserId = @UserId", conn, transaction);

                                updateHostCmd.Parameters.AddWithValue("@UserId", id);
                                updateHostCmd.Parameters.AddWithValue("@Bio", req.Bio ?? "");
                                updateHostCmd.ExecuteNonQuery();
                            }
                            else
                            {
                                // Create new host record (for existing users who became hosts)
                                var insertHostCmd = new SqlCommand(@"
                                    INSERT INTO Hosts (UserId, Bio, Rating, NumberOfProperties)
                                    VALUES (@UserId, @Bio, @Rating, @NumberOfProperties)", conn, transaction);

                                insertHostCmd.Parameters.AddWithValue("@UserId", id);
                                insertHostCmd.Parameters.AddWithValue("@Bio", req.Bio ?? "");
                                insertHostCmd.Parameters.AddWithValue("@Rating", 0.00);
                                insertHostCmd.Parameters.AddWithValue("@NumberOfProperties", 0);
                                insertHostCmd.ExecuteNonQuery();
                            }
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
            }
        }
    }
}
