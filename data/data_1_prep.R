#'//////////////////////////////////////////////////////////////////////////////
#' FILE: data_1_prep.R
#' AUTHOR: David Ruvolo
#' CREATED: 2020-02-12
#' MODIFIED: 2020-03-04
#' PURPOSE: prepare data into viz ready objects
#' STATUS: complete; working;
#' PACKAGES: tidyverse
#' COMMENTS: NA
#'//////////////////////////////////////////////////////////////////////////////
options(stringsAsFactors = FALSE)

# pkgs
suppressPackageStartupMessages(library(tidyverse))


#'//////////////////////////////////////////////////////////////////////////////

#' ~ 0 ~
#' Reduce Data
#' In this section, identify duplicate entries and remove them. Load datasets
breweries <- readRDS("data/downloads/breweries_all_cities.RDS")
coffee <- readRDS("data/downloads/coffee_all_cafes.RDS")
museum <- readRDS("data/downloads/museums_all_cities.RDS")

#'//////////////////////////////////////

#' ~ A ~
#' Check Breweries Dataset

#' ~ a ~
# check missing values
#' At this point, the number of breweries is around 4k. Let's check the missing
#' variables.
sapply(seq_len(NCOL(breweries)), function(col) {
    list(
        name = names(breweries[col]),
        missing = NROW(breweries[is.na(breweries[, col]) == TRUE, ]),
        percent = round(
            (
                NROW(breweries[is.na(breweries[, col]) == TRUE, ]) /
                NROW(breweries) * 100
            ),
            2
        )
    )
})


#' ~ b ~
#' check unique entries
breweries$duplicated <- as.character(
    sapply(seq_len(NROW(breweries$id)), function(x) {
        result <- breweries$id[breweries$id == breweries$id[x]]
        if (length(result) > 1) {
            return(TRUE)
        } else {
            return(FALSE)
        }
    })
)

#' Check a few cases where there's a duplicated id
breweries %>% filter(duplicated == TRUE) %>% head()
breweries %>% filter(id == "1502898997")

#' Since there are multiple entries for a location, use coordinates to reduce
#' the dataset down to unique breweries only.
breweries <- breweries %>%
    distinct(id, lat, lon, .keep_all = TRUE) %>%
    select(-duplicated)

# Double check ids and rows. These should match. If the numbers do not match,
# continue to evaluate the breweries by id and coordinates. It is likely that
# some breweries have multiple locations. However, this should be addressed by
# id. The cases in this dataset a result of multiple entries of the same place,
# but with two different addresses; more often it was the city that was
# different. If all of the coordinates, ids, and place names are the same, then
# take any distinct value.
NROW(breweries)
length(unique(breweries$id))

#'//////////////////////////////////////

#' ~ B ~
#' Check Coffee Dataset

#' ~ a ~
#' Find missing values
sapply(seq_len(NCOL(coffee)), function(col) {
    list(
        name = names(coffee[col]),
        missing = NROW(coffee[is.na(coffee[, col]) == TRUE, ]),
        blank = NROW(coffee[coffee[, col] == "", ]),
        percent = round(
            (
                NROW(coffee[is.na(coffee[, col]) == TRUE, ]) /
                NROW(coffee) * 100
            ),
            2
        )
    )
})

#' There is one instance where the name was blank. I'm pretty sure this was
#' handled in the early scripts, but perhaps it didn't get saved. Since there
#' is only one case, I will update it manually.

#' Filter dataset for the case with the blank city
coffee %>% filter(city == "")

#' The cafe id is cafe_585 Wldkaffee Rosterie. Use the link provided to find
#' the city and other information
coffee$city[coffee$cafeId == "cafe_585"] <- "Garmisch-Partenkirchen"
coffee$address[coffee$cafeId == "cafe_585"] <- "Bahnhofstr. 8, 82467, Garmisch-Partenkirchen, Germany"
coffee$lat[coffee$cafeId == "cafe_585"] <- 47.493381500
coffee$lng[coffee$cafeId == "cafe_585"] <- 11.103316307
coffee$website[coffee$cafeId == "cafe_585"] <- "https://www.wild-kaffee.de"
coffee$user_ratings_total[coffee$cafeId == "cafe_585"] <- 88
coffee$rating[coffee$cafeId == "cafe_585"] <- 4.8

