
import requests
import BeautifulSoup
import pymongo

import datetime


########### Get data
response = requests.get("http://hraun.vedur.is/ja/skjalftar/skjlisti.html")
if response.status_code != 200:
    print "EXITING!!!"
    exit()

########### Parse data
parsed_html = BeautifulSoup.BeautifulSoup(response.text)
data = []
first = True
for table_row in parsed_html.body.findAll("table")[2].findAll("tr"):
    # skip the header line
    if first:
        first = False
        continue

    day, time, latitude, longitude, depth, size, quality, location_dist, location_dir, location_name = table_row.findAll("td")
    day = day.text
    time, subsecond = time.text.split(",")
    subsecond = float("0."+subsecond)

    date_object = datetime.datetime.strptime("%s %s %06d" % (day, time, subsecond*1000000), '%Y-%m-%d %H:%M:%S %f')

    latitude = float(latitude.text.replace(",", "."))
    longitude = float(longitude.text.replace(",", "."))
    depth = float(depth.text.replace(",", "."))
    size = float(size.text.replace(",", "."))
    quality = float(quality.text.replace(",", "."))
    location_dist = location_dist.text
    location_dir = location_dir.text
    location_name = location_name.text

    data_row = {
        "date": date_object,
        "latitude": latitude,
        "longitude": longitude,
        "depth": depth,
        "size": size,
        "quality": quality,
        "location_dist": location_dist,
        "location_dir": location_dir,
        "location_name": location_name,
    }
    data.append(data_row)

##############################
# setup mongodb connection
client = pymongo.MongoClient("localhost", 27017)
isapi_db = client.isapi
earthquake_collection = isapi_db.earthquake
earthquake_collection.ensure_index("date")

# insert or update all the found rows
for data_row in data:
    earthquake_collection.find_and_modify(
        query={"date": data_row["date"]},
        update=data_row,
        upsert=True
    )
client.close()

print "Updated", len(data), "rows"

# debug print out all the rows in the db
#for row in earthquake_collection.find():
#    print row["date"], row["latitude"], row["longitude"], row["size"]

