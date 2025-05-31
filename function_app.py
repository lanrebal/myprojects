import logging
import os
import azure.functions as func
import requests
import json
from datetime import datetime, timedelta, timezone
from azure.identity import ClientSecretCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.storage.blob import BlobServiceClient

# Suppress unneccesary logs
for logger_name in [
    "uamqp",
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
    "azure.servicebus"
]:
    logging.getLogger(logger_name).setLevel(logging.WARNING)

logging.basicConfig(level=logging.INFO)

app = func.FunctionApp()

@app.timer_trigger(schedule="0 0 * * * *", arg_name="myTimer", run_on_startup=False, use_monitor=False) 
def hourly_trigger_function(myTimer: func.TimerRequest) -> None:
    if myTimer.past_due:
        logging.info("The timer is past due!")

    symbols = ["XRPUSDT", "BTCUSDT", "VETUSDT", "DOGEUSDT"]

    now = datetime.now(timezone.utc)
    last_full_hour = now.replace(minute=0, second=0, microsecond=0) - timedelta(hours=1)
    hour_suffix = last_full_hour.strftime("%Hhr_utc")

    for symbol in symbols:
        data = fetch_hourly_kline(symbol)
        if data:
            label = f"{symbol}_{hour_suffix}"

            if not send_to_service_bus(data):
                logging.info(f"{label} data failed to send to Service Bus.")

            if not upload_to_data_lake(data):
                logging.info(f"{label} data failed to upload to Data Lake.")
        else:
            logging.info(f"No {symbol} data available to process.")

# Service Principal Credentials
TENANT_ID = os.environ["TENANT_ID"]
CLIENT_ID = os.environ["CLIENT_ID"]
CLIENT_SECRET = os.environ["CLIENT_SECRET"]

# Service Bus
NAMESPACE = os.environ.get("NAMESPACE")
TOPIC_NAME = os.environ.get("TOPIC_NAME")

# Data Lake Storage
STORAGE_ACCOUNT_NAME = "cryptoassets"
CONTAINER_NAME = "my-assets"

def to_utc_datetime(ms):
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc)

def format_timestamp(ms):
    return to_utc_datetime(ms).strftime("%Y-%m-%d %H:%M:%S")

def split_symbol(symbol):
    if symbol.endswith("USDT"):
        return symbol.replace("USDT", ""), "USDT"
    return symbol[:3], symbol[3:]

def fetch_hourly_kline(symbol):
    url = f"https://api.binance.com/api/v3/klines?symbol={symbol}&interval=1h&limit=5"
    response = requests.get(url)

    if response.status_code != 200:
        logging.error(f"Error fetching {symbol} data: {response.status_code}")
        return None

    data = response.json()
    if not data:
        logging.error(f"No {symbol} kline data received.")
        return None

    now_utc = datetime.now(timezone.utc)
    latest_full_hour = now_utc.replace(minute=0, second=0, microsecond=0) - timedelta(hours=1)

    for kline in data:
        kline_open_time = to_utc_datetime(kline[0])
        if kline_open_time == latest_full_hour:
            base_asset, quote_asset = split_symbol(symbol)
            return {
                "symbol": symbol,
                "baseAsset": base_asset,
                "quoteAsset": quote_asset,
                "openTime": format_timestamp(kline[0]),
                "openPrice": kline[1],
                "highPrice": kline[2],
                "lowPrice": kline[3],
                "closePrice": kline[4],
                "volume": kline[5],
                "closeTime": format_timestamp(kline[6]),
                "quoteAssetVolume": kline[7],
                "numberOfTrades": kline[8],
                "takerBuyBaseAssetVolume": kline[9],
                "takerBuyQuoteAssetVolume": kline[10],
                "ignore": kline[11]
            }

    logging.error(f"No matching {symbol} kline for expected time: {latest_full_hour}")
    return None

def send_to_service_bus(payload):
    try:
        credential = ClientSecretCredential(TENANT_ID, CLIENT_ID, CLIENT_SECRET)
        servicebus_client = ServiceBusClient(
            fully_qualified_namespace=NAMESPACE,
            credential=credential,
            logging_enable=False
        )

        with servicebus_client:
            sender = servicebus_client.get_topic_sender(topic_name=TOPIC_NAME)
            with sender:
                message = ServiceBusMessage(json.dumps(payload))
                sender.send_messages(message)
                logging.info(f"[ServiceBus] Message for {payload.get('symbol')} sent successfully.")
        return True
    except Exception as e:
        logging.error(f"[ServiceBus] Failed to send message for {payload.get('symbol')}: {e}")
        return False

def upload_to_data_lake(payload):
    try:
        credential = ClientSecretCredential(TENANT_ID, CLIENT_ID, CLIENT_SECRET)
        blob_service_client = BlobServiceClient(
            account_url=f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net",
            credential=credential
        )
        container_client = blob_service_client.get_container_client(CONTAINER_NAME)

        now = datetime.now(timezone.utc)
        last_full_hour = now.replace(minute=0, second=0, microsecond=0) - timedelta(hours=1)

        symbol_prefix = payload.get("symbol", "UNKNOWN").lower().replace("usdt", "")
        timestamp_str = last_full_hour.strftime("%Y%m%d_%Hhr")
        blob_name = f"{symbol_prefix}_hourly_data_{timestamp_str}.json"

        blob_client = container_client.get_blob_client(blob_name)
        blob_client.upload_blob(data=json.dumps(payload), overwrite=True)
        logging.info(f"[DataLake] Data for {payload.get('symbol')} uploaded successfully.")
        return True
    except Exception as e:
        logging.error(f"[DataLake] Failed to upload data for {payload.get('symbol')}: {e}")
        return False
