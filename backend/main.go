package main

import (
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/sqlite"
	"github.com/joho/godotenv"
	"gopkg.in/gomail.v2"
)

// Form represents the structure of the form data
type Form struct {
	ID          uint      `json:"id" gorm:"primary_key"`
	FirstName   string    `json:"first_name" binding:"required"`
	LastName    string    `json:"last_name" binding:"required"`
	DOB         time.Time `json:"dob" binding:"required"`
	Email       string    `json:"email" binding:"required,email"`
	PhoneNumber string    `json:"phone_number" binding:"required"`
	CVFileName  string    `json:"cv_file_name" binding:"required"`
	CreatedAt   time.Time `json:"created_at"`
}

// DB represents the database connection
var DB *gorm.DB

func main() {
	// Load environment variables from .env file
	err := godotenv.Load()
	if err != nil {
		log.Fatal("Error loading .env file:", err)
	}

	// Connect to the SQLite database
	db, err := gorm.Open("sqlite3", "forms.db")
	if err != nil {
		log.Fatal("Error connecting to the database:", err)
	}
	defer db.Close()

	// Initialize the database and auto-migrate the Form model
	DB = db
	db.AutoMigrate(&Form{})

	// Create a new Gin router
	r := gin.Default()

	// Add CORS middleware
	config := cors.Config{
		AllowOrigins: []string{"http://localhost:8081"},
		// , "http://192.168.1.255:3000"},
		AllowMethods: []string{"GET", "POST"},
		AllowHeaders: []string{"Authorization", "Content-Type"},
	}
	r.Use(cors.New(config))

	// Load HTML templates
	r.LoadHTMLGlob("templates/*")

	// Define a route to serve the HTML registration form
	r.GET("/", func(c *gin.Context) {
		c.HTML(http.StatusOK, "form.html", nil)
	})

	// Define a route to handle form submissions
	r.POST("/submit", submitForm)

	// Define a route to handle fetching submitted forms
	r.GET("/submitted-forms", getSubmittedForms)

	// Define a route to serve CV files
	r.GET("/cv/:cvFileName", serveCV)

	// Define a route to fetch CV files (used indirectly through redirection)
	r.GET("/get-cv/:cvFileName", getCV)

	// Run the server on port 8080
	r.Run(":8081")

}

func submitForm(c *gin.Context) {
	// Parse form fields from the POST request
	firstName := c.PostForm("first_name")
	lastName := c.PostForm("last_name")
	dob, _ := time.Parse("2006-01-02", c.PostForm("dob"))
	email := c.PostForm("email")
	phoneNumber := c.PostForm("phone_number")

	// Validate form data
	if calculateAge(dob) < 18 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Age should be at least 18"})
		return
	}

	if !isValidPhoneNumber(phoneNumber) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid phone number"})
		return
	}

	// Handle CV file upload
	cvFile, err := c.FormFile("cv_file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "CV file not found"})
		return
	}
	// Generate a unique filename for the CV file
	cvFileName := fmt.Sprintf("%d_%s", time.Now().UnixNano(), cvFile.Filename)
	cvFilePath := "cv_uploads/" + cvFileName
	if err := c.SaveUploadedFile(cvFile, cvFilePath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save CV file"})
		return
	}

	// Create a new Form struct with the form data
	form := Form{
		FirstName:   firstName,
		LastName:    lastName,
		DOB:         dob,
		Email:       email,
		PhoneNumber: phoneNumber,
		CVFileName:  cvFileName,
		CreatedAt:   time.Now(),
	}

	// Save the form data in the database
	DB.Create(&form)

	// Send an email to the form submitter
	if err := sendEmail(form.Email, "Form Submission Confirmation", "Thank you for submitting the form!"); err != nil {
		log.Println("Error sending email:", err)
	}

	c.JSON(http.StatusOK, form)
}

func calculateAge(dob time.Time) int {
	now := time.Now()
	age := now.Year() - dob.Year()
	if now.Month() < dob.Month() || (now.Month() == dob.Month() && now.Day() < dob.Day()) {
		age--
	}
	return age
}

func isValidPhoneNumber(phoneNumber string) bool {
	return len(phoneNumber) == 10
}

func sendEmail(to, subject, body string) error {
	m := gomail.NewMessage()
	m.SetHeader("From", "testfluttergo@gmail.com")
	m.SetHeader("To", to)
	m.SetHeader("Subject", subject)
	m.SetBody("text/plain", body)

	d := gomail.NewDialer("smtp.gmail.com", 587, "testfluttergo@gmail.com", "Manchester@1")

	if err := d.DialAndSend(m); err != nil {
		return err
	}

	return nil
}
func getSubmittedForms(c *gin.Context) {
	var forms []Form
	if err := DB.Find(&forms).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch submitted forms"})
		return
	}

	c.JSON(http.StatusOK, forms)
}

func serveCV(c *gin.Context) {
	cvFileName := c.Param("cvFileName")
	cvFilePath := "cv_uploads/" + cvFileName
	c.File(cvFilePath)
}

func getCV(c *gin.Context) {
	cvFileName := c.Param("cvFileName")

	// You can add additional logic here, like checking if the CV file exists before serving it

	// Redirect to the /cv/:cvFileName API endpoint to serve the CV file
	c.Redirect(http.StatusFound, "/cv/"+cvFileName)
}
