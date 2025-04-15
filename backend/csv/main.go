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
	router.GET("/timetable", getTimetable)

	router.Run(":8081")
}

func getTimetable(c * gin.Context) () {
	routeID := c.Query("route_id")

	if routeID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "routeID is required to not be empty"})
	}

	trips, err := getTrips(routeID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Initialize timetable structure
	timetables := map[string]map[string]map[string]interface{}{}
	days := []string{"monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"}

	for _, day := range days {
		timetables[day] = map[string]map[string]interface{}{
			"trips": {},
		}
	}

	for _, trip := range(trips) {
		serviceID, ok := trip["service_id"].(sql.NullString)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "serviceID is not a valid string"})
			return
		}
		if !serviceID.Valid {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "serviceID is not valid"})
			return
		}
		calendar, err := getCalendar(serviceID.String)
		
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		tripID, ok := trip["trip_id"].(sql.NullString)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "trip_id is not a valid sql.NullString"})
			return
		}
		routeShortName, err := getRouteShortNameForTrip(tripID)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		trip["start_date"] = calendar["start_date"]
		trip["end_date"] = calendar["end_date"]
		trip["route_short_name"] = routeShortName

		days := []string{"monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"}
		for _, day := range days {
			calendar_day := calendar[day]
			calendarDayStr, ok := calendar_day.(sql.NullString)
			if !ok {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "calendar_day is not a valid string"})
				return
			}
			if calendarDayStr.String == "1" {
				trip["day"] = day
				break
			}
		}

		if !tripID.Valid {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "tripID is not valid"})
			return
		}
		tripIDStr := tripID.String

		day, ok := trip["day"].(string)
		if !ok {
			continue // or handle error
		}

		stopTimes, err := getStopTimes(tripIDStr)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		var arrivalTimes []string
		var stopNames []string

		for _, stopTime := range stopTimes {
			stopID := stopTime["stop_id"]
			stopIDStr, ok := stopID.(sql.NullString)
			if !ok {
				continue
			}
			stop, err := getStop(stopIDStr.String)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			stopTime["stop_name"] = stop["stop_name"]

			// Handle arrival_time
			arrivalTime, ok := stopTime["arrival_time"].(sql.NullTime)
			if ok && arrivalTime.Valid {
				arrivalTimes = append(arrivalTimes, arrivalTime.Time.Format("15:04:05"))
			}

			// Handle stop_name
			stopName, ok := stopTime["stop_name"].(sql.NullString)
			if ok && stopName.Valid {
				stopNames = append(stopNames, stopName.String)
			}
		}

		timetables[day]["trips"][tripID.String] = map[string]interface{}{
			"arrival_times": arrivalTimes,
			"stop_names":    stopNames,
			"start_date":    trip["start_date"].(sql.NullString).String,
			"end_date":      trip["end_date"].(sql.NullString).String,
		}
	}

	// Return the complete timetable structure
	c.JSON(
		http.StatusOK,
		gin.H{
			"route_id":         routeID,
			"route_short_name": trips[0]["route_short_name"].(sql.NullString).String,
			"timetables":       timetables,
		},
	)
}

func getStop(stopID string) (map[string]interface{}, error) {
	if stopID == "" {
		return nil, fmt.Errorf("error: stopID is required to not be empty")
	}

	row, err := db.Query(`
		SELECT stop_id,stop_code,stop_name,stop_desc,stop_lat,stop_lon,zone_id,stop_url,location_type,parent_station
		FROM stops
		WHERE stop_id = $1
	`, stopID)

	if err != nil {
		return nil, fmt.Errorf("error querying database: %w", err)
	}

	var result map[string]interface{}

	for row.Next() {

		var stop_id,stop_code,stop_name,stop_desc,stop_lat,stop_lon,zone_id,stop_url,parent_station sql.NullString

		var location_type sql.NullInt64

		if err := row.Scan(&stop_id, &stop_code, &stop_name, &stop_desc, &stop_lat, &stop_lon, &zone_id, &stop_url, &location_type, &parent_station); err != nil {
			return nil, fmt.Errorf("error scanning stop row: %w", err)
		}

		result = gin.H{
			"stop_id":stop_id,
			"stop_code":stop_code,
			"stop_name": stop_name,
			"stop_desc":stop_desc,
			"stop_lat":stop_lat,
			"stop_lon":stop_lon,
			"zone_id":zone_id,
			"stop_url":stop_url,
			"location_type":location_type,
			"parent_station":parent_station,
		}
	}

	defer row.Close()

	return result, nil
}

