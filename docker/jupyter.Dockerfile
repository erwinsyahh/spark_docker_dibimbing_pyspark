FROM jupyter/pyspark-notebook:spark-3.3.2
USER root

RUN apt-get update && apt-get install -y \
    curl
RUN curl https://jdbc.postgresql.org/download/postgresql-42.2.18.jar -o /opt/postgresql-42.2.18.jar
RUN curl https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/2.1.1/kafka-clients-2.1.1.jar -o /opt/kafka-clients-2.1.1.jar
RUN curl https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/3.3.2/spark-sql-kafka-0-10_2.12-3.3.2.jar -o /opt/spark-sql-kafka-0-10_2.12-3.3.2.jar
RUN curl https://repo1.maven.org/maven2/org/apache/spark/spark-streaming-kafka-0-10_2.12/3.3.2/spark-streaming-kafka-0-10_2.12-3.3.2.jar -o /opt/spark-streaming-kafka-0-10_2.12-3.3.2.jar
RUN curl https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_2.12/3.3.2/spark-token-provider-kafka-0-10_2.12-3.3.2.jar -o /opt/spark-token-provider-kafka-0-10_2.12-3.3.2.jar
RUN curl https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/2.11.1/commons-pool2-2.11.1.jar -o /opt/commons-pool2-2.11.1.jar
COPY ./requirements.txt /opt/app/requirements.txt
RUN pip install -r /opt/app/requirements.txt --no-cache-dir
ENV JUPYTER_ALLOW_INSECURE_WRITES=1