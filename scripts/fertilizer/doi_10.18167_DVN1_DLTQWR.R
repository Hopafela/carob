# R script for "carob"


carob_script <- function(path) {

"A set of 87 bibliographic references was collected in order to compare yields in “CT” (conventional tillage) and in “CA” (conservation agriculture) in a meta-analysis, from experiments in Sub-Saharan Africa. Data were collected from 1974 to 2017. We had 1071 observations in total in our file. Six of the crops in the file were subject of the meta-analysis: cotton, cowpea, maize, rice, sorghum and soybean. (2020-06-12)"


	uri <- "doi:10.18167/DVN1/DLTQWR"
	group <- "fertilizer"
	ff <- carobiner::get_data(uri, path, group)

	dset <- data.frame(
		carobiner::read_metadata(uri, path, group, major=1, minor=1),
	   project=NA,
	   publication= "doi:10.1038_s43016-020-0114-x",
	   data_institute = "CIRAD",
	   carob_contributor="Eduardo Garcia Bendito",
	   carob_date="2023-04-20",
	   data_type="compilation"
	)

	f <- ff[basename(ff) == "Donnees_meta-analyse_2020.txt"]

	# Handling unknown-8bit charset
	r <- read.table(f, sep = "\t", quote = "", fileEncoding="latin1")
	colnames(r) <- r[1,]
	r <- r[2:nrow(r),]
  # Reshape dataset to long
	rr <- reshape(r, direction='long', 
	              varying=c('Grain_yield_CT', 'Grain_yield_CA'), 
	              timevar='tillage',
	              times=c('CT', 'CA'),
	              v.names=c('yield'),
	              idvar='observation')

## process file(s)

#### about the data #####

	d <- data.frame("on_farm" = ifelse(rr$Study_type == "on-farm", TRUE, FALSE))
	
	d$trial_id <- paste0(rr$ref)
## the treatment code	
	d$treatment <- paste0("N", ifelse(as.numeric(gsub(",", ".", rr$Applied_N)) > 0, paste0("N", floor(as.numeric(gsub(",", ".", rr$Applied_N)))), 0),
	                      "P", ifelse(as.numeric(gsub(",", ".", rr$Applied_P)) > 0, paste0("P", floor(as.numeric(gsub(",", ".", rr$Applied_P)))), 0),
	                      "K0")


##### Location #####
## make sure that the names are normalized (proper capitalization, spelling, no additional white space).
## you can use carobiner::fix_name()

	rr$Site <- trimws(gsub("\\.", ",", rr$Site))
	d$country <- trimws(gsub(".*,", "", rr$Site))
	d$site <- gsub("(.*),.*", "\\1", rr$Site)
	
	d$elevation <- round(as.numeric(rr$Altitude), 0)
## each site must have corresponding longitude and latitude
	# Process coordinates
	
	crd <- rr$Coordinates
	crd <- gsub("´", "'", crd)
	crd <- gsub("°", "'", crd)
	crd <- gsub("to", "#", crd)
	crd <- gsub("o", "'", crd)
	crd <- gsub("\"", "", crd)
	crd <- gsub("\\?", "'", crd)
	crd <- gsub(";", ", ", crd)
	crd <- gsub("\u0092", "", crd)
	#replace character that may not be visible to you:
	crd <- gsub(" ", "", crd)

	crd <- do.call(rbind, strsplit(crd, ","))
	lat <- data.frame(trimws(stringr::str_split_fixed(crd[,1], "#", 2)))
	i <- which(lat[,2] != "" )
	lat[i,1] <- paste0(lat[i,1], substr(lat[i,2], nchar(lat[i,2]), nchar(lat[i,2])))	
	lon <- data.frame(trimws(stringr::str_split_fixed(crd[,2], "#", 2)))
	i <- which(lon[,2] != "" )
	lon[i,1] <- paste0(lon[i,1], substr(lon[i,2], nchar(lon[i,2]), nchar(lon[i,2])))	

	make_decimal <- function(x) {
		direction <- substr(x, nchar(x), nchar(x))
		x <- trimws(substr(x, 1, nchar(x)-1))
		s <- stringr::str_split_fixed(x, "'", 3)
		s[s[,2] == "", 2] <- 0 
		x <- as.numeric(s[,1]) + as.numeric(s[,2])/60 
		i <- grep("S|W", direction, ignore.case=TRUE)
		x[i] <- -1 * x[i]
		x
	}

	lat[,1] <- make_decimal(lat[,1])
	lat[,2] <- make_decimal(lat[,2])
	d$latitude <- apply(lat, 1, mean, na.rm=TRUE)

	lon[,1] <- make_decimal(lon[,1])
	lon[,2] <- make_decimal(lon[,2])
	d$longitude <- apply(lon, 1, mean, na.rm=TRUE)

#z = data.frame(crd, d$latitude, d$longitude)
	
##### Crop #####
## normalize variety names
	d$crop <- tolower(rr$Crop)
	d$intercrops <- NA
	d$intercrops[grep("hanfets (wheat+barley)", tolower(rr$Crop), fixed = T)] <- "barley"
	d$crop[grep("hanfets (wheat+barley)", tolower(rr$Crop), fixed = T)] <- "wheat"
	d$crop[grep("tef", tolower(rr$Crop), fixed = T)] <- "teff"
	d$crop[grep("millet", tolower(rr$Crop), fixed = T)] <- "pearl millet"
	d$crop[grep("bean", tolower(rr$Crop), fixed = T)] <- "common bean"
	
## EGB
# crop_rotation and intercrops are included but only as binary legume...
	# d$intercrops <- ifelse(rr$Legume_intercropping == "Y", "common bean", NA)
	# d$crop_rotation <- ifelse(rr$Legume_rotation == "Y", "common bean", NA)

##### Time #####
## time can be year (four characters), year-month (7 characters) or date (10 characters).
	year <- substr(gsub("[^0-9.-]", "", rr$Year), 1, 4)
	year[year == ""] <- NA
	d$planting_date <- year
	d$season <- ifelse(grepl("LR", rr$Year), "LR",
                ifelse(grepl("SR", rr$Year), "SR",
                ifelse(grepl("M", rr$Year), "M",
                ifelse(grepl("V", rr$Year), "V",
                ifelse(grepl("masika", rr$Year), "masika",
                ifelse(grepl("vuli", rr$Year), "vuli", NA))))))

##### Fertilizers #####
## note that we use P and K, not P2O5 and K2O
## P <- P2O5 / 2.29
## K <- K2O / 1.2051
   d$P_fertilizer <- as.numeric(gsub(",", ".", rr$Applied_P))
   d$K_fertilizer <- 0
   d$N_fertilizer <- as.numeric(gsub(",", ".", rr$Applied_N))
## normalize names 
   d$fertilizer_type <- "unknown"
   d$inoculated <- FALSE
   
##### Yield #####
	d$yield <- as.numeric(gsub(",", ".", rr$yield))
	#d$crop %in% c("sorghum", "maize", "wheat", "teff", "barley", "pearl millet", "rice")
	d$yield_part <- "grain"
	i <- d$crop %in% c("grass pea", "cowpea", "common bean", "pigeon pea")
	d$yield_part[i] <- "seed"
	d$yield_part[d$crop=="cotton"] <- "fruit"

      
##### Soil #####
   d$soil_type <- tolower(trimws(rr$Soil_NRCS))
   d$soil_SOC <- as.numeric(gsub(",", ".", ifelse(rr$Initial_soil_C == "?", NA, rr$Initial_soil_C)))/10 # g/kg -> %
   
##### Tillage #####   
	tillage <- trimws(tolower(ifelse(rr$tillage == "CT", rr$CT_type, rr$CA_type1)))
	tillage[tillage == "permanent_beds"] <- "permanent beds"
	tillage[tillage == "no-tillage"] <- "none"
	tillage[tillage == "ridge"] <- "ridge tillage"
	tillage[tillage == "plow"] <- "ploughing"
	tillage[tillage == "hoe"] <- "hoeing"
	d$land_prep_method <- tillage

	d <- d[!is.na(d$yield), ] 
	carobiner::write_files(dset, d, path=path)
}
