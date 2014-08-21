
import datetime

import flask
app = flask.Flask(__name__)
import pymongo
import time


database_connection_cache = None


def get_database_connection():
    global database_connection_cache
    if database_connection_cache is None or not database_connection_cache.alive():
        database_connection_cache = pymongo.MongoClient("localhost", 27017)

    return database_connection_cache


@app.route('/')
def main():

    return_value = {
        "earthquakes": flask.url_for('earthquakes'),
    }

    return flask.jsonify(return_value)


@app.route("/api/earthquakes/")
def earthquakes():

    isapi_db = get_database_connection().isapi
    earthquake_collection = isapi_db.earthquake

    input_date_string = flask.request.args.get('date', None)

    if input_date_string is None:
        return flask.Response("date query parameter missing", status=400)

    input_date = datetime.datetime.strptime(input_date_string, '%Y-%m-%d')

    start_date = datetime.datetime(input_date.year, input_date.month, input_date.day)
    end_date = datetime.datetime(input_date.year, input_date.month, input_date.day+1)

    results = earthquake_collection.find(
        spec={
            "date": {
                "$gte": start_date,
                "$lt": end_date,
            },
        },
        sort=[('date', pymongo.ASCENDING)]
    )

    formatted_results = []

    for result in results:
        formatted_result = {
            "date": time.mktime(result["date"].timetuple()),
            "date_human": result["date"],
            "latitude": result["latitude"],
            "longitude": result["longitude"],
            "depth": result["depth"],
            "size": result["size"],
            "quality": result["quality"],
            "location_dist": result["location_dist"],
            "location_dir": result["location_dir"],
            "location_name": result["location_name"],
        }
        formatted_results.append(formatted_result)

    return_data = {
        "start": start_date,
        "end": end_date,
        "items": formatted_results
    }

    # Fiddle with the cache

    response = flask.jsonify(return_data)
    # cache for a long time if the now is greater than the end date
    # (so all the data is in the past and not going to change)
    if datetime.datetime.now() > end_date:
        response.cache_control.max_age = 60
    else:
        response.cache_control.max_age = 10

    response.cache_control.public = True

    return response



if __name__ == '__main__':
    app.run(host='0.0.0.0')
