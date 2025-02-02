package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

var db *sql.DB

var (
	dbUser     string
	dbPassword string
	dbName     string
)

func main() {
	// Load environment variables from ldflags
	connStr := fmt.Sprintf("postgres://%s:%s@localhost:5432/%s?sslmode=disable", dbUser, dbPassword, dbName)

	// Connect to the database
	var err error
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		fmt.Println("Error connecting to the database:", err)
		os.Exit(1)
	}
	defer db.Close()

	// Verify the connection
	if err := db.Ping(); err != nil {
		fmt.Println("Error pinging the database:", err)
		os.Exit(1)
	}

	// Initialize the Gin router
	router := gin.Default()

	// Routes
	router.GET("/stops/:stop_id", getStopDetails)
	router.GET("/stops/:stop_id/next", getNextDepartures)
	router.GET("/trips/:trip_id", getTripDetails)
	router.GET("/stops", getStops)

	// Start the server
	router.Run(":8081")
}

// Handler to get details of a specific stop
func getStopDetails(c *gin.Context) {
	stopID := c.Param("stop_id")

	// Query the database
	rows, err := db.Query("SELECT * FROM stops WHERE stop_id = $1", stopID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error querying database: " + err.Error()})
		return
	}
	defer rows.Close()

	// Process results
	var results []map[string]interface{}
	for rows.Next() {
		var tripID, stopID, stopHeadSign sql.NullString
		var arrivalTime, departureTime sql.NullString
		var stopSequence, pickupType, dropOffType, timePoint sql.NullInt32

		err = rows.Scan(&tripID, &arrivalTime, &departureTime, &stopID, &stopSequence, &stopHeadSign, &pickupType, &dropOffType, &timePoint)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error scanning database rows: " + err.Error()})
			return
		}

		results = append(results, gin.H{
			"trip_id":       tripID,
			"stop_id":       stopID,
			"arrival_time":  arrivalTime,
			"departure_time": departureTime,
			"stop_sequence": stopSequence,
			"stop_headsign": stopHeadSign,
			"pickup_type":   pickupType,
			"drop_off_type": dropOffType,
			"time_point":    timePoint,
		})
	}

	c.JSON(http.StatusOK, results)
}

// Handler to get the next departures for a specific stop
func getNextDepartures(c *gin.Context) {
	stopID := c.Param("stop_id")

	// Get the current date and day of the week
	currentDate := time.Now().Format("2006-01-02")
	currentDayOfWeek := time.Now().Weekday().String()

	// Map Go's weekday to the column names in the calendar table
	dayOfWeekMap := map[string]string{
		"Sunday":    "sunday",
		"Monday":    "monday",
		"Tuesday":   "tuesday",
		"Wednesday": "wednesday",
		"Thursday":  "thursday",
		"Friday":    "friday",
		"Saturday":  "saturday",
	}

	dayOfWeekColumn := dayOfWeekMap[currentDayOfWeek]

	rows, err := db.Query(`
		SELECT s.* FROM stop_times s
		JOIN trips t ON s.trip_id = t.trip_id
		JOIN calendar c ON t.service_id = c.service_id
		WHERE s.stop_id = $1 
		AND s.departure_time >= CURRENT_TIME
		AND c.`+dayOfWeekColumn+` = 1
		AND c.start_date <= $2
		AND c.end_date >= $2
		ORDER BY s.departure_time ASC 
		LIMIT 8
	`, stopID, currentDate)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error querying database: " + err.Error()})
		return
	}
	defer rows.Close()

	// Process results
	var results []map[string]interface{}
	for rows.Next() {
		var tripID, stopID, stopHeadSign sql.NullString
		var arrivalTime, departureTime sql.NullString
		var stopSequence, pickupType, dropOffType, timePoint sql.NullInt32

		err = rows.Scan(&tripID, &arrivalTime, &departureTime, &stopID, &stopSequence, &stopHeadSign, &pickupType, &dropOffType, &timePoint)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error scanning database rows: " + err.Error()})
			return
		}

		results = append(results, gin.H{
			"trip_id":       tripID,
			"stop_id":       stopID,
			"arrival_time":  arrivalTime,
			"departure_time": departureTime,
			"stop_sequence": stopSequence,
			"stop_headsign": stopHeadSign,
			"pickup_type":   pickupType,
			"drop_off_type": dropOffType,
			"time_point":    timePoint,
		})
	}

	c.JSON(http.StatusOK, results)
}

// Handler to get details of a specific trip
func getTripDetails(c *gin.Context) {
	tripID := c.Param("trip_id")

	row := db.QueryRow("SELECT * FROM trips WHERE trip_id = $1", tripID)

	var routeID, serviceID, tripIDStr, tripHeadSign, tripShortName, blockID, shapeID sql.NullString
	var directionID sql.NullInt32

	err := row.Scan(&routeID, &serviceID, &tripIDStr, &tripHeadSign, &tripShortName, &directionID, &blockID, &shapeID)
	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Trip not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error querying database: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"route_id":        routeID,
		"service_id":      serviceID,
		"trip_id":         tripIDStr,
		"trip_headsign":   tripHeadSign,
		"trip_short_name": tripShortName,
		"direction_id":    directionID,
		"block_id":        blockID,
		"shape_id":        shapeID,
	})
}

// Handler to get the eight nearest stops to the user's location
func getStops(c *gin.Context) {
	userLat := c.Query("lat")
	userLng := c.Query("lng")

	if userLat == "" || userLng == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Latitude and longitude are required"})
		return
	}

	rows, err := db.Query(`
		SELECT stop_id, stop_name, stop_lat, stop_lon,
			   ( 6371000 * acos(
				   cos(radians($1)) * cos(radians(stop_lat)) *
				   cos(radians(stop_lon) - radians($2)) +
				   sin(radians($1)) * sin(radians(stop_lat))
				 )
			   ) AS distance
		FROM stops
		ORDER BY distance
		LIMIT 8
	`, userLat, userLng)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error querying database: " + err.Error()})
		return
	}
	defer rows.Close()

	// Process results
	var results []map[string]interface{}
	for rows.Next() {
		var stopID, stopName sql.NullString
		var latitude, longitude sql.NullFloat64
		var distance sql.NullFloat64

		err = rows.Scan(&stopID, &stopName, &latitude, &longitude, &distance)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error scanning database rows: " + err.Error()})
			return
		}

		results = append(results, gin.H{
			"stop_id":   stopID,
			"stop_name": stopName,
			"latitude":  latitude,
			"longitude": longitude,
			"distance":  distance,
		})
	}

	c.JSON(http.StatusOK, results)
}