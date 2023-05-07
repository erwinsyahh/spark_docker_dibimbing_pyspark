include .env
export

CURRENT_DATE := $(shell date +'%Y-%m-%d')
JDBC_URL := "jdbc:postgresql://${DIBIMBING_DE_POSTGRES_HOST}/${DIBIMBING_DE_POSTGRES_DB}"
JDBC_PROPERTIES := '{"user": "${DIBIMBING_DE_POSTGRES_ACCOUNT}", "password": "${DIBIMBING_DE_POSTGRES_PASSWORD}", "driver": "${DIBIMBING_DE_SPARK_DRIVER}", "stringtype": "${DIBIMBING_DE_SPARK_STRINGTYPE}"}'

help:
	@echo "## postgres			- Run a Postgres container, including its inter-container network. \n"
	@echo "## spark			- Run a Spark cluster, rebuild the postgres container, then create the destination tables \n"
	@echo "## spark-help			- Show the script argument documentations.\n"
	@echo "## challenge-sql-a		- Build the postgres image and containers, create the tables, and ingest the csv.\n"
	@echo "## challenge-sql-b		- Will do the challenge_sql_a, then truncate and insert the hourly average salary data.\n"
	@echo "## challenge-sql-test		- Show all hourly average salary data directly from database.\n"
	@echo "## challenge-spark-a		- Build both postgres and spark images and containers,ccreate the destination tablesreate the destination tables, overwrite the destination table.\n"
	@echo "## challenge-spark-b		- Build both postgres and spark images and containers,ccreate the destination tablesreate the destination tables, append the destination table based on --running-date=$(CURRENT_DATE).\n"
	@echo "## jupyter			- Spinup jupyter notebook for testing and validation purposes.\n"
	@echo "## clean			- Cleanup all running containers related to the challenge."

all: postgres spark

network:
	@docker network inspect dibimbing-dataeng-network >/dev/null 2>&1 || docker network create dibimbing-dataeng-network

postgres: network postgres-create

postgres-create:
	@docker-compose -f ./docker/docker-compose-postgres.yml --env-file .env up -d
	@echo '__________________________________________________________'
	@echo 'Postgres container created at port ${DIBIMBING_DE_POSTGRES_PORT}...'
	@echo '__________________________________________________________'
	@echo 'Postgres Docker Host	: ${DIBIMBING_DE_POSTGRES_HOST}' &&\
		echo 'Postgres Account	: ${DIBIMBING_DE_POSTGRES_ACCOUNT}' &&\
		echo 'Postgres password	: ${DIBIMBING_DE_POSTGRES_PASSWORD}' &&\
		echo 'Postgres Db		: ${DIBIMBING_DE_POSTGRES_DB}'
	@sleep 5
	@echo '==========================================================='

# postgres-create-table:
# 	@echo '__________________________________________________________'
# 	@echo 'Creating tables...'
# 	@echo '_________________________________________'
# 	@docker exec -it ${DIBIMBING_DE_POSTGRES_CONTAINER_NAME} psql -U ${DIBIMBING_DE_POSTGRES_ACCOUNT} -d ${DIBIMBING_DE_POSTGRES_DB} -f challenge_sql/ddl.sql
# 	@echo '==========================================================='

# postgres-ingest-csv:
# 	@echo '__________________________________________________________'
# 	@echo 'Ingesting CSV...'
# 	@echo '_________________________________________'
# 	@docker exec -it ${DIBIMBING_DE_POSTGRES_CONTAINER_NAME} psql -U ${DIBIMBING_DE_POSTGRES_ACCOUNT} -d ${DIBIMBING_DE_POSTGRES_DB} -f challenge_sql/ingest.sql
# 	@echo '==========================================================='

# postgres-transform-load:
# 	@echo '__________________________________________________________'
# 	@echo 'Transforming data...'
# 	@echo '__________________________________________________________'
# 	@docker exec -it ${DIBIMBING_DE_POSTGRES_CONTAINER_NAME} psql -U ${DIBIMBING_DE_POSTGRES_ACCOUNT} -d ${DIBIMBING_DE_POSTGRES_DB} -f challenge_sql/transform.sql
# 	@echo 'Created at average_salary_hour on Full Snapshot Mode (Truncate)'
# 	@echo '==========================================================='

# spark: postgres-create spark-create

spark-create:
	@echo '__________________________________________________________'
	@echo 'Creating Spark Cluster ...'
	@echo '__________________________________________________________'
	@docker build -t dataeng-dibimbing/challenges_spark -f ./docker/spark.Dockerfile .
	@docker-compose -f ./docker/docker-compose-spark.yml --env-file .env up -d
	@echo '==========================================================='

