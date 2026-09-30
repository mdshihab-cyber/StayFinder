namespace StayFinder_Web_API.Models
{
    public class UserProfileUpdateRequest
    {
        public string FullName { get; set; }
        public string Email { get; set; }
        public string Phone { get; set; }
        public string Bio { get; set; }
    }
}