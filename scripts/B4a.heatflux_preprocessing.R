library(dplyr)

# Import data
data <- read.csv("heatflux_test.csv")

# Check that each name has six unique variable_id
test <- data
test <- test %>%
  group_by(name) %>%
  mutate(check = length(variable_id))

test_six <- slice(test[which(test$check == 6),])
test_notsix <- slice(test[which(test$check != 6),])

rlds <- test_six %>% filter(variable_id == "rlds")
rlus <- test_six %>% filter(variable_id == "rlus")
hfss <- test_six %>% filter(variable_id == "hfss")
rsus <- test_six %>% filter(variable_id == "rsus")
rsds <- test_six %>% filter(variable_id == "rsds")
hfls <- test_six %>% filter(variable_id == "hfls")

# Pull out zstore addresses for names with all six variables
# To be used in Python script
write.csv(rlds$zstore, "./inputs/rlds_addresses.csv")
write.csv(rlus$zstore, "./inputs/rlus_addresses.csv")
write.csv(hfss$zstore, "./inputs/hfss_addresses.csv")
write.csv(rsus$zstore, "./inputs/rsus_addresses.csv")
write.csv(rsds$zstore, "./inputs/rsds_addresses.csv")
write.csv(hfls$zstore, "./inputs/hfls_addresses.csv")
