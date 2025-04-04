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
	ipAddress  string
	port       string
)

func main() {
	// Load environment variables from ldflags
	connStr := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable", dbUser, dbPassword, ipAddress, port, dbName)

	var err error
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		fmt.Println("Error connecting to the database:", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		fmt.Println("Error pinging the database:", err)
		os.Exit(1)
	}

	router := gin.Default()

	router.GET("/nearestStops", getNearestStopsandDepartures)
	router.GET("/stops", getStopsAndDepartures)

	router.Run(":8081")
}

func getStops(query string) ([]map[string]interface{}, error){

	if query == "" {
		return nil, fmt.Errorf("error: Query is required to not be empty")
	}

	rows, err := db.Query(`
		SELECT stop_id, stop_name
		FROM stops
		WHERE stop_name ILIKE $1
		LIMIT 8
	`, "%"+query+"%")

	if err != nil {
		return nil, fmt.Errorf("Error querying database: " + err.Error())
	}

	var results []map[string]interface{}
	for rows.Next() {
		var stopID, stopName sql.NullString
		if err := rows.Scan(&stopID, &stopName); err != nil {
			return nil, fmt.Errorf("error scanning stop row: %w", err)
		}

		results = append(results, gin.H{
			"stop_id":   stopID,
			"stop_name": stopName,
			"trips":     []interface{}{},
		})
	}
	defer rows.Close()
	return results, nil

}

func getStopsAndDepartures(c * gin.Context) {
	query := c.Query("query")

	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "query is required to not be empty"})
		return
	}

	stops, err := getStops(query)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	currentDate, now, dayOfWeekColumn := getCurrentDateAndTimeInfo()

	for i, stop := range stops {
		stopID := stop["stop_id"]
		trips, err := getUpcomingTripsForStop(stopID, currentDate, now, dayOfWeekColumn)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		stops[i]["trips"] = trips
	}

	c.JSON(http.StatusOK, stops)
}

func getNearestStopsandDepartures(c *gin.Context) {
	userLat, userLng := c.Query("lat"), c.Query("lng")
	if userLat == "" || userLng == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Latitude and longitude are required"})
		return
	}

	stops, err := getNearestStops(userLat, userLng)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	currentDate, now, dayOfWeekColumn := getCurrentDateAndTimeInfo()

	for i, stop := range stops {
		stopID := stop["stop_id"]
		trips, err := getUpcomingTripsForStop(stopID, currentDate, now, dayOfWeekColumn)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		stops[i]["trips"] = trips
	}

	c.JSON(http.StatusOK, stops)
}

func getNearestStops(lat, lng string) ([]map[string]interface{}, error) {
	rows, err := db.Query(`
		SELECT stop_id, stop_name, stop_lat, stop_lon,
			(6371000 * acos(
				cos(radians($1)) * cos(radians(stop_lat)) *
				cos(radians(stop_lon) - radians($2)) +
				sin(radians($1)) * sin(radians(stop_lat))
			)) AS distance
		FROM stops
		ORDER BY distance
		LIMIT 8`, lat, lng)
	if err != nil {
		return nil, fmt.Errorf("error querying nearest stops: %w", err)
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var stopID, stopName sql.NullString
		var lat, lon, dist sql.NullFloat64
		if err := rows.Scan(&stopID, &stopName, &lat, &lon, &dist); err != nil {
			return nil, fmt.Errorf("error scanning stop row: %w", err)
		}

		results = append(results, gin.H{
			"stop_id":   stopID,
			"stop_name": stopName,
			"latitude":  lat,
			"longitude": lon,
			"distance":  int(dist.Float64),
			"trips":     []interface{}{},
		})
	}
	return results, nil
}

func getCurrentDateAndTimeInfo() (string, string, string) {
	loc, _ := time.LoadLocation("Europe/Dublin")
	nowTime := time.Now().In(loc)
	currentDate := nowTime.Format("2006-01-02")
	currentTime := nowTime.Format("15:04:05")

	dayOfWeek := nowTime.Weekday().String()
	dayOfWeekMap := map[string]string{
		"Sunday": "sunday", "Monday": "monday", "Tuesday": "tuesday",
		"Wednesday": "wednesday", "Thursday": "thursday",
		"Friday": "friday", "Saturday": "saturday",
	}
	return currentDate, currentTime, dayOfWeekMap[dayOfWeek]
}

func getUpcomingTripsForStop(stopID interface{}, currentDate, currentTime, dayColumn string) ([]interface{}, error) {
	query := fmt.Sprintf(`
		SELECT s.* FROM stop_times s
		JOIN trips t ON s.trip_id = t.trip_id
		JOIN calendar c ON t.service_id = c.service_id
		WHERE s.stop_id = $1
		AND s.departure_time >= $2
		AND c.%s = 1
		AND c.start_date <= $3
		AND c.end_date >= $3
		ORDER BY s.departure_time ASC 
		LIMIT 8`, dayColumn)

	rows, err := db.Query(query, stopID, currentTime, currentDate)
	if err != nil {
		return nil, fmt.Errorf("error querying upcoming trips: %w", err)
	}
	defer rows.Close()

	var trips []interface{}
	for rows.Next() {
		var tripID, stopID, stopHeadSign sql.NullString
		var arrivalTime, departureTime sql.NullString
		var stopSeq, pickup, dropoff, timepoint sql.NullInt32

		if err := rows.Scan(&tripID, &arrivalTime, &departureTime, &stopID, &stopSeq, &stopHeadSign, &pickup, &dropoff, &timepoint); err != nil {
			return nil, fmt.Errorf("error scanning stop_time row: %w", err)
		}

		routeName, err := getRouteShortNameForTrip(tripID)
		if err != nil {
			return nil, err
		}

		trips = append(trips, gin.H{
			"trip_id":          tripID,
			"arrival_time":     arrivalTime,
			"departure_time":   departureTime,
			"stop_sequence":    stopSeq,
			"stop_headsign":    stopHeadSign,
			"pickup_type":      pickup,
			"drop_off_type":    dropoff,
			"time_point":       timepoint,
			"route_short_name": routeName,
		})
	}
	if trips == nil {
		return []interface{}{}, nil
	}
	return trips, nil
}

func getRouteShortNameForTrip(tripID sql.NullString) (sql.NullString, error) {
	var routeID sql.NullString
	row := db.QueryRow("SELECT route_id FROM trips WHERE trip_id = $1", tripID)
	if err := row.Scan(&routeID); err != nil {
		if err == sql.ErrNoRows {
			return sql.NullString{}, fmt.Errorf("trip not found")
		}
		return sql.NullString{}, fmt.Errorf("error fetching trip: %w", err)
	}

	var routeShortName sql.NullString
	row = db.QueryRow("SELECT route_short_name FROM routes WHERE route_id = $1", routeID)
	if err := row.Scan(&routeShortName); err != nil {
		if err == sql.ErrNoRows {
			return sql.NullString{}, fmt.Errorf("route not found")
		}
		return sql.NullString{}, fmt.Errorf("error fetching route: %w", err)
	}
	return routeShortName, nil
}