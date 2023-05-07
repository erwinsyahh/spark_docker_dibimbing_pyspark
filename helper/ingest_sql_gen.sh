#!/bin/bash

cat <<EOF >./challenge_sql/ingest.sql
COPY employees FROM '$1' DELIMITER AS ',' CSV HEADER;
SELECT * FROM employees LIMIT 5;

COPY timesheets FROM '$2' DELIMITER AS ',' CSV HEADER;
SELECT * FROM timesheets LIMIT 5;
EOF