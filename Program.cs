using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();

// Add CORS policy
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(builder =>
    {
        builder.AllowAnyOrigin()
               .AllowAnyMethod()
               .AllowAnyHeader();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

// Enable CORS first
app.UseCors();

// Configure default files to serve index.html as the default page
var defaultFilesOptions = new DefaultFilesOptions();
defaultFilesOptions.DefaultFileNames.Clear();
defaultFilesOptions.DefaultFileNames.Add("index.html");
app.UseDefaultFiles(defaultFilesOptions);

// Enable static files (for serving HTML, CSS, JS)
app.UseStaticFiles();

// Test DB connection at startup
try
{
    var connectionString = "Server=DESKTOP-7VNIMVI\\SQLEXPRESS;Database=StayFinderWebApiDB;Trusted_Connection=True;Encrypt=False;";
    using (var conn = new SqlConnection(connectionString))
    {
        conn.Open();
        Console.WriteLine(":) Database connection successful!");
        conn.Close();
    }
}
catch (Exception ex)
{
    Console.WriteLine(":( Database connection failed: " + ex.Message);
}

// Map API controllers
app.MapControllers();

// Ensure root path serves index.html (fallback)
app.MapFallbackToFile("index.html");

Console.WriteLine("?? StayFinder application is starting...");
Console.WriteLine("?? Default page: index.html");
Console.WriteLine("?? Navigate to: https://localhost:7000 or http://localhost:5000");

app.Run();
