import azure.functions as func 
import logging
import json
import pyodbc
import os
from datetime import datetime, timezone
import pytz
from tenacity import retry, stop_after_attempt, wait_fixed, before_log, RetryError

app = func.FunctionApp()

connection_string = os.environ.get("database_connection_str")

# Retry-enabled insert function for each row
@retry(
    stop=stop_after_attempt(5),
    wait=wait_fixed(60),
    before=before_log(logging.getLogger(), logging.INFO),
    reraise=True
)
def insert_into_sql(data, query, values):
    with pyodbc.connect(connection_string) as conn:
        cursor = conn.cursor()
        cursor.execute(query, values)
        conn.commit()
        logging.info(f"[{data.get('symbol', 'UNKNOWN')}] Inserted successfully.")

@app.service_bus_topic_trigger(arg_name="azservicebus", subscription_name="my_assets", topic_name="crypto-assets",
                               connection="servicebusmydev_SERVICEBUS")
def data_processing_function(azservicebus: func.ServiceBusMessage):
    message_body = azservicebus.get_body().decode('utf-8')
    logging.info("ServiceBus message received.")

    try:
        parsed_data = json.loads(message_body)

        # Normalize to list format
        if isinstance(parsed_data, dict):
            data_list = [parsed_data]
        elif isinstance(parsed_data, list):
            data_list = parsed_data
        else:
            logging.error("Unexpected payload structure: not a dict or list.")
            return

        for i, data in enumerate(data_list):
            symbol = data.get("symbol", "UNKNOWN")
            try:
                logging.info(f"Processing row {i + 1}/{len(data_list)}: {symbol}")

                # Remove unused field
                data.pop("ignore", None)

                # Parse and convert time fields
                open_time_utc = datetime.strptime(data["openTime"], "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
                close_time_utc = datetime.strptime(data["closeTime"], "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)

                mst = pytz.timezone("America/Edmonton")
                open_time_mst = open_time_utc.astimezone(mst)
                close_time_mst = close_time_utc.astimezone(mst)
                created_at_mst = datetime.now(mst).replace(tzinfo=None)

                # Add converted timestamps
                data["openTime_UTC"] = open_time_utc.replace(tzinfo=None)
                data["closeTime_UTC"] = close_time_utc.replace(tzinfo=None)
                data["openTime_MST"] = open_time_mst.replace(tzinfo=None)
                data["closeTime_MST"] = close_time_mst.replace(tzinfo=None)
                data["dataWrittenAt_MST"] = created_at_mst

                # Remove old fields
                data.pop("openTime", None)
                data.pop("closeTime", None)

                # SQL insert
                columns = ", ".join(data.keys())
                placeholders = ", ".join(["?"] * len(data))
                values = list(data.values())
                insert_query = f"INSERT INTO dbo.CryptoAssetData ({columns}) VALUES ({placeholders})"

                # Insert the record with retry logic
                insert_into_sql(data, insert_query, values)

            except RetryError:
                logging.error(f"[{symbol}] Retry limit reached. Skipping row {i + 1}.")
            except Exception as row_error:
                logging.error(f"[{symbol}] Unexpected error while processing row {i + 1}: {row_error}")

    except json.JSONDecodeError as json_err:
        logging.error(f"Failed to decode JSON payload: {json_err}")
    except Exception as global_err:
        logging.error(f"Unexpected top-level error: {global_err}")
