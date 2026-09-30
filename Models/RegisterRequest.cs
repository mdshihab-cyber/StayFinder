using System.ComponentModel.DataAnnotations;

namespace StayFinder_Web_API.Models
{


    public class RegisterRequest
    {
        [Required(ErrorMessage = "Role is required")]
        public string Role { get; set; }
        
        [Required(ErrorMessage = "Full name is required")]
        [StringLength(200, ErrorMessage = "Full name cannot exceed 200 characters")]
        public string FullName { get; set; }
        
        [Required(ErrorMessage = "Email is required")]
        [EmailAddress(ErrorMessage = "Invalid email format")]
        [StringLength(150, ErrorMessage = "Email cannot exceed 150 characters")]
        public string Email { get; set; }
        
        [Required(ErrorMessage = "Phone number is required")]
        [StringLength(20, ErrorMessage = "Phone number cannot exceed 20 characters")]
        public string Phone { get; set; }
        
        [Required(ErrorMessage = "Password is required")]
        [StringLength(100, MinimumLength = 6, ErrorMessage = "Password must be between 6 and 100 characters")]
        public string Password { get; set; }
        
        [Required(ErrorMessage = "Password confirmation is required")]
        public string ConfirmPassword { get; set; }
    }


}
