import json
import pandas as pd
import datetime

def safe_serialize(data):
    def convert(obj):
        if isinstance(obj, pd.Timestamp):
            return obj.isoformat()
        if isinstance(obj, (datetime.datetime, datetime.date)):
            return obj.isoformat()
        return str(obj)
    return json.dumps(data, default=convert)
