#Start of the First R Project - Data Cleaning

#Package loading
library(tidyr)

#Reading The RDS object to a dataframe
weather_df <- readRDS("weather.rds")
class(weather_df)

#Exploring raw data in dataframe using different functions
str(weather_df)
dim(weather_df)
summary(weather_df)

#Viewing Data in dataframe "weather_df"
head(weather_df,n=20)
tail(weather_df,n=20)

#Converting the messy data to tidy data
weather_df_new<-gather(weather_df, day, value, X1:X31, na.rm = TRUE)
head(weather_df_new)
weather_df_new <- weather_df_new[,-1]#removing first column
weather_df_tidy <- spread(weather_df_new,measure,value)
head(weather_df_tidy)

#preparing data for analysis using "lubridate", "dplyr" and "stringr" package
library(lubridate)
library(stringr)
library(dplyr)
weather_df_tidy$day <- str_replace(weather_df_tidy$day, "X", "") # Remove X's from day column

# Unite the year, month, and day columns
weather_df_tidy <- unite(weather_df_tidy, date, year, month, day, sep = "-")

# Convert date column to proper date format using lubridates's ymd()
weather_df_tidy$date <- ymd(weather_df_tidy$date)
head(weather_df_tidy,n=2)




# Replace T with 0 (T = trace)
weather_df_tidy$PrecipitationIn <- str_replace(weather_df_tidy$PrecipitationIn, "T", "0")
as.numeric(weather_df_tidy$PrecipitationIn)

# Convert characters to numerics
weather_df_tidy1 <- mutate_each(weather_df_tidy, funs(as.numeric), CloudCover:WindDirDegrees)

# Look at result
str(weather_df_tidy1)


######
# Count missing values
sum(is.na(weather_df_tidy1))

# Find missing values
summary(weather_df_tidy1)

# Find indices of NAs in Max.Gust.SpeedMPH
ind <- which(is.na(weather_df_tidy1$Max.Gust.SpeedMPH))

# Look at the full rows for records missing Max.Gust.SpeedMPH
weather_df_tidy1[ind, ]

####
# Review distributions for all variables
summary(weather_df_tidy1)

# Find row with Max.Humidity of 1000
ind <- which(weather_df_tidy1$Max.Humidity == 1000)

# Look at the data for that day
weather_df_tidy1[ind, ]

# Change 1000 to 100
weather_df_tidy1$Max.Humidity[ind] <- 100


##########
# Look at summary of Mean.VisibilityMiles
summary(weather_df_tidy1$Mean.VisibilityMiles)

# Get index of row with -1 value
ind <- which(weather_df_tidy1$Mean.VisibilityMiles == -1)

# Look at full row
weather_df_tidy1[ind, ]

# Set Mean.VisibilityMiles to the appropriate value
weather_df_tidy1$Mean.VisibilityMiles[ind] <- 10

# Replace empty cells in events column
#weather_df_tidy1$events[weather_df_tidy1$events == ""] <- "None"


#Visualizing
# Look at histogram for MeanDew.PointF
hist(weather_df_tidy1$MeanDew.PointF)

# Look at histogram for Min.TemperatureF
hist(weather_df_tidy1$Min.TemperatureF)

# Compare to histogram for Mean.TemperatureF
hist(weather_df_tidy1$Mean.TemperatureF)
