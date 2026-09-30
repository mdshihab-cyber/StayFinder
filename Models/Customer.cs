namespace StayFinder_Web_API.Models
{
    public class Customer
    {
        public int Id { get; set; } // Primary key and foreign key to Users.Id
        public decimal Rating { get; set; } = 0;
        public string SavedProperties { get; set; } = "[]"; // JSON string
    }
}