func getStopTimes(tripID string) ([]map[string]interface{}, error) {
	if tripID == "" {
		return nil, fmt.Errorf("error: serviceID is required not to be empty")
	}

	rows, err := db.Query(`
		SELECT trip_id,arrival_time,departure_time,stop_id,stop_sequence,stop_headsign,pickup_type,drop_off_type,timepoint
		FROM stop_times
		WHERE trip_id = $1
	`,tripID)

	if err != nil {
		return nil, fmt.Errorf("error querying database: %w", err)
	}

	var results []map[string]interface{}

	for rows.Next() {
		var trip_id, stop_id, stop_headsign sql.NullString
		var arrival_time, departure_time sql.NullTime
		var pickup_type, drop_off_type, timepoint, stop_sequence sql.NullInt64

		if err := rows.Scan(&trip_id, &arrival_time, &departure_time, &stop_id, &stop_sequence, &stop_headsign, &pickup_type, &drop_off_type, &timepoint); err != nil {
			return nil, fmt.Errorf("error scanning stoptime row: %w", err)
		}

		results = append(results, gin.H{
			"trip_id":trip_id,
			"arrival_time":arrival_time,
			"departure_time":departure_time,
			"stop_id":stop_id,
			"stop_sequence":stop_sequence,
			"stop_headsign":stop_headsign,
			"pickup_type":pickup_type,
			"drop_off_type":drop_off_type,
			"timepoint":timepoint,
			"stop_name": "",
		})
	}
	defer rows.Close()
	return results, nil
}

func getCalendar(serviceID string) (map[string]interface{}, error) {
	if serviceID == "" {
		return nil, fmt.Errorf("error: serviceID is required not to be empty")
	}

	var result map[string]interface{}

	row, err := db.Query(`
		SELECT service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date
		FROM calendar
		WHERE service_id = $1
	`, serviceID)

	if err != nil {
		return nil, fmt.Errorf("error querying database: %w", err)
	}

	for row.Next(){
		var service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date sql.NullString

	if err := row.Scan(&service_id, &monday, &tuesday, &wednesday, &thursday, &friday, &saturday, &sunday, &start_date, &end_date); err != nil {
		return nil, fmt.Errorf("error scanning trip row: %w", err)
	}

	result = gin.H{
		"service_id": service_id,
		"monday": monday,
		"tuesday": tuesday,
		"wednesday": wednesday,
		"thursday": thursday,
		"friday": friday,
		"saturday": saturday,
		"sunday": sunday,
		"start_date": start_date,
		"end_date": end_date,
	}}

	defer row.Close()

	return result, nil
}

func getTrips(routeID string) ([]map[string]interface{}, error) {
	if routeID == "" {
		return nil, fmt.Errorf("error: routeID is required not to be empty")
	}

	rows, err := db.Query(`
		SELECT route_id, service_id, trip_id
		FROM trips
		WHERE route_id = $1
	`, routeID)

	if err != nil {
		return nil, fmt.Errorf("Error querying database: " + err.Error())
	}

	var results []map[string]interface{}

	for rows.Next() {
		var routeID, serviceID, tripID sql.NullString

		if err := rows.Scan(&routeID, &serviceID, &tripID); err != nil {
			return nil, fmt.Errorf("error scanning trip row: %w", err)
		}

		results = append(results, gin.H{
			"route_id": routeID,
			"service_id": serviceID,
			"trip_id": tripID,
			"day": "",
			"start_date": "",
			"end_date": "",
			"route_short_name": "",
		})
	}

	defer rows.Close()

	return results, nil
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