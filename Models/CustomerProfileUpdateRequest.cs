namespace StayFinder_Web_API.Models
{
    public class CustomerProfileUpdateRequest
    {
        public string FullName { get; set; }
        public string Email { get; set; }
        public string Phone { get; set; }
        public string Password { get; set; } // optional for change password
    }
}
