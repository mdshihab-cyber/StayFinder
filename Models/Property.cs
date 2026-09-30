namespace StayFinder_Web_API.Models
{
    public class Property
    {
        public int Id { get; set; }
        public int HostId { get; set; }
        public string Name { get; set; }
        public string Type { get; set; }
        public decimal PricePerDay { get; set; }
        public string Location { get; set; }
        public string? ImageUrl { get; set; }
        public string Status { get; set; }
        public string BookingStatus { get; set; }
        public DateTime? BookingFrom { get; set; }
        public DateTime? BookingTo { get; set; }
        public string? Description { get; set; }  // New description field
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}