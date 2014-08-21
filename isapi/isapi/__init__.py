
import datetime

import flask
app = flask.Flask(__name__)
import pymongo
import time
import datetime
import functools


def crossdomain(origin=None, methods=None, headers=None,
                max_age=21600, attach_to_all=True,
                automatic_options=True):
    if methods is not None:
        methods = ', '.join(sorted(x.upper() for x in methods))
    if headers is not None and not isinstance(headers, basestring):
        headers = ', '.join(x.upper() for x in headers)
    if not isinstance(origin, basestring):
        origin = ', '.join(origin)
    if isinstance(max_age, datetime.timedelta):
        max_age = max_age.total_seconds()

    def get_methods():
        if methods is not None:
            return methods

        options_resp = flask.current_app.make_default_options_response()
        return options_resp.headers['allow']

    def decorator(f):
        def wrapped_function(*args, **kwargs):
            if automatic_options and flask.request.method == 'OPTIONS':
                resp = flask.current_app.make_default_options_response()
            else:
                resp = flask.make_response(f(*args, **kwargs))
            if not attach_to_all and flask.request.method != 'OPTIONS':
                return resp

            h = resp.headers

            h['Content-Type'] = 'application/json'

            h['Access-Control-Allow-Origin'] = origin
            h['Access-Control-Allow-Methods'] = get_methods()
            h['Access-Control-Max-Age'] = str(max_age)
            if headers is not None:
                h['Access-Control-Allow-Headers'] = headers
            elif "Access-Control-Request-Headers" in flask.request.headers:
                h['Access-Control-Allow-Headers'] = flask.request.headers["Access-Control-Request-Headers"]
            else:
                pass

            return resp

        f.provide_automatic_options = False

        # make sure we let options through
        if hasattr(f, "methods"):
            f.methods.append("OPTIONS")
        else:
            f.methods = ["GET", "POST", "OPTIONS"]
        return functools.update_wrapper(wrapped_function, f)
    return decorator


database_connection_cache = None


def get_database_connection():
    global database_connection_cache
    if database_connection_cache is None or not database_connection_cache.alive():
        database_connection_cache = pymongo.MongoClient("localhost", 27017)

    return database_connection_cache


@app.route('/')
@crossdomain(origin="*")
def main():

    return_value = {
        "earthquakes": flask.url_for('earthquakes'),
    }

    return flask.jsonify(return_value)


@app.route("/api/earthquakes/")
@crossdomain(origin="*")
def earthquakes():

    isapi_db = get_database_connection().isapi
    earthquake_collection = isapi_db.earthquake

    input_date_string = flask.request.args.get('date', None)

    if input_date_string is None:
        return flask.Response("date query parameter missing", status=400)

    force_short_cache = False

    try:
        input_date = datetime.datetime.strptime(input_date_string, '%Y-%m-%d')
        start_date = datetime.datetime(input_date.year, input_date.month, input_date.day)
        end_date = start_date + datetime.timedelta(days=1)
    except:
        if input_date_string.endswith("-hoursago"):
            try:
                hours_ago_string, text = input_date_string.rsplit("-", 1)
                hours_ago = int(hours_ago_string)
                start_time = datetime.datetime.utcnow() - datetime.timedelta(hours=hours_ago)
                start_date = datetime.datetime(start_time.year, start_time.month, start_time.day, start_time.hour)

                end_time = datetime.datetime.utcnow() + datetime.timedelta(hours=1)
                end_date = datetime.datetime(end_time.year, end_time.month, end_time.day, end_time.hour)
                force_short_cache = True
            except:
                return flask.Response("date query parameter bad", status=400)
        else:
            return flask.Response("date query parameter bad", status=400)

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
        try:
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
                "verified": result.get("verified", False),
            }
            formatted_results.append(formatted_result)
        except Exception as e:
            formatted_results.append({"error": e.message})

    return_data = {
        "start": start_date,
        "end": end_date,
        "items": formatted_results
    }

    # Fiddle with the cache

    response = flask.jsonify(return_data)

    if datetime.datetime.utcnow() <= end_date or force_short_cache:
        response.cache_control.max_age = 10
    else:
        # cache for a long time if the now is greater than the end date
        # (so all the data is in the past and not going to change)
        response.cache_control.max_age = 300

    response.cache_control.public = True

    return response


if __name__ == '__main__':
    app.run(host='0.0.0.0')
