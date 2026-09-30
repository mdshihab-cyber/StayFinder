namespace StayFinder_Web_API.Models
{
    public class PropertyReview
    {
        public int Id { get; set; }
        public int PropertyId { get; set; }
        public int CustomerId { get; set; }
        public int Rating { get; set; }
        public string? Comment { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}