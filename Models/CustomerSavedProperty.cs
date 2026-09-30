namespace StayFinder_Web_API.Models
{
    public class CustomerSavedProperty
    {
        public int Id { get; set; }
        public int CustomerId { get; set; }
        public int PropertyId { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class AddSavedPropertyRequest
    {
        public int CustomerId { get; set; }
        public int PropertyId { get; set; }
    }
}