# challenge-spark-a:
# 	@docker exec -it ${DIBIMBING_DE_POSTGRES_CONTAINER_NAME} psql -U ${DIBIMBING_DE_POSTGRES_ACCOUNT} -d ${DIBIMBING_DE_POSTGRES_DB} -f challenge_spark/ddl_spark.sql
# 	@docker exec ${DIBIMBING_DE_SPARK_MASTER_CONTAINER_NAME} \
# 		spark-submit \
# 		--master spark://${DIBIMBING_DE_SPARK_MASTER_HOST_NAME}:${DIBIMBING_DE_SPARK_MASTER_PORT} \
# 		/challenge_spark/average_employee_spark.py \
# 		--spark-host ${DIBIMBING_DE_SPARK_MASTER_HOST_NAME}:${DIBIMBING_DE_SPARK_MASTER_PORT} \
# 		--jdbc-url $(JDBC_URL)\
# 		--jdbc-properties $(JDBC_PROPERTIES)\
# 		--jdbc-target-table ${DIBIMBING_DE_SPARK_TARGET_HISTORICAL_TABLE} \
# 		--employees-csv ${DIBIMBING_DE_EMPLOYEES_CSV} \
# 		--timesheets-csv ${DIBIMBING_DE_TIMESHEETS_CSV} \
# 		--employees-schema ${DIBIMBING_DE_EMPLOYEES_SCHEMA} \
# 		--timesheets-schema ${DIBIMBING_DE_TIMESHEETS_SCHEMA} \
# 		--transformer-sql ${DIBIMBING_DE_SPARK_TRANSFORMER_SQL}

# challenge-spark-b:
# 	@docker exec ${DIBIMBING_DE_SPARK_MASTER_CONTAINER_NAME} \
# 		spark-submit \
# 		--master spark://${DIBIMBING_DE_SPARK_MASTER_HOST_NAME}:${DIBIMBING_DE_SPARK_MASTER_PORT} \
# 		/challenge_spark/average_employee_spark.py \
# 		--spark-host ${DIBIMBING_DE_SPARK_MASTER_HOST_NAME}:${DIBIMBING_DE_SPARK_MASTER_PORT} \
# 		--spark-append-mode \
# 		--running-date $(CURRENT_DATE) \
# 		--jdbc-url $(JDBC_URL)\
# 		--jdbc-properties $(JDBC_PROPERTIES)\
# 		--jdbc-target-table ${DIBIMBING_DE_SPARK_TARGET_HISTORICAL_TABLE} \
# 		--employees-csv ${DIBIMBING_DE_EMPLOYEES_CSV} \
# 		--timesheets-csv ${DIBIMBING_DE_TIMESHEETS_CSV} \
# 		--employees-schema ${DIBIMBING_DE_EMPLOYEES_SCHEMA} \
# 		--timesheets-schema ${DIBIMBING_DE_TIMESHEETS_SCHEMA} \
# 		--transformer-sql ${DIBIMBING_DE_SPARK_TRANSFORMER_SQL}

# spark-help:
# 	@docker exec ${DIBIMBING_DE_SPARK_MASTER_CONTAINER_NAME} \
# 		spark-submit \
# 		--master spark://${DIBIMBING_DE_SPARK_MASTER_HOST_NAME}:${DIBIMBING_DE_SPARK_MASTER_PORT} \
# 		/challenge_spark/average_employee_spark.py -h

# challenge-sql-a: postgres-create-table postgres-ingest-csv

# challenge-sql-b: postgres-create-table postgres-ingest-csv postgres-transform-load

# challenge-sql-test:
# 	@echo '__________________________________________________________'
# 	@echo 'End Results:'
# 	@echo '_________________________________________'
# 	@docker exec -it ${DIBIMBING_DE_POSTGRES_CONTAINER_NAME} psql -U ${DIBIMBING_DE_POSTGRES_ACCOUNT} -d ${DIBIMBING_DE_POSTGRES_DB} -f challenge_sql/load_bi.sql
# 	@echo '==========================================================='

# clean:
# 	@bash ./helper/goodnight.sh

jupyter:
	@echo '__________________________________________________________'
	@echo 'Creating Jupyter Notebook Cluster at http://localhost:${DIBIMBING_DE_JUPYTER_PORT}...'
	@echo '__________________________________________________________'
	@docker build -t dataeng-dibimbing/jupyter -f ./docker/jupyter.Dockerfile .
	@docker-compose -f ./docker/docker-compose-jupyter.yml --env-file .env up -d
	@echo 'Created...'
	@echo 'Processing token...'
	@sleep 10
	@docker logs dibimbing-dataeng-jupyter 2>&1 | grep '\?token\=' -m 1 | cut -d '=' -f2
	@echo '==========================================================='
