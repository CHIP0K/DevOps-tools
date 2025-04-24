# Before running the script, make sure to install the required packages:
# pip install redis
# pip install threading

import redis
import threading
import logging
import os

# Logging configuration
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

# Redis configuration
redis_host = os.getenv("REDIS_HOST", "127.0.0.1")
redis_port = int(os.getenv("REDIS_PORT", 6379))
redis_db = int(os.getenv("REDIS_DB", 0))
redis_password = os.getenv("REDIS_PASSWORD", "your_requirepass")
count_chunk_size = 100
ttl_seconds = 120 * 60

# Redis connection
r = redis.Redis(host=redis_host, port=redis_port, db=redis_db, password=redis_password)

def set_ttl(keys):
    try:
        for key in keys:
            r.expire(key, ttl_seconds)
        logging.info(f"TTL for {len(keys)} keys has been set.")
    except Exception as e:
        logging.error(f"Error setting TTL: {e}")

def main():
    try:
        # Use SCAN instead of KEYS
        keys = []
        cursor = "0"
        while cursor != 0:
            cursor, batch = r.scan(cursor=cursor, match="*", count=1000)
            keys.extend(batch)

        # Split keys into chunks
        key_chunks = [keys[i:i + count_chunk_size] for i in range(0, len(keys), count_chunk_size)]

        # Create threads for each chunk
        threads = []
        for chunk in key_chunks:
            thread = threading.Thread(target=set_ttl, args=(chunk,))
            threads.append(thread)
            thread.start()

        # Wait for all threads to finish
        for thread in threads:
            thread.join()

        logging.info("All threads have finished.")
    except Exception as e:
        logging.error(f"Error in main: {e}")

if __name__ == "__main__":
    main()