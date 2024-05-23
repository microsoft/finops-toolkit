from pyspark.sql import SparkSession
import sys

def export(name, read_path, export_table):
    spark = SparkSession.builder \
        .appName(name) \
        .getOrCreate()
    
    df = spark.read \
        .format("csv") \
        .option("header", "true") \
        .option("inferSchema", "true") \
        .option("recursiveFileLookup", "true") \
        .load(read_path)
    
    ''' Use this for parquet reading
    df = spark.read \
        .format("parquet") \
        .option("header", "true") \
        .option("inferSchema", "true") \
        .option("recursiveFileLookup", "true") \
        .load(read_path)
    '''

    ''' Use this if you want to overwrite the schema as well
    df.write \
        .mode("overwrite") \
        .format("delta") \
        .option("overwriteSchema", "true") \
        .save(export_table)
    '''
    df.write \
        .mode("overwrite") \
        .format("delta") \
        .save(export_table)

if __name__ == "__main__":
    appName = "Continuous Export Script"
    readPath = sys.argv
    outputTable = "Tables/CostDetails"
    export(appName, readPath, outputTable)
