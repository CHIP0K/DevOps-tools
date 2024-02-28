# Before running the script, make sure to install the required packages:
# pip install redis
# pip install threading

import redis
import threading

redis_host = '127.0.0.1'  # Redis server address
redis_port = 6379  # Redis server port
redis_db = 0  # Redis server db
redis_password = 'your_requirepass'  # Redis server requirepass
count_chunk_size = 100  # Number of chunks to split keys into
ttl_seconds = 120 * 60  # TTL in seconds

r = redis.Redis(host=redis_host,
                port=redis_port,
                db=redis_db,
                password=redis_password)

keys = r.keys("binom_click_id*") # Get all keys from Redis

def set_ttl(keys):
    for key in keys:
        r.expire(key, ttl_seconds)
        # print(f"TTL for {key} has been set.") # Uncomment this line to see the progress
    print(f"TTL for {len(keys)} keys has been set.")

def main():
    # Split keys into chunks
    chunk_size = len(keys) // count_chunk_size
    key_chunks = [keys[i:i + chunk_size] for i in range(0, len(keys), chunk_size)]

    # Create threads for each chunk
    threads = []
    for chunk in key_chunks:
        thread = threading.Thread(target=set_ttl, args=(chunk,))
        threads.append(thread)
        thread.start()

    # Wait for all threads to finish
    for thread in threads:
        thread.join()

    print("All threads have finished.")


if __name__ == "__main__":
    main()