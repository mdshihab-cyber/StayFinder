using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using StayFinder_Web_API.Models;

namespace StayFinder_Web_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PropertyController : ControllerBase
    {
        private readonly string connectionString =
            "Server=DESKTOP-7VNIMVI\\SQLEXPRESS;Database=StayFinderWebApiDB;Trusted_Connection=True;Encrypt=False;";

        // GET all properties (public endpoint for browsing)
        [HttpGet("all")]
        public IActionResult GetAllProperties()
        {
            try
            {
                var properties = new List<object>();
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    var cmd = new SqlCommand(@"
                        SELECT p.Id, p.HostId, p.Name, p.Type, p.PricePerDay, p.Location, p.ImageUrl, 
                               p.Status, p.BookingStatus, p.BookingFrom, p.BookingTo, p.Description, 
                               p.CreatedAt, p.UpdatedAt, u.FullName as HostName
                        FROM Properties p
                        JOIN Users u ON p.HostId = u.Id
                        WHERE p.Status = 'active'
                        ORDER BY p.CreatedAt DESC", conn);

                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            properties.Add(new
                            {
                                id = reader["Id"],
                                hostId = reader["HostId"],
                                name = reader["Name"].ToString(),
                                type = reader["Type"].ToString(),
                                pricePerDay = reader["PricePerDay"],
                                location = reader["Location"].ToString(),
                                imageUrl = reader["ImageUrl"]?.ToString() ?? "",
                                status = reader["Status"].ToString(),
                                bookingStatus = reader["BookingStatus"].ToString(),
                                bookingFrom = reader["BookingFrom"] == DBNull.Value ? null : Convert.ToDateTime(reader["BookingFrom"]).ToString("yyyy-MM-dd"),
                                bookingTo = reader["BookingTo"] == DBNull.Value ? null : Convert.ToDateTime(reader["BookingTo"]).ToString("yyyy-MM-dd"),
                                description = reader["Description"]?.ToString() ?? "",
                                hostName = reader["HostName"].ToString(),
                                createdAt = Convert.ToDateTime(reader["CreatedAt"]).ToString("yyyy-MM-dd HH:mm:ss")
                            });
                        }
                    }
                }
                return Ok(properties);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error retrieving properties", error = ex.Message });
            }
        }

        // GET all properties for a host
        [HttpGet("host/{hostId}")]
        public IActionResult GetPropertiesByHost(int hostId)
        {
            try
            {
                var properties = new List<object>();
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    var cmd = new SqlCommand(@"
                        SELECT Id, HostId, Name, Type, PricePerDay, Location, ImageUrl, 
                               Status, BookingStatus, BookingFrom, BookingTo, Description, CreatedAt, UpdatedAt
                        FROM Properties 
                        WHERE HostId = @HostId 
                        ORDER BY CreatedAt DESC", conn);
                    
                    cmd.Parameters.AddWithValue("@HostId", hostId);

                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            properties.Add(new
                            {
                                id = reader["Id"],
                                hostId = reader["HostId"],
                                name = reader["Name"].ToString(),
                                type = reader["Type"].ToString(),
                                pricePerDay = reader["PricePerDay"],
                                location = reader["Location"].ToString(),
                                imageUrl = reader["ImageUrl"]?.ToString() ?? "",
                                status = reader["Status"].ToString(),
                                bookingStatus = reader["BookingStatus"].ToString(),
                                bookingFrom = reader["BookingFrom"] == DBNull.Value ? null : Convert.ToDateTime(reader["BookingFrom"]).ToString("yyyy-MM-dd"),
                                bookingTo = reader["BookingTo"] == DBNull.Value ? null : Convert.ToDateTime(reader["BookingTo"]).ToString("yyyy-MM-dd"),
                                description = reader["Description"]?.ToString() ?? "",
                                createdAt = Convert.ToDateTime(reader["CreatedAt"]).ToString("yyyy-MM-dd HH:mm:ss")
                            });
                        }
                    }
                }
                return Ok(properties);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error retrieving properties", error = ex.Message });
            }
        }

        // GET single property (enhanced with host information)
        [HttpGet("{id}")]
        public IActionResult GetProperty(int id)
        {
            try
            {
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    var cmd = new SqlCommand(@"
                        SELECT p.Id, p.HostId, p.Name, p.Type, p.PricePerDay, p.Location, p.ImageUrl, 
                               p.Status, p.BookingStatus, p.BookingFrom, p.BookingTo, p.Description, 
                               p.CreatedAt, p.UpdatedAt,
                               u.FullName as HostName, u.Email as HostEmail, u.Phone as HostPhone,
                               h.Bio as HostBio, h.Rating as HostRating
                        FROM Properties p
                        JOIN Users u ON p.HostId = u.Id
                        LEFT JOIN Hosts h ON u.Id = h.UserId
                        WHERE p.Id = @Id", conn);
                    
                    cmd.Parameters.AddWithValue("@Id", id);

                    using (var reader = cmd.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            var property = new
                            {
                                id = reader["Id"],
                                hostId = reader["HostId"],
                                name = reader["Name"].ToString(),
                                type = reader["Type"].ToString(),
                                pricePerDay = reader["PricePerDay"],
                                location = reader["Location"].ToString(),
                                imageUrl = reader["ImageUrl"]?.ToString() ?? "",
                                status = reader["Status"].ToString(),
                                bookingStatus = reader["BookingStatus"].ToString(),
                                bookingFrom = reader["BookingFrom"] == DBNull.Value ? null : Convert.ToDateTime(reader["BookingFrom"]).ToString("yyyy-MM-dd"),
                                bookingTo = reader["BookingTo"] == DBNull.Value ? null : Convert.ToDateTime(reader["BookingTo"]).ToString("yyyy-MM-dd"),
                                description = reader["Description"]?.ToString() ?? "",
                                createdAt = Convert.ToDateTime(reader["CreatedAt"]).ToString("yyyy-MM-dd HH:mm:ss"),
                                // Host information
                                host = new
                                {
                                    name = reader["HostName"].ToString(),
                                    email = reader["HostEmail"].ToString(),
                                    phone = reader["HostPhone"].ToString(),
                                    bio = reader["HostBio"]?.ToString() ?? "",
                                    rating = reader["HostRating"] ?? 0.0
                                }
                            };
                            return Ok(property);
                        }
                    }
                }
                return NotFound(new { message = "Property not found" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error retrieving property", error = ex.Message });
            }
        }

        // POST: Add new property
        [HttpPost]
        public IActionResult AddProperty([FromBody] PropertyRequest req)
        {
            if (!ModelState.IsValid) 
                return BadRequest(ModelState);

            try
            {
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    
                    // Verify the host exists
                    var hostCheckCmd = new SqlCommand("SELECT COUNT(*) FROM Users WHERE Id = @HostId AND Role = 'Host'", conn);
                    hostCheckCmd.Parameters.AddWithValue("@HostId", req.HostId);
                    int hostExists = (int)hostCheckCmd.ExecuteScalar();
                    
                    if (hostExists == 0)
                        return BadRequest(new { message = "Invalid Host ID" });

                    var cmd = new SqlCommand(@"
                        INSERT INTO Properties (HostId, Name, Type, PricePerDay, Location, ImageUrl, Status, BookingStatus, BookingFrom, BookingTo, Description, CreatedAt)
                        VALUES (@HostId, @Name, @Type, @PricePerDay, @Location, @ImageUrl, @Status, @BookingStatus, @BookingFrom, @BookingTo, @Description, @CreatedAt);
                        SELECT SCOPE_IDENTITY();", conn);

                    cmd.Parameters.AddWithValue("@HostId", req.HostId);
                    cmd.Parameters.AddWithValue("@Name", req.Name);
                    cmd.Parameters.AddWithValue("@Type", req.Type);
                    cmd.Parameters.AddWithValue("@PricePerDay", req.PricePerDay);
                    cmd.Parameters.AddWithValue("@Location", req.Location);
                    cmd.Parameters.AddWithValue("@ImageUrl", req.ImageUrl ?? "");
                    cmd.Parameters.AddWithValue("@Status", req.Status ?? "active");
                    cmd.Parameters.AddWithValue("@BookingStatus", req.BookingStatus ?? "not booked");
                    cmd.Parameters.AddWithValue("@BookingFrom", req.BookingFrom ?? (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@BookingTo", req.BookingTo ?? (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@Description", req.Description ?? "");
                    cmd.Parameters.AddWithValue("@CreatedAt", DateTime.UtcNow);

                    var propertyId = cmd.ExecuteScalar();
                    return Created("", new { message = "Property added successfully", propertyId = propertyId });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error adding property", error = ex.Message });
            }
        }

        // PUT: Update property
        [HttpPut("{id}")]
        public IActionResult UpdateProperty(int id, [FromBody] PropertyRequest req)
        {
            if (!ModelState.IsValid) 
                return BadRequest(ModelState);

            try
            {
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    
                    // Check if property exists
                    var checkCmd = new SqlCommand("SELECT COUNT(*) FROM Properties WHERE Id = @Id", conn);
                    checkCmd.Parameters.AddWithValue("@Id", id);
                    int propertyExists = (int)checkCmd.ExecuteScalar();
                    
                    if (propertyExists == 0)
                        return NotFound(new { message = "Property not found" });

                    var cmd = new SqlCommand(@"
                        UPDATE Properties
                        SET Name = @Name, Type = @Type, PricePerDay = @PricePerDay, Location = @Location,
                            ImageUrl = @ImageUrl, Status = @Status, BookingStatus = @BookingStatus,
                            BookingFrom = @BookingFrom, BookingTo = @BookingTo, Description = @Description, UpdatedAt = @UpdatedAt
                        WHERE Id = @Id", conn);

                    cmd.Parameters.AddWithValue("@Id", id);
                    cmd.Parameters.AddWithValue("@Name", req.Name);
                    cmd.Parameters.AddWithValue("@Type", req.Type);
                    cmd.Parameters.AddWithValue("@PricePerDay", req.PricePerDay);
                    cmd.Parameters.AddWithValue("@Location", req.Location);
                    cmd.Parameters.AddWithValue("@ImageUrl", req.ImageUrl ?? "");
                    cmd.Parameters.AddWithValue("@Status", req.Status ?? "active");
                    cmd.Parameters.AddWithValue("@BookingStatus", req.BookingStatus ?? "not booked");
                    cmd.Parameters.AddWithValue("@BookingFrom", req.BookingFrom ?? (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@BookingTo", req.BookingTo ?? (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@Description", req.Description ?? "");
                    cmd.Parameters.AddWithValue("@UpdatedAt", DateTime.UtcNow);

                    cmd.ExecuteNonQuery();
                    return Ok(new { message = "Property updated successfully" });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error updating property", error = ex.Message });
            }
        }

        // DELETE: Delete property
        [HttpDelete("{id}")]
        public IActionResult DeleteProperty(int id)
        {
            try
            {
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    
                    // Check if property exists
                    var checkCmd = new SqlCommand("SELECT COUNT(*) FROM Properties WHERE Id = @Id", conn);
                    checkCmd.Parameters.AddWithValue("@Id", id);
                    int propertyExists = (int)checkCmd.ExecuteScalar();
                    
                    if (propertyExists == 0)
                        return NotFound(new { message = "Property not found" });

                    var cmd = new SqlCommand("DELETE FROM Properties WHERE Id = @Id", conn);
                    cmd.Parameters.AddWithValue("@Id", id);
                    cmd.ExecuteNonQuery();
                    
                    return Ok(new { message = "Property deleted successfully" });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error deleting property", error = ex.Message });
            }
        }
    }
}
