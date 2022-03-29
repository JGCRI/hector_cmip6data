path_name = 'C:/land-ocean-warming-ratio'
ratio_file_name = 'ratio_cleaned_1pctCO2_temp.csv'

numRuns = 5000

ratio_data <- read.csv(file = file.path(path_name, ratio_file_name), stringsAsFactors = FALSE)
mean <- mean(ratio_data$Ratio)
sd <- sd(ratio_data$Ratio)

ran_dist <- rnorm(numRuns, mean, sd)