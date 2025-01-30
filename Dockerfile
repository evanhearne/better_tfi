# Use official PostgreSQL image
FROM postgres:latest

# Copy initialization SQL script into Docker image
COPY init.sql /docker-entrypoint-initdb.d/init.sql

# Copy the CSV file into the container
COPY assets/csv/stop_times.txt /data/stop_times.txt
COPY assets/csv/trips.txt /data/trips.txt
COPY assets/csv/calendar.txt /data/calendar.txt

# Increase max_wal_size to optimize for bulk inserts
RUN echo "max_wal_size = '3GB'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "checkpoint_timeout = '10min'" >> /usr/share/postgresql/postgresql.conf.sample

# Expose PostgreSQL port
EXPOSE 5432
