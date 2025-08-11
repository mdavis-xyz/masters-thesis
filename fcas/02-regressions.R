library(tidyverse)
library(arrow)
#library(tseries)
library(forecast)
#library(corrplot)
#library(caret)
library(jsonlite)
library(sandwich)

# Constants and Config ----

# 5-minute data
#data_path <- "/home/matthew/Data/fcas/combined.parquet"
# SAMPLES_PER_H <- 12

# hourly data

fcas_durations <- c("6SEC", "60SEC", "5MIN")

fcas_duration <- "60SEC"

data_path <- "/home/matthew/Data/fcas/combined-hourly.parquet"
SAMPLES_PER_H <- 1

HOURS_PER_DAY <- 24
DAYS_PER_WEEK <- 7
DAYS_PER_YEAR <- 365

SAMPLES_PER_DAY <- SAMPLES_PER_H * HOURS_PER_DAY
SAMPLES_PER_WEEK <- SAMPLES_PER_H * HOURS_PER_DAY * DAYS_PER_WEEK
SAMPLES_PER_YEAR <- SAMPLES_PER_H * HOURS_PER_DAY * DAYS_PER_YEAR

# Load Data --------

df <- read_parquet(data_path) |>
  arrange(INTERVAL_START) |>
  # normalise MW to GW, to have values closer to 1
  mutate(across(ends_with("_MW") & !all_of("FCAS_MW"), ~ .x / 1000)) |> 
  rename_with(~ str_replace(.x, "_MW$", "_GW"), ends_with("_MW") & !all_of("FCAS_MW"))


# Plot Data -----

plot_df <- df |>
  group_by(FCAS_DURATION) |>
  slice_sample(n = 6000) |> 
  ungroup() |>
  pivot_longer(
    cols = c(TOTAL_GENERATION_GW, GENERATION_EXCL_ROOFTOP_GW),
    names_to = "METRIC",
    values_to = "ENERGY_GW"
  ) |>
  mutate(
    METRIC = recode(METRIC,
                    "GENERATION_EXCL_ROOFTOP_GW" = "Excluding Rooftop PV",
                    "TOTAL_GENERATION_GW" = "Including Rooftop PV"
    ),
    #FCAS_DURATION = factor(FCAS_DURATION, 
    #                       levels = c("1SEC", "6SEC", "60SEC", "5MIN"),
    #                       labels = c("1 Second", "6 Seconds", "60 Seconds", "5 Minutes")
    #)
  )

# 
# plt <- ggplot(aes(x = ENERGY_GW, y = FCAS_MW), data = plot_df) +
#   #geom_point(aes(color = BIGGEST_CONTINGENCY_GW), alpha = 0.05) +
#   geom_jitter(alpha = 0.05, size = 0.1) + # aes(color = BIGGEST_CONTINGENCY_GW)
#   #scale_color_viridis_c(name = "Largest Contingency (GW)") +
#   geom_smooth(method = "lm", se = FALSE) +
#   facet_grid(METRIC ~ FCAS_DURATION) +
#   labs(
#     x = "Energy Quantity (GW)",
#     y = "Raise Demand (MW)"
#   )

plt <- ggplot(aes(x = ENERGY_GW, y = FCAS_MW), data = plot_df |> filter(FCAS_DURATION == fcas_duration)) +
  #geom_point(aes(color = BIGGEST_CONTINGENCY_GW), alpha = 0.05) +
  geom_jitter(alpha = 0.08, size = 0.6) + # aes(color = BIGGEST_CONTINGENCY_GW)
  #scale_color_viridis_c(name = "Largest Contingency (GW)") +
  geom_smooth(method = "lm", se = FALSE) +
  facet_grid(. ~ METRIC) +
  labs(
    x = "Energy Quantity (GW)",
    y = "Raise Demand (MW)"
  )



print(plt)
ggsave(paste0("results/simpson-facet-", fcas_duration, ".svg"), plot = plt, width = 6, height = 3)



df |>
  filter(FCAS_DURATION == fcas_duration) |>
  pull(FCAS_MW) |> 
  ggtsdisplay(main = paste("Original Data", fcas_duration)) 

df |>
  filter(FCAS_DURATION == fcas_duration) |>
  pull(FCAS_MW) |> 
  diff() |> 
  ggtsdisplay(main = paste("First Diff", fcas_duration))

df |>
  filter(FCAS_DURATION == fcas_duration) |>
  pull(FCAS_MW) |> 
  diff(lag=SAMPLES_PER_DAY) |> 
  ggtsdisplay(main =paste("Daily Diff", fcas_duration), lag.max = SAMPLES_PER_WEEK + 1)