# View entry
coffee[coffee$cafeId == "cafe_585", ]

#' Recode Cafe in Antwerp that is incorrectly coded as Netherlands
coffee$country[coffee$cafeId == "cafe_1197"] <- "Belgium"
coffee$address[coffee$cafeId == "cafe_1197"] <- "Lange Klarenstraat 14 2000  Antwerp Belgium"


#'//////////////////////////////////////

#' Reduce the Museums Dataset
#' It's impossible to submit the dataset with names missing. I cannot add cases
#' if the name does not exist as it is impossible to verify it's existence.
#' Despite the significant loss of data, I'd rather have cases with a valid
#' name than pure numbers. This is a real life example of the issues that are
#' mentioned in the OSM blog post.
#' https://blog.emacsen.net/blog/2018/02/16/osm-is-in-trouble/

museum <- museum %>% filter(!is.na(name))


dim(museum) #' Ouch, this hurts!

#'//////////////////////////////////////

#' ~ c ~
#' Merge Datasets
#' Here, I will merge the two datasets in order to create a summary dataset.
#' The full datasets will be saved for use in the maps, but here I want
#' to reduce the datasets to merge and summarize. Since coffee is the primary
#' focus, I will save ratings data and remove everything else. Corresponding
#' columns will need to be created in the breweries dataset; make sure these
#' receive NA values. From both dadtasets, I am interested in the following
#' variables.
#'
#'      - City
#'      - Country
#'      - Name
#'      - Coordinates (Lat, Long)
#'      - id (i.e., osm id and place_id or cafeID)
#'      - Ratings: user_ratings_total and rating
#'      - Price: price_level
#'
#' Reduce the datasets using the columns above. Also add columns so the struct-
#' ures are the same. Rename and reorder columns


#' reduce breweries and add columns to match the structure of the coffee data
brew <- breweries %>%
    select(
        city,
        country,
        id,
        name,
        lat,
        lon
    ) %>%
    mutate(
        user_ratings_total = NA,
        rating = NA,
        price_level = NA,
        type = "brewery"
    )

#' reduce coffee and add columns to match the structure of the breweries data
cafes <- coffee %>%
    select(
        city,
        country,
        id = cafeId,
        name,
        lat,
        lon = lng,
        user_ratings_total,
        rating,
        price_level
    ) %>%
    mutate(
        type = "cafe"
    )

#' reduce museums data and add columns to match the structure of the other data
museums <- museum %>%
    mutate(
        user_ratings_total = NA,
        rating = NA,
        price_level = NA,
        type = "museum",
        name = trimws(
            stringr::str_replace(name, ",", " "),
            "both"
        )
    ) %>%
    select(
        city,
        country,
        id,
        name,
        lat,
        lon,
        user_ratings_total,
        rating,
        price_level,
        type
    )

#' Merge datasets - bind rows
places <- rbind(brew, cafes, museums) %>%
    arrange(city, country, name, type) %>%
    distinct(id, .keep_all = TRUE)

#'//////////////////////////////////////////////////////////////////////////////

#' ~ 1 ~
#' Summarize Data
#' In this section, create an object that contains summarized data that will be
#' used in the data viz. The cleaned datasets (i.e., coffee and breweries) will
#' be saved and used in the interactive map.


#' Create summary object
travel <- list()
travel$highlights <- list()
travel$descriptives <- list()
travel$summary <- list()

#' ~ a ~
#' Find the total number of countries
travel$highlights$countries <- places %>%
    distinct(country) %>%
    count() %>%
    pull()

#' ~ b ~
#' Find the total number of cities
travel$highlights$cities <- places %>%
    distinct(city) %>%
    count() %>%
    pull()

#' ~ c ~
#' Find the total number of places
travel$highlights$places <- places %>%
    distinct(id) %>%
    count() %>%
    pull()

