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

write.csv(rlds$zstore, "rlds_addresses.csv")
write.csv(rlus$zstore, "rlus_addresses.csv")
write.csv(hfss$zstore, "hfss_addresses.csv")
write.csv(rsus$zstore, "rsus_addresses.csv")
write.csv(rsds$zstore, "rsds_addresses.csv")
write.csv(hfls$zstore, "hfls_addresses.csv")
