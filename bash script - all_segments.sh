#!/bin/bash

# Function for Segment 1: Create Database, Create Staging Table, Load CSV into Staging Table
run_segment_1() {
  echo "Running Segment 1: Create Database, Create Staging Table, Load CSV into Staging Table - trading_data_staging"

  # Check if the database exists, and if not, create it
  DB_EXISTS=$(psql -U postgres -h localhost -p 5433 -tAc "SELECT 1 FROM pg_database WHERE datname='lanre_db'")
  if [ "$DB_EXISTS" != "1" ]; then
    echo "Database lanre_db does not exist. Creating lanre_db..."
    psql -U postgres -h localhost -p 5433 -c "CREATE DATABASE lanre_db;"
  else
    echo "Database lanre_db already exists. Skipping creation."
  fi

  # Connect to the database, create the staging table, load data, and verify the data load
  psql -U postgres -h localhost -p 5433 -d lanre_db <<EOF

  -- Create the staging table
  CREATE TABLE IF NOT EXISTS public.trading_data_staging (
      Open_Time TIMESTAMP,
      Open FLOAT,
      High FLOAT,
      Low FLOAT,
      Close FLOAT,
      Volume FLOAT,
      Close_Time TIMESTAMP,
      Quote_Asset_Volume FLOAT,
      Number_Of_Trades INT,
      Taker_Buy_Base_Asset_Volume FLOAT,
      Taker_Buy_Quote_Asset_Volume FLOAT,
      Ignore_column INT
  );

  -- Load data from the CSV file into the staging table
  \copy trading_data_staging FROM 'C:/half2_BTCUSDT_1s.csv' CSV HEADER;

  -- Verify the data load by displaying the first 5 rows
  SELECT * FROM trading_data_staging LIMIT 5;

EOF
}

# Function for Segment 2: Run dbt Model to load table - trading_hourly_data
run_segment_2() {
  echo "Running Segment 2: Run dbt Model to load table - trading_hourly_data"

  # Navigate to the dbt project directory and run the dbt model
  DBT_PROJECT_DIR="/c/dbt_projects_Lanre/Lanre_project"
  cd $DBT_PROJECT_DIR

  echo "Running dbt model to materialize table..."
  dbt run --select trading_hourly_data

  # Notification after dbt completion
  echo "DBT model 'trading_hourly_data' has been materialized as a table."

  # Running tests on the model to validate the data
  echo "Running dbt tests on trading_hourly_data..."
  dbt test --select trading_hourly_data

  # Query the top 5 rows from trading_hourly_data
  echo "Querying the top 5 rows from trading_hourly_data..."
  psql -U postgres -h localhost -p 5433 -d lanre_db -c "SELECT * FROM trading_hourly_data LIMIT 5;"
}

# Function for Segment 3: Run Trading Data Analysis to load table - trading_data_analysis
run_segment_3() {
  echo "Running Segment 3: Run Trading Data Analysis to load table - trading_data_analysis"

  # Ask user for input to run the trading analysis
  # Available day range information 
  echo "Available day is from '2021-02-23'  to '2024-08-27'"
  echo "You can provide a single date (e.g., 2021-02-24), multiple dates (e.g., 2021-02-24,2021-02-25), or a date range (e.g., 2021-01-01 to 2021-01-05). You can also type 'ALL' in CAPS for all dates."

  # Prompt the user for the date range or option for all dates
  read -p "Enter the day(s) or date range: " day_input

  # Show available hour options
  echo "Available hours: 0 to 23"
  echo "You can provide a single hour (e.g., 7), multiple hours (e.g., 7,8,9), or a range of hours (e.g., 5 to 9). You can also type 'ALL' in CAPS for all hours."

  # Prompt the user for the hours they want to filter 
  read -p "Enter the hour(s) or hour range: " hours_input

  
  # Handle date condition
  if [[ "$day_input" == "ALL" ]]; then
      day_condition="TRUE"  # This will match all dates
  elif [[ "$day_input" =~ to ]]; then
      # Handle date range input
      start_date=$(echo $day_input | cut -d' ' -f1)
      end_date=$(echo $day_input | cut -d' ' -f3)
      day_condition="day BETWEEN '$start_date' AND '$end_date'"
  else
      # Handle comma-separated dates 
      day_input=$(echo $day_input | sed "s/,/','/g")
      day_condition="day IN ('$day_input')"  # Match specific dates or multiple dates
  fi

  # Handle hour condition
  if [[ "$hours_input" == "ALL" ]]; then
      hours_condition="TRUE"  # This will match all hours
  elif [[ "$hours_input" =~ to ]]; then
      # Handle hour range input
      start_hour=$(echo $hours_input | cut -d' ' -f1)
      end_hour=$(echo $hours_input | cut -d' ' -f3)
      hours_condition="hour BETWEEN $start_hour AND $end_hour"
  else
      # Handle comma seperated hours
      hours_condition="hour IN ($hours_input)"
  fi

  # Run the trading data analysis with user-defined filters
  psql -U postgres -h localhost -p 5433 -d lanre_db <<EOF

  -- Drop the table if it exists  
  DROP TABLE IF EXISTS trading_data_analysis;

  -- Create a new table to store the result
  CREATE TABLE trading_data_analysis AS
  SELECT
      ROW_NUMBER() OVER (ORDER BY day, hour) AS trading_no,
      day,
      hour,
      open_price_for_hour,
      close_price_for_hour,
      first_time_for_hour,
      last_time_for_hour,
      hour_details,
      0.0::double precision AS amount_invested,
      0.0::double precision AS unit_purchased,
      0.0::double precision AS amount_when_sold,
      0.0::double precision AS gain_loss  
  FROM trading_hourly_data
  WHERE $day_condition
  AND $hours_condition
  ORDER BY hour;

  -- Create the PL/pgSQL function to update the rows sequentially
  DO \$\$
  DECLARE
      r RECORD;
      previous_amount_when_sold DOUBLE PRECISION := 0;
  BEGIN
      -- Loop through each row in trading_data_analysis
      FOR r IN
          SELECT * FROM trading_data_analysis ORDER BY trading_no
      LOOP
          -- For the first row, set amount_invested to open_price_for_hour
          IF r.trading_no = 1 THEN
              UPDATE trading_data_analysis
              SET amount_invested = open_price_for_hour,
                  unit_purchased = 1.0,
                  amount_when_sold = close_price_for_hour,
                  gain_loss = (close_price_for_hour - open_price_for_hour)
              WHERE trading_no = r.trading_no;

              -- Save the first row's amount_when_sold for the next iteration
              previous_amount_when_sold := r.close_price_for_hour;

          -- For subsequent rows, use the previous row's amount_when_sold
          ELSE
              UPDATE trading_data_analysis
              SET amount_invested = previous_amount_when_sold,
                  unit_purchased = previous_amount_when_sold / r.open_price_for_hour,
                  amount_when_sold = (previous_amount_when_sold / r.open_price_for_hour) * r.close_price_for_hour,
                  gain_loss = ((previous_amount_when_sold / r.open_price_for_hour) * r.close_price_for_hour) - previous_amount_when_sold 
              WHERE trading_no = r.trading_no;

              -- Update the value of previous_amount_when_sold for the next row
              previous_amount_when_sold := (previous_amount_when_sold / r.open_price_for_hour) * r.close_price_for_hour;
          END IF;
      END LOOP;
  END \$\$;

  -- Query the updated results from the table
  SELECT 
      day,
      hour,
      hour_details,
      first_time_for_hour::timestamp AS first_time_for_hour,
      open_price_for_hour,
      last_time_for_hour::timestamp AS last_time_for_hour,
      close_price_for_hour,
      trading_no,
      amount_invested,
      unit_purchased,
      amount_when_sold,
      gain_loss  -- Include gain_loss in the output
  FROM trading_data_analysis
  ORDER BY trading_no
  LIMIT 5;

EOF

  # Notify user that the analysis is completed
  echo "Analysis completed. The data for day(s) $day_input and hours $hours_input has been processed.Limit of 5 Rows can be shown, see trading_data_analysis table for full data."
}

# Ask the user which segment to run
echo "Select which segment you want to run:"
echo "1. Run Segment 1 (Create Database, Create Staging Table, Load CSV into Staging Table - trading_data_staging)"
echo "2. Run Segment 2 (Run dbt Model to load table - trading_hourly_data)"
echo "3. Run Segment 3 (Run Trading Data Analysis to load table - trading_data_analysis)"
echo "4. Run All Segments"
read -p "Enter your choice (1, 2, 3, or 4): " user_choice

# Execute based on the user's choice
case $user_choice in
  1)
    run_segment_1
    ;;
  2)
    run_segment_2
    ;;
  3)
    run_segment_3
    ;;
  4)
    run_segment_1
    run_segment_2
    run_segment_3
    ;;
  *)
    echo "Invalid option selected. Exiting."
    exit 1
    ;;
esac