df |>
  filter(FCAS_DURATION == fcas_duration) |>
  pull(FCAS_MW) |> 
  diff() |> 
  diff(lag=SAMPLES_PER_DAY) |> 
  ggtsdisplay(main =  paste("Daily Diff of Diff", fcas_duration), lag.max = SAMPLES_PER_WEEK + 1)

# Regressions -----


extract_model_info <- function(model, is_arima = TRUE) {
  coef_summary <- coef(model)
  
  if (is_arima) {
    se <- sqrt(diag(vcov(model)))
    t_stats <- coef_summary / se
    p_values <- 2 * (1 - pnorm(abs(t_stats)))
    order <- arimaorder(model)[1:3]
    seasonal <- arimaorder(model)[4:6]
    period <- arimaorder(model)[7][[1]]
    n_obs <- model$nobs[[1]]
  } else {
    vcov_nw <- NeweyWest(model)
    se <- sqrt(diag(vcov_nw))
    t_stats <- coef_summary / se
    p_values <- 2 * pnorm(abs(t_stats), lower.tail = FALSE)
    order <- c(0, 0, 0)
    seasonal <- c(0, 0, 0)
    period <- c(0)
    n_obs <- nobs(model)
  }
  
  
  list(
    metadata = list(
      fcas_duration = fcas_duration,
      order = order,
      seasonal = seasonal,
      period = period,
      n_obs = n_obs
    ),
    coefficients = data.frame(
      term = names(coef_summary),
      point_estimate = as.numeric(coef_summary),
      std_error = as.numeric(se),
      p_value = as.numeric(p_values),
      stringsAsFactors = FALSE
    )
  )
}


control_sets <- list(
  list(do_naive = TRUE, controls = c("GENERATION_EXCL_ROOFTOP_GW")),
  list(do_naive = TRUE, controls = c("GENERATION_EXCL_ROOFTOP_GW", "ROOFTOP_POWER_GW")),
  list(do_naive = FALSE, controls = c("GENERATION_EXCL_ROOFTOP_GW", "ROOFTOP_POWER_GW", "CONNECTED_INERTIA_GW")), 
  list(do_naive = FALSE, controls = c("GENERATION_EXCL_ROOFTOP_GW", "ROOFTOP_POWER_GW", "CONNECTED_INERTIA_GW", "BIGGEST_CONTINGENCY_GW", "BIGGEST_INTERCONNECTOR_FLOW_GW", "BIGGEST_RUNNING_GEN_GW"))
)

models <- list()
models_data <- list()

for (fcas_duration in fcas_durations) {
  
  
  for (i in 1:length(control_sets)) {
    do_naive <- control_sets[[i]]$do_naive
    current_controls <- control_sets[[i]]$controls
    
    # encode factors/chars as ones-hot
    # convert tibble to matrix
    # minus an intercept (because auto.arima doesn't like an intercept)
    Y <- df |> filter(FCAS_DURATION == fcas_duration) |> pull(FCAS_MW)
    X <- model.matrix(~ . -1, data = df |> filter(FCAS_DURATION == fcas_duration) |> select(all_of(current_controls)))
    
    if (do_naive) {
      # naive regression first
      formula_obj <- reformulate(current_controls, response = "FCAS_MW")
      model <- lm(formula_obj, data = df |> filter(FCAS_DURATION == fcas_duration))
      summary(model)
      checkresiduals(model, main = paste(str(i), "controls", fcas_duration, "duration"))
      models <- c(models, list(model))
      models_data <- c(models_data, list(extract_model_info(model, is_arima = FALSE)))
    }
    
    # now arima

    model <- auto.arima(
      ts(Y, frequency = SAMPLES_PER_DAY),
      ic = "aic",
      d = 1,
      # max.d = 1,
      max.p = SAMPLES_PER_DAY, # AR
      max.q = SAMPLES_PER_DAY, #MA
      D = 1,
      #max.D = 1,
      max.P = 2, #DAYS_PER_WEEK + 1, # seasonal AR
      max.Q =  2, #DAYS_PER_WEEK + 1, # seasonal MA
      seasonal = TRUE,
      xreg = X[, current_controls, drop = FALSE]
    )
    summary(model)
    checkresiduals(model, main = paste(str(i), "controls", fcas_duration, "duration"))
    models <- c(models, list(model))
    models_data <- c(models_data, list(extract_model_info(model)))

  }
}

# Export to JSON
write_json(models_data, "results/regression-results.json", pretty = TRUE, digits = 3)


