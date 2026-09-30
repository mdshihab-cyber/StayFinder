using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using StayFinder_Web_API.Models;

namespace StayFinder_Web_API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SavedPropertiesController : ControllerBase
    {
        private readonly string _connectionString = "Server=DESKTOP-7VNIMVI\\SQLEXPRESS;Database=StayFinderWebApiDB;Trusted_Connection=True;Encrypt=False;";

        [HttpPost]
        public async Task<IActionResult> Add([FromBody] AddSavedPropertyRequest request)
        {
            if (request == null || request.CustomerId <= 0 || request.PropertyId <= 0)
                return BadRequest(new { message = "Invalid request" });

            try
            {
                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                // Ensure customer exists
                using (var cmd = new SqlCommand("SELECT COUNT(*) FROM Customers WHERE Id = @CustomerId", connection))
                {
                    cmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                    var count = (int)await cmd.ExecuteScalarAsync();
                    if (count == 0) return BadRequest(new { message = "Customer not found" });
                }

                // Ensure property exists
                using (var cmd = new SqlCommand("SELECT COUNT(*) FROM Properties WHERE Id = @PropertyId", connection))
                {
                    cmd.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                    var count = (int)await cmd.ExecuteScalarAsync();
                    if (count == 0) return BadRequest(new { message = "Property not found" });
                }

                // Prevent duplicates
                using (var cmd = new SqlCommand(@"SELECT COUNT(*) FROM CustomerSavedProperties WHERE CustomerId=@CustomerId AND PropertyId=@PropertyId", connection))
                {
                    cmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                    cmd.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                    var exists = (int)await cmd.ExecuteScalarAsync();
                    if (exists > 0)
                    {
                        return Ok(new { message = "Already saved" });
                    }
                }

                // Insert
                using (var cmd = new SqlCommand(@"INSERT INTO CustomerSavedProperties (CustomerId, PropertyId, CreatedAt) VALUES (@CustomerId, @PropertyId, @CreatedAt)", connection))
                {
                    cmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                    cmd.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                    cmd.Parameters.AddWithValue("@CreatedAt", DateTime.UtcNow);
                    await cmd.ExecuteNonQueryAsync();
                }

                return Ok(new { message = "Saved" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Failed to save property", error = ex.Message });
            }
        }

        [HttpDelete]
        public async Task<IActionResult> Remove([FromBody] AddSavedPropertyRequest request)
        {
            if (request == null || request.CustomerId <= 0 || request.PropertyId <= 0)
                return BadRequest(new { message = "Invalid request" });

            try
            {
                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                using var cmd = new SqlCommand("DELETE FROM CustomerSavedProperties WHERE CustomerId=@CustomerId AND PropertyId=@PropertyId", connection);
                cmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                cmd.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                var affected = await cmd.ExecuteNonQueryAsync();

                if (affected == 0)
                    return NotFound(new { message = "Not found" });

                return Ok(new { message = "Removed" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Failed to remove property", error = ex.Message });
            }
        }

        [HttpPost("toggle")]
        public async Task<IActionResult> Toggle([FromBody] AddSavedPropertyRequest request)
        {
            if (request == null || request.CustomerId <= 0 || request.PropertyId <= 0)
                return BadRequest(new { message = "Invalid request" });

            try
            {
                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                // Check exists
                using (var check = new SqlCommand("SELECT Id FROM CustomerSavedProperties WHERE CustomerId=@CustomerId AND PropertyId=@PropertyId", connection))
                {
                    check.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                    check.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                    var existingId = await check.ExecuteScalarAsync();

                    if (existingId != null)
                    {
                        using var del = new SqlCommand("DELETE FROM CustomerSavedProperties WHERE Id=@Id", connection);
                        del.Parameters.AddWithValue("@Id", Convert.ToInt32(existingId));
                        await del.ExecuteNonQueryAsync();
                        return Ok(new { message = "Removed", saved = false });
                    }
                }

                // Insert new
                using (var insert = new SqlCommand("INSERT INTO CustomerSavedProperties (CustomerId, PropertyId, CreatedAt) VALUES (@CustomerId, @PropertyId, @CreatedAt)", connection))
                {
                    insert.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                    insert.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                    insert.Parameters.AddWithValue("@CreatedAt", DateTime.UtcNow);
                    await insert.ExecuteNonQueryAsync();
                }
                return Ok(new { message = "Saved", saved = true });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Toggle failed", error = ex.Message });
            }
        }

        [HttpGet("customer/{customerId}")]
        public async Task<IActionResult> ListForCustomer(int customerId)
        {
            try
            {
                var results = new List<object>();
                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                var sql = @"SELECT csp.Id, csp.PropertyId, csp.CreatedAt, p.Name, p.PricePerDay, p.Location, p.ImageUrl, p.Type, p.Status
                             FROM CustomerSavedProperties csp
                             INNER JOIN Properties p ON csp.PropertyId = p.Id
                             WHERE csp.CustomerId = @CustomerId
                             ORDER BY csp.CreatedAt DESC";
                using var cmd = new SqlCommand(sql, connection);
                cmd.Parameters.AddWithValue("@CustomerId", customerId);
                using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    results.Add(new
                    {
                        id = reader.GetInt32(reader.GetOrdinal("Id")),
                        propertyId = reader.GetInt32(reader.GetOrdinal("PropertyId")),
                        createdAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")).ToString("yyyy-MM-dd HH:mm:ss"),
                        name = reader["Name"].ToString(),
                        pricePerDay = reader.GetDecimal(reader.GetOrdinal("PricePerDay")),
                        location = reader["Location"].ToString(),
                        imageUrl = reader["ImageUrl"] == DBNull.Value ? null : reader["ImageUrl"].ToString(),
                        type = reader["Type"].ToString(),
                        status = reader["Status"].ToString()
                    });
                }

                return Ok(results);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Failed to load saved properties", error = ex.Message });
            }
        }

        [HttpGet("is-saved")]
        public async Task<IActionResult> IsSaved([FromQuery] int customerId, [FromQuery] int propertyId)
        {
            if (customerId <= 0 || propertyId <= 0)
                return BadRequest(new { message = "Invalid parameters" });

            try
            {
                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();
                using var cmd = new SqlCommand("SELECT COUNT(*) FROM CustomerSavedProperties WHERE CustomerId=@CustomerId AND PropertyId=@PropertyId", connection);
                cmd.Parameters.AddWithValue("@CustomerId", customerId);
                cmd.Parameters.AddWithValue("@PropertyId", propertyId);
                var count = (int)await cmd.ExecuteScalarAsync();
                return Ok(new { saved = count > 0 });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Failed to check saved state", error = ex.Message });
            }
        }
    }
}
