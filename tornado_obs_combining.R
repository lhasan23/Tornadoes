library(rnoaa)
library(dplyr)
# Set your NOAA API key here
options(noaakey = "xxxx")

tornado_data <- read.csv("1950-2018_all_tornadoes.csv") %>% arrange(desc(date))

# Number of tornadoes to get
n_tornadoes <- 5000

# Start index and current index
idx <- 1

new_tornado_data <- tibble()

while (nrow(new_tornado_data) < n_tornadoes) {
  # Select a tornado from the index
  tornado <- tornado_data %>% slice(idx)
  
  # Find weather stations up to 50 miles from the tornado
  station_isds <- isd_stations_search(lat=tornado$slat, lon=tornado$slon, radius=25)
  
  # We'll consider up to the closest 5 weather stations - some stations don't have weather data
  max_idx = min(nrow(station_isds), 5)
  for (i in 1:max_idx) {
    station_isd <- station_isds[i,]
    
    # Fetch the station data. Ignore errors from the isd function
    tryCatch({
      isd_data <- isd(
        station_isd$usaf,
        station_isd$wban,
        format(as.Date(tornado$date), "%Y")
      )
      if (length(isd_data)> 0) {
        # Combine the date time columns
        date_time <- as.POSIXlt(paste(tornado$date, tornado$time))
        
        # Subtract an hour to get weather obs 1 hour before the tornado
        date_time$hour = date_time$hour - 1
        
        # We could repeat this for 2 hours before, 3 hours before, etc.
        new_data <- isd_data %>% 
          filter(date == format(date_time, "%Y%m%d") & time >= format(date_time, "%H%m"))  %>% #  Get the observations one hour before and later
          dplyr::select(date,time,wind_speed, visibility_distance, temperature, temperature_dewpoint, air_pressure) %>% 
          rename(weather_date=date, weather_time=time) %>% # Rename date and time as they are duplicates in the tornadoes
          slice_head()
        
        # 2 hours before
        date_time$hour = date_time$hour - 1
        
        new_data_2 <- isd_data %>% 
          filter(date == format(date_time, "%Y%m%d") & time >= format(date_time, "%H%m"))  %>% #  Get the observations two hours before and later
          dplyr::select(date,time,wind_speed, visibility_distance, temperature, temperature_dewpoint, air_pressure) %>% 
          rename(weather_date_2=date, weather_time_2=time, wind_speed_2=wind_speed, visibility_distance_2=visibility_distance, temperature_2=temperature, temperature_dewpoint_2=temperature_dewpoint, air_pressure_2=air_pressure) %>% # Rename date and time as they are duplicates in the tornadoes
          slice_head()
 
        new_tornado_data <- bind_rows(new_tornado_data, bind_cols(tornado, new_data, new_data_2))
        print('new data!')
        print(paste("n obs:", nrow(new_tornado_data)))
        break
      }
    }, error=function(e){print(e)})
    
  }
  idx = idx + 1
  print(idx)
  
}
# Write to csv file
write.csv(new_tornado_data, file='combined_tornado_weather.csv')