#' ~ d ~
#' Find the total number of cafes
travel$highlights$cafes <- places %>%
    filter(type == "cafe") %>%
    distinct(id) %>%
    count() %>%
    pull()

#' ~ e ~
#' Find the total number of breweries
travel$highlights$breweries <- places %>%
    filter(type == "brewery") %>%
    distinct(id) %>%
    count() %>%
    pull()

#' ~ f ~
#' Find the total number of museums
travel$highlights$museums <- places %>%
    filter(type == "museum") %>%
    distinct(id) %>%
    count() %>%
    pull()

#' Check to see if the breweries and cafes count equal the NCOL
travel$highlights$places == NROW(places)
sum(
    travel$highlights$breweries,
    travel$highlights$cafes,
    travel$highlights$museums
) == NROW(places)


#' Create an Object with all highlights collapsed into a data.frame
travel$highlights$all <- travel$highlights %>%
        as.data.frame() %>%
        rename(
            Breweries = breweries,
            Cafes = cafes,
            Cities = cities,
            Countries = countries,
            Museums = museums,
            Total = places
        ) %>%
        pivot_longer(everything(), "name") %>%
        mutate(
            name = factor(
                name,
                c(
                    "Countries", "Cities",
                    "Cafes", "Breweries", "Museums",
                    "Total"
                )
            )
        ) %>%
        arrange(name) %>%
        as.data.frame()


#' ~ g ~
#' Descriptives: Places by City
#' (I don't know if this will be helpful)
travel$descriptives$places_by_city <- places %>%
    group_by(city, country, type) %>%
    summarize(
        n = n()
    ) %>%

    #' Calcuate the total number of places in each city
    #' This says, In Vienna there are n places. Where n is
    #' the total cafes, breweries, and museums.
    left_join(
        places %>%
            group_by(city) %>%
            summarize(
                tot_city_places = length(unique(id))
            ),
        by = "city"
    ) %>%

    #' Calcuate the total number of places in each country.
    #' This says: In Austria, there n cafes, n breweries, and
    #' n musuems. This allows me to calcuate the rate of place type
    #' of a city in comparison to the country level.
    left_join(
        places %>%
            group_by(country) %>%
            summarize(
                tot_country_places = length(unique(id))
            ),
        by = "country"
    ) %>%

    #' Calcuate the total number of place type (entire dataset)
    #' This says: in the entire dataset, how returns the total number
    #' of cafes, museums, and breweries
    left_join(
        places %>%
            group_by(type) %>%
            summarize(
                global_type_places = length(unique(id))
            ),
        by = "type"
    ) %>%
    mutate(
        city_rate = n / tot_city_places,
        country_rate = n / tot_country_places,
        type_rate_global = n / global_type_places
    )


#' ~ h ~
#' Descriptives: Places by Country
#' (I don't know if this will be helpful)
travel$descriptives$places_by_country <- places %>%
    group_by(country, type) %>%
    summarize(
        n = n(),
    ) %>%
    left_join(
        places %>%
            group_by(country) %>%
            summarize(
                places_country = length(unique(id))
            ),
        by = "country"
    ) %>%
    left_join(
        places %>%
            group_by(type) %>%
            summarize(
                places_type = length(unique(id))
            ),
        by = "type"
    ) %>%
    mutate(
        rate_country = n / places_country,
        rate_type = n / places_type
    )

#' ~ i ~
#' Summaries: coffee and breweries by country
#' travel$summary$places_by_country <- places %>%
#'     group_by(country, type) %>%
#'     summarize(
#'         cities = length(unique(city)),
#'         places = length(unique(id)),
#'         user_ratings_mean = mean(user_ratings_total, na.rm = TRUE),
#'         user_ratings_total = sum(user_ratings_total, na.rm = TRUE),
#'         rating_avg = mean(rating, na.rm = TRUE),
#'         rading_sd = sd(rating, na.rm = TRUE),
#'         price_level = median(price_level, na.rm = TRUE)
#'     ) %>%
#'     arrange(country, type)

#' ~ j ~
#' Summary: coffe and breweries by city
#' travel$summary$places_by_city <- places %>%
#'     group_by(city, country, type) %>%
#'     summarize(
#'         cities = length(unique(city)),
#'         places = length(unique(id)),
#'         user_ratings_mean = mean(user_ratings_total, na.rm = TRUE),
#'         user_ratings_total = sum(user_ratings_total, na.rm = TRUE),
#'         rating_avg = mean(rating, na.rm = TRUE),
#'         rading_sd = sd(rating, na.rm = TRUE),
#'         price_level = median(price_level, na.rm = TRUE)
#'     ) %>%
#'     ungroup() %>%
#'     arrange(country, city, type)

#'//////////////////////////////////////////////////////////////////////////////

#' ~ 2 ~
#' Create Master List of All Cities Geocoded

#' Load data
geo <- readRDS("data/downloads/cafe_cities_geocoded.RDS")

#' Add IDs
geo <- geo %>%
    rowid_to_column("id") %>%
    mutate(
        id = as.character(id)
    )


#'//////////////////////////////////////////////////////////////////////////////

#' ~ 3 ~
#' Create Travel Recommendations objects


#' Wide (for use in user preferences function)
recs_wide <- travel$descriptives$places_by_city %>%
    select(city, country, type, n, "tot_n" = tot_city_places) %>%
    pivot_wider(
        names_from = type,
        values_from = n,
        values_fill = list(n = 0)
    ) %>%
    left_join(
        geo %>%
            select(id, city, lat, lng),
        by = "city"
    ) %>%
    select(id, city, country, lat, lng, everything()) %>%
    as.data.frame()

#' Long (for use in visualisations)
#' use wide as missing cases are already filled and geo data is merged
recs_long <- recs_wide %>%
    select(id, tot_n, brewery, cafe, museum) %>%
    group_by(id) %>%
    pivot_longer(
        c(brewery, cafe, museum),
        names_to = "place",
        values_to = "n"
    ) %>%
    left_join(
        geo %>%
            select(id, city, country, lat, lng),
        by = "id"
    ) %>%
    mutate(
        rate = round((n / tot_n) * 100, 2)
    ) %>%
    select(
        id,
        city,
        country,
        lat,
        lng,
        place,
        "count" = n,
        rate,
        "total" = tot_n
    ) %>%
    as.data.frame(.)

#'//////////////////////////////////////////////////////////////////////////////

#' ~ 3 ~
#' Create GEOJSON object for use in the mapbox

#' remove missing cases
map_data <- places %>%
    filter(!is.na(lat)) %>%
    select(id, city, country, name, lat, lon, type)

#' define parent object
json <- list(
    type = "FeatureCollection",
    totalFeatures = length(unique(map_data$id)),
    features = list()
)

#' fill in geometry
x <- 1
max.reps <- NROW(map_data)
while (x <= max.reps) {
    json$features[[x]] <- list(
        type = "Feature",
        id = map_data$id[x],
        geometry = list(
            type = "Point",
            coordinates = list(
                map_data$lon[x],
                map_data$lat[x]
            )
        ),
        properties = list(
            id = map_data$id[x],
            name = map_data$name[x],
            city = map_data$city[x],
            country = map_data$country[x],
            place = map_data$type[x],
            lat = map_data$lat[x],
            lon = map_data$lon[x]
        )
    )
    # update counter
    x <- x + 1
}


#'//////////////////////////////////////////////////////////////////////////////

#' ~ 4 ~
# save all objects

#' Save Individual Place Type Objects
saveRDS(brew, "data/all_european_breweries.RDS")
saveRDS(cafes, "data/all_european_coffee.RDS")
saveRDS(museums, "data/all_european_museums.RDS")

#' Save Summarized Data For Viz and User Preferences Function
saveRDS(recs_wide, "data/travel_summary_userprefs.RDS")  # use for user preferences
saveRDS(recs_long, "data/travel_summary_general.RDS")    # use for visualisations

#' Save All Geodata
saveRDS(geo, "data/travel_all_cities_geocoded.RDS")

#' Save GEOjson
j <- jsonlite::toJSON(json)
write(j, "www/data/travel.geojson